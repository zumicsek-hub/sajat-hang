import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sajat_hang/wav_enhancer.dart';

void main() {
  Uint8List tone(double amplitude, {int hz = 300, int rate = 48000}) => Wave(
    rate,
    Float64List.fromList(
      List.generate(
        rate,
        (i) => amplitude * math.sin(2 * math.pi * hz * i / rate),
      ),
    ),
  ).encode();
  double rms(Wave w) => math.sqrt(
    w.samples.fold<double>(0, (s, x) => s + x * x) / w.samples.length,
  );

  test('quiet voice is raised without changing duration or original bytes', () {
    final input = tone(.02);
    final copy = Uint8List.fromList(input);
    final result = enhanceWave(input);
    final output = Wave.decode(result['bytes'] as Uint8List);
    expect(input, copy);
    expect(output.samples.length, 48000);
    expect(output.rate, 48000);
    expect(rms(output), greaterThan(rms(Wave.decode(input)) * 3));
    expect(output.samples.every((x) => x.isFinite && x.abs() <= .795), true);
  });
  test('silence stays silent', () {
    final result = enhanceWave(Wave(48000, Float64List(48000)).encode());
    expect(result['quiet'], true);
    expect(
      Wave.decode(result['bytes'] as Uint8List).samples.every((x) => x == 0),
      true,
    );
  });
  test('full-scale transients do not clip after processing', () {
    final data = Float64List(48000);
    for (int i = 0; i < data.length; i += 100) {
      data[i] = i.isEven ? 1 : -1;
    }
    final out = Wave.decode(
      enhanceWave(Wave(48000, data).encode())['bytes'] as Uint8List,
    );
    expect(out.samples.every((x) => x.isFinite && x.abs() <= .795), true);
  });
  test('malformed WAV is rejected instead of decoding arbitrary bytes', () {
    expect(() => Wave.decode(Uint8List(44)), throwsFormatException);
    final broken = tone(.1).sublist(0, 100);
    expect(() => Wave.decode(broken), throwsFormatException);
  });
  test('low-frequency rumble is attenuated relative to speech', () {
    final mixed = Wave(
      48000,
      Float64List.fromList(
        List.generate(
          48000,
          (i) =>
              .04 *
              (math.sin(2 * math.pi * 20 * i / 48000) +
                  math.sin(2 * math.pi * 1000 * i / 48000)),
        ),
      ),
    );
    final output = Wave.decode(
      enhanceWave(mixed.encode())['bytes'] as Uint8List,
    );
    double magnitude(int hz) {
      double re = 0, im = 0;
      for (int i = 4800; i < output.samples.length; i++) {
        re += output.samples[i] * math.cos(2 * math.pi * hz * i / 48000);
        im += output.samples[i] * math.sin(2 * math.pi * hz * i / 48000);
      }
      return math.sqrt(re * re + im * im);
    }

    expect(magnitude(20) / magnitude(1000), lessThan(.4));
  });
}
