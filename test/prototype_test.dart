import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sajat_hang/audio_controller.dart';
import 'package:sajat_hang/main.dart';
import 'package:voice_audio/voice_audio.dart';

class FakeAudio extends VoiceAudio {
  final calls = <String>[];
  final state = <String, dynamic>{'running': false, 'muted': true, 'fault': 0};
  Completer<Map<String, dynamic>>? pendingStart;
  @override
  Future<Map<String, dynamic>> command(
    String name, [
    Map<String, Object?>? arguments,
  ]) async {
    calls.add(name);
    switch (name) {
      case 'start':
        if (pendingStart != null) return pendingStart!.future;
        state['running'] = true;
        state['muted'] = true;
      case 'stop':
        state['running'] = false;
        state['muted'] = true;
      case 'mute':
        state['muted'] = arguments!['muted'];
      case 'configure':
        state.addAll(arguments!);
    }
    return Map.of(state);
  }
}

void main() {
  test('mute, fault and stop are controlled natively', () async {
    final fake = FakeAudio();
    final controller = AudioController(
      audio: fake,
      supported: true,
      poll: false,
    );
    await controller.start();
    expect(controller.running, true);
    expect(controller.muted, true);
    await controller.unmute();
    expect(controller.muted, false);
    fake.state['fault'] = 1;
    fake.state['muted'] = true;
    await controller.refresh();
    final before = fake.calls.length;
    await controller.unmute();
    expect(fake.calls.length, before, reason: 'Cannot unmute a latched fault');
    await controller.stop();
    expect(controller.running, false);
    controller.dispose();
  });

  test('stop supersedes a pending start response', () async {
    final fake = FakeAudio()..pendingStart = Completer<Map<String, dynamic>>();
    final controller = AudioController(
      audio: fake,
      supported: true,
      poll: false,
    );
    final starting = controller.start();
    await controller.stop();
    fake.pendingStart!.complete({'running': true, 'muted': true});
    await starting;
    expect(controller.running, false);
    expect(controller.busy, false);
    controller.dispose();
  });

  testWidgets(
    'preview is Hungarian, cannot start audio, and switches to English',
    (tester) async {
      final controller = AudioController(supported: false);
      await tester.pumpWidget(SajatHangApp(controller: controller));
      expect(
        find.text('Felületi előnézet · nincs hangfeldolgozás'),
        findsOneWidget,
      );
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('start-stop')),
      );
      expect(start.onPressed, isNull);
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(
        find.text('Interface preview · no audio processing'),
        findsOneWidget,
      );
      expect(find.text('Ready to talk'), findsOneWidget);
      controller.dispose();
    },
  );

  testWidgets('large text fits a narrow phone on every screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AudioController(supported: false);
    await tester.pumpWidget(SajatHangApp(controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Felvétel').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Beállítások').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}
