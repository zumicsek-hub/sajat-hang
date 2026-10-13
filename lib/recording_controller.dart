import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'wav_enhancer.dart';
import 'package:voice_audio/voice_audio.dart';

class Clip {
  Clip(this.directory);
  final Directory directory;
  String get id => directory.uri.pathSegments.where((s) => s.isNotEmpty).last;
  String get original => '${directory.path}/original.wav';
  String get enhanced => '${directory.path}/enhanced.wav';
  String get label =>
      DateTime.tryParse(
        id.replaceAll('_', ':'),
      )?.toLocal().toString().split('.').first ??
      id;
}

class RecordingController extends ChangeNotifier {
  RecordingController({
    bool? supported,
    AudioRecorder? recorder,
    AudioPlayer? player,
    Future<Directory> Function()? storage,
  }) : supported =
           supported ??
           (!kIsWeb &&
               (defaultTargetPlatform == TargetPlatform.windows ||
                   defaultTargetPlatform == TargetPlatform.iOS)),
       // Public injection names keep native adapters replaceable in tests.
       // ignore: prefer_initializing_formals
       _recorder = recorder,
       // ignore: prefer_initializing_formals
       _player = player,
       _storage = storage ?? getApplicationSupportDirectory;
  final bool supported;
  final Future<Directory> Function() _storage;
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  StreamSubscription<Amplitude>? _levels;
  StreamSubscription<RecordState>? _states;
  StreamSubscription<void>? _complete;
  Timer? _timer;
  final Stopwatch _watch = Stopwatch();
  bool _disposed = false, _initialized = false, _background = false;
  bool busy = false, recording = false, playing = false;
  double db = -60;
  int seconds = 0;
  String? error, message;
  String? playingPath;
  Directory? _root;
  Clip? _current;
  List<Clip> clips = [];
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!supported || _initialized || busy) return;
    busy = true;
    _notify();
    try {
      final support = await _storage();
      if (_disposed) return;
      _root = await Directory(
        '${support.path}/recordings',
      ).create(recursive: true);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await VoiceAudio().command('protectRecordings');
      }
      _recorder ??= AudioRecorder();
      _player ??= AudioPlayer();
      _complete = _player!.onPlayerComplete.listen((_) {
        playing = false;
        playingPath = null;
        _notify();
      });
      _states = _recorder!.onStateChanged().listen((state) {
        if (recording && state != RecordState.record) unawaited(stop());
      });
      _levels = _recorder!
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen(
            (level) {
              db = level.current.isFinite ? level.current.clamp(-60, 0) : -60;
              _notify();
            },
            onError: (Object _) {
              db = -60;
              _notify();
            },
          );
      await _reload();
      _initialized = true;
    } catch (e) {
      error = 'init';
    }
    busy = false;
    _notify();
  }

  Future<void> _reload() async {
    final found = <Clip>[];
    await for (final item in _root!.list(followLinks: false)) {
      if (item is Directory &&
          await File('${item.path}/original.wav').exists()) {
        found.add(Clip(item));
      }
    }
    found.sort((a, b) => b.id.compareTo(a.id));
    clips = found;
  }

  Future<void> start() async {
    if (!supported || busy || recording || _disposed) return;
    if (!_initialized) await initialize();
    if (!_initialized || _disposed) return;
    busy = true;
    error = message = null;
    _notify();
    try {
      await stopPlayback();
      if (!await _recorder!.hasPermission()) {
        error = 'permission';
        return;
      }
      if (_background || _disposed) return;
      final id = DateTime.now().toUtc().toIso8601String().replaceAll(':', '_');
      _current = Clip(await Directory('${_root!.path}/$id').create());
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 48000,
          numChannels: 1,
          audioInterruption: AudioInterruptionMode.pause,
          iosConfig: IosRecordConfig(
            categoryOptions: [IosAudioCategoryOption.defaultToSpeaker],
          ),
        ),
        path: _current!.original,
      );
      recording = true;
      seconds = 0;
      db = -60;
      _watch
        ..reset()
        ..start();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        seconds = _watch.elapsed.inSeconds;
        _notify();
        if (seconds >= 180) unawaited(stop());
      });
    } catch (e) {
      error = 'record';
    } finally {
      busy = false;
      _notify();
    }
    if (_background && recording) await stop();
  }

  Future<void> stop() async {
    if (!recording || busy) return;
    busy = true;
    recording = false;
    _timer?.cancel();
    _watch.stop();
    db = -60;
    _notify();
    try {
      final path = await _recorder!.stop();
      if (path == null || _current == null) throw StateError('No recording');
      // Original is retained even if enhancement fails, so the user can retry.
      await _enhance(_current!);
    } catch (e) {
      error = e is FormatException ? 'format' : 'process';
    } finally {
      try {
        await _reload();
      } catch (_) {
        error = 'storage';
      }
      busy = false;
      _current = null;
      _notify();
    }
  }

  Future<void> _enhance(Clip clip) async {
    final source = File(clip.original);
    if (await source.length() > 40000000) {
      throw const FormatException('Too long');
    }
    final result = await compute(enhanceWave, await source.readAsBytes());
    final temp = File('${clip.enhanced}.tmp');
    await temp.writeAsBytes(result['bytes'] as List<int>, flush: true);
    await temp.rename(clip.enhanced);
    message = result['quiet'] == true ? 'quiet' : 'saved';
  }

  Future<void> enhance(Clip clip) async {
    if (busy || recording) return;
    busy = true;
    error = null;
    _notify();
    try {
      await stopPlayback();
      await _enhance(clip);
    } catch (e) {
      error = e is FormatException ? 'format' : 'process';
    }
    busy = false;
    _notify();
  }

  Future<void> play(String path) async {
    if (busy || recording || !_initialized) return;
    busy = true;
    error = null;
    _notify();
    try {
      await stopPlayback();
      if (!await File(path).exists()) {
        error = 'missing';
        return;
      }
      await _player!.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
      await _player!.play(DeviceFileSource(path));
      playing = true;
      playingPath = path;
      if (_background || _disposed) await stopPlayback();
    } catch (e) {
      error = 'play';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> stopPlayback() async {
    await _player?.stop();
    playing = false;
    playingPath = null;
    _notify();
  }

  Future<void> delete(Clip clip) async {
    if (busy || recording) return;
    busy = true;
    error = null;
    _notify();
    try {
      await stopPlayback();
      // Only app-owned files; never recursively delete user-chosen paths.
      for (final name in ['original.wav', 'enhanced.wav', 'enhanced.wav.tmp']) {
        final file = File('${clip.directory.path}/$name');
        if (await file.exists()) await file.delete();
      }
      if (await clip.directory.list().isEmpty) await clip.directory.delete();
      await _reload();
    } catch (e) {
      error = 'delete';
    }
    busy = false;
    _notify();
  }

  Future<void> background(bool value) async {
    _background = value;
    if (value) {
      await stop();
      await stopPlayback();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_levels?.cancel());
    unawaited(_states?.cancel());
    unawaited(_complete?.cancel());
    // On normal navigation the controller remains alive; disposal is app teardown.
    unawaited(_recorder?.dispose());
    unawaited(_player?.dispose());
    super.dispose();
  }
}
