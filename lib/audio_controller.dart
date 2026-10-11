import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:voice_audio/voice_audio.dart';

class AudioController extends ChangeNotifier {
  AudioController({VoiceAudio? audio, bool? supported, bool poll = true})
    : audio = audio ?? VoiceAudio(),
      supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    if (this.supported && poll) {
      unawaited(refresh());
      _timer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => refresh(),
      );
    }
  }
  final VoiceAudio audio;
  final bool supported;
  Timer? _timer;
  bool _disposed = false, _polling = false;
  int _epoch = 0;
  bool busy = false, running = false, muted = true, clarity = false;
  double input = 0,
      output = 0,
      gainDb = 0,
      sampleRate = 0,
      bufferMs = 0,
      reportedIoMs = 0;
  int fault = 0;
  String reason = 'idle';
  String? errorCode;

  void _apply(Map<String, dynamic> value) {
    running = value['running'] == true;
    muted = value['muted'] != false;
    clarity = value['clarity'] == true;
    fault = (value['fault'] as num?)?.toInt() ?? 0;
    input = (value['input'] as num?)?.toDouble() ?? 0;
    output = (value['output'] as num?)?.toDouble() ?? 0;
    gainDb = (value['gainDb'] as num?)?.toDouble() ?? gainDb;
    sampleRate = (value['sampleRate'] as num?)?.toDouble() ?? 0;
    bufferMs = (value['bufferMs'] as num?)?.toDouble() ?? 0;
    reportedIoMs = (value['reportedIoMs'] as num?)?.toDouble() ?? 0;
    reason = value['reason'] as String? ?? 'idle';
  }

  Future<void> refresh() async {
    if (_disposed || !supported || _polling || busy) return;
    _polling = true;
    final epoch = _epoch;
    try {
      final state = await audio
          .command('heartbeat')
          .timeout(const Duration(seconds: 2));
      if (!_disposed && epoch == _epoch) {
        _apply(state);
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        // Never display stale telemetry as live. Native watchdog mutes if the
        // Flutter controller is no longer able to send heartbeats.
        input = output = 0;
        errorCode = 'connection';
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _command(String name, [Map<String, Object?>? arguments]) async {
    if (!supported || _disposed) return;
    final epoch = ++_epoch;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      final state = await audio
          .command(name, arguments)
          .timeout(const Duration(seconds: 20));
      if (!_disposed && epoch == _epoch) _apply(state);
    } on PlatformException catch (error) {
      if (!_disposed && epoch == _epoch) errorCode = error.code;
    } on MissingPluginException {
      if (!_disposed && epoch == _epoch) errorCode = 'missing';
    } catch (_) {
      if (!_disposed && epoch == _epoch) errorCode = 'connection';
    } finally {
      if (!_disposed && epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> start() async {
    if (busy || running) return;
    await _command('start');
  }

  Future<void> stop() => _command('stop');
  Future<void> mute() => _command('mute', {'muted': true});
  Future<void> unmute() async {
    if (!running || fault != 0 || busy) return;
    await _command('mute', {'muted': false});
  }

  Future<void> configure(double db, bool useClarity) async {
    if (busy) return;
    if (!supported) {
      gainDb = db.clamp(0, 6);
      clarity = useClarity;
      notifyListeners();
      return; // UI preview only; no fake persistence or audio.
    }
    await _command('configure', {
      'gainDb': db.clamp(0, 6),
      'clarity': useClarity,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (supported) {
      unawaited(
        audio.command('stop').then<void>((_) {}, onError: (Object _) {}),
      );
    }
    super.dispose();
  }
}
