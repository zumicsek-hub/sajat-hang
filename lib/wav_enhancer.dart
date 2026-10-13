import 'dart:math' as math;
import 'dart:typed_data';

class Wave {
  Wave(this.rate, this.samples);
  final int rate;
  final Float64List samples;
  double get seconds => samples.length / rate;

  static Wave decode(Uint8List bytes) {
    if (bytes.length < 44 || bytes.length > 40000000) {
      throw const FormatException('WAV size');
    }
    final b = ByteData.sublistView(bytes);
    String tag(int i) => String.fromCharCodes(bytes.sublist(i, i + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      throw const FormatException('WAV header');
    }
    int? channels, rate, bits, format, offset, length;
    for (int i = 12; i + 8 <= bytes.length;) {
      final size = b.getUint32(i + 4, Endian.little);
      if (i + 8 + size > bytes.length) {
        throw const FormatException('Truncated WAV');
      }
      if (tag(i) == 'fmt ' && size >= 16) {
        format = b.getUint16(i + 8, Endian.little);
        channels = b.getUint16(i + 10, Endian.little);
        rate = b.getUint32(i + 12, Endian.little);
        bits = b.getUint16(i + 22, Endian.little);
        // Media Foundation may wrap PCM16 in WAVE_FORMAT_EXTENSIBLE.
        if (format == 0xfffe &&
            size >= 40 &&
            b.getUint16(i + 26, Endian.little) == 16 &&
            b.getUint32(i + 32, Endian.little) == 1 &&
            b.getUint32(i + 36, Endian.little) == 0x00100000 &&
            b.getUint32(i + 40, Endian.little) == 0xaa000080 &&
            b.getUint32(i + 44, Endian.little) == 0x719b3800) {
          format = 1;
        }
      } else if (tag(i) == 'data') {
        offset = i + 8;
        length = size;
      }
      i += 8 + size + (size % 2);
    }
    if (format != 1 ||
        bits != 16 ||
        channels == null ||
        channels < 1 ||
        channels > 2 ||
        rate == null ||
        rate < 8000 ||
        rate > 96000 ||
        offset == null ||
        length == null ||
        length % (channels * 2) != 0) {
      throw const FormatException('Use PCM16 WAV, mono or stereo');
    }
    final count = length ~/ (2 * channels);
    if (count == 0 || count / rate > 185) {
      throw const FormatException('Maximum 3 minutes');
    }
    final samples = Float64List(count);
    for (int i = 0; i < count; i++) {
      double sum = 0;
      for (int c = 0; c < channels; c++) {
        sum +=
            b.getInt16(offset + (i * channels + c) * 2, Endian.little) / 32768;
      }
      samples[i] = sum / channels;
    }
    return Wave(rate, samples);
  }

  Uint8List encode() {
    final bytes = Uint8List(44 + samples.length * 2);
    final b = ByteData.sublistView(bytes);
    void tag(int offset, String s) =>
        bytes.setRange(offset, offset + s.length, s.codeUnits);
    tag(0, 'RIFF');
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    tag(36, 'data');
    b.setUint32(4, bytes.length - 8, Endian.little);
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, rate, Endian.little);
    b.setUint32(28, rate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    b.setUint32(40, samples.length * 2, Endian.little);
    for (int i = 0; i < samples.length; i++) {
      final x = samples[i].isFinite ? samples[i] : 0.0;
      b.setInt16(
        44 + i * 2,
        (x * 32768).round().clamp(-32768, 32767),
        Endian.little,
      );
    }
    return bytes;
  }
}

/// Offline DSP only. Does not synthesize speech, time-stretch or infer words.
/// Frame-energy normalization is NOT LUFS or speech recognition.
Map<String, Object> enhanceWave(Uint8List bytes) {
  final wave = Wave.decode(bytes);
  final out = Float64List(wave.samples.length);
  final hp = math.exp(-2 * math.pi * 75 / wave.rate);
  final a = math.pow(10, 2 / 40).toDouble(); // +2 dB at 3 kHz
  final w = 2 * math.pi * math.min(3000, wave.rate * .35) / wave.rate;
  final alpha = math.sin(w) / (2 * .8);
  final a0 = 1 + alpha / a;
  final b0 = (1 + alpha * a) / a0, b1 = -2 * math.cos(w) / a0;
  final b2 = (1 - alpha * a) / a0, a1 = b1, a2 = (1 - alpha / a) / a0;
  double prev = 0, high = 0, z1 = 0, z2 = 0;
  for (int i = 0; i < out.length; i++) {
    high = hp * (high + wave.samples[i] - prev);
    prev = wave.samples[i];
    final y = b0 * high + z1;
    z1 = b1 * high - a1 * y + z2;
    z2 = b2 * high - a2 * y;
    out[i] = y;
  }
  final frame = (wave.rate * .02).round();
  final energies = <double>[];
  for (int i = 0; i < out.length; i += frame) {
    final end = math.min(i + frame, out.length);
    double energy = 0;
    for (int j = i; j < end; j++) {
      energy += out[j] * out[j];
    }
    energies.add(math.sqrt(energy / (end - i)));
  }
  energies.sort();
  final reference =
      energies[(energies.length * .8).floor().clamp(0, energies.length - 1)];
  // Do not amplify digital silence or near-silent microphone input.
  final quiet = reference < .001;
  final gain = quiet ? 1.0 : (.10 / reference).clamp(.25, 7.94);
  double envelope = 0, peak = 0;
  final attack = math.exp(-1 / (.008 * wave.rate));
  final release = math.exp(-1 / (.16 * wave.rate));
  for (int i = 0; i < out.length; i++) {
    final x = out[i] * gain;
    final c = x.abs() > envelope ? attack : release;
    envelope = c * envelope + (1 - c) * x.abs();
    final reduction = envelope > .18
        ? math.pow(.18 / envelope, .5).toDouble()
        : 1.0;
    out[i] = x * reduction;
    peak = math.max(peak, out[i].abs());
  }
  // Whole-recording peak normalization avoids clipped transients, no lookahead needed.
  final scale = peak > .794 ? .794 / peak : 1.0;
  for (int i = 0; i < out.length; i++) {
    out[i] *= scale;
  }
  return {
    'bytes': Wave(wave.rate, out).encode(),
    'seconds': wave.seconds,
    'quiet': quiet,
    'gainDb': 20 * math.log(gain * scale) / math.ln10,
  };
}
