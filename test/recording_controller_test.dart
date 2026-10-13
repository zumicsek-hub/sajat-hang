import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:sajat_hang/recording_controller.dart';
import 'package:sajat_hang/wav_enhancer.dart';

class TestRecorder extends Fake implements AudioRecorder {
  bool allowed = true;
  int starts = 0, stops = 0;
  String? path;
  Completer<void>? starting;
  final states = StreamController<RecordState>.broadcast();
  @override
  Stream<RecordState> onStateChanged() => states.stream;
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream.empty();
  @override
  Future<bool> hasPermission({bool request = true}) async => allowed;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    this.path = path;
    await starting?.future;
    await File(path).writeAsBytes(Wave(48000, Float64List(4800)).encode());
  }

  @override
  Future<String?> stop() async {
    stops++;
    return path;
  }

  @override
  Future<void> dispose() async {
    await states.close();
  }
}

class TestPlayer extends Fake implements AudioPlayer {
  @override
  Stream<void> get onPlayerComplete => const Stream.empty();
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory directory;
  late TestRecorder recorder;
  late RecordingController controller;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sajat-hang-test-');
    recorder = TestRecorder();
    controller = RecordingController(
      supported: true,
      recorder: recorder,
      player: TestPlayer(),
      storage: () async => directory,
    );
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await directory.delete(recursive: true);
  });
  test('permission denial never starts capture', () async {
    recorder.allowed = false;
    await controller.start();
    expect(recorder.starts, 0);
    expect(controller.error, 'permission');
    expect(controller.busy, false);
  });
  test(
    'stop saves both versions, then deletion removes only the selected clip',
    () async {
      await controller.start();
      await controller.start();
      expect(recorder.starts, 1);
      await controller.stop();
      expect(controller.recording, false);
      expect(controller.error, isNull);
      expect(controller.clips, hasLength(1));
      final clip = controller.clips.single;
      expect(await File(clip.original).exists(), true);
      expect(await File(clip.enhanced).exists(), true);
      await controller.delete(clip);
      expect(controller.clips, isEmpty);
    },
  );
  test(
    'background during pending start stops when native start completes',
    () async {
      recorder.starting = Completer<void>();
      final start = controller.start();
      while (recorder.starts == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await controller.background(true);
      recorder.starting!.complete();
      await start;
      expect(recorder.stops, 1);
      expect(controller.recording, false);
      expect(controller.clips, hasLength(1));
    },
  );
}
