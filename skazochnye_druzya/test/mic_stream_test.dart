import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/audio/mic_stream.dart';

void main() {
  Uint8List pcm(List<int> samples) {
    final d = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      d.setInt16(i * 2, samples[i], Endian.little);
    }
    return d.buffer.asUint8List();
  }

  test('громкость тишины — ноль', () {
    expect(MicStream.peakOf(pcm([0, 0, 0])), 0);
  });

  test('громкость — максимум по модулю', () {
    expect(MicStream.peakOf(pcm([100, -16384, 200])), closeTo(0.5, 0.001));
  });

  test('нечётный хвост куска не ломает подсчёт', () {
    final b = Uint8List.fromList([
      ...pcm([8192]),
      7
    ]);
    expect(MicStream.peakOf(b), closeTo(0.25, 0.001));
  });
}
