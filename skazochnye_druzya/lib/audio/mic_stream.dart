import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import '../config.dart';

/// Поток с микрофона в PCM16 моно. Пока `muted`, звук никуда не уходит —
/// так персонаж не слышит сам себя из динамика.
class MicStream {
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool muted = false;

  // Для журнала: сколько кусков ушло и самый громкий звук в них.
  int _sent = 0;
  double _peak = 0;

  /// Сводка с прошлого вызова: куски и громкость 0..1. Обнуляет счётчики.
  ({int chunks, double peak}) takeStats() {
    final r = (chunks: _sent, peak: _peak);
    _sent = 0;
    _peak = 0;
    return r;
  }

  /// Громкость куска PCM16: максимум по модулю, 0..1.
  static double peakOf(Uint8List chunk) {
    final d = ByteData.sublistView(chunk);
    var m = 0;
    for (var i = 0; i + 1 < chunk.length; i += 2) {
      m = math.max(m, d.getInt16(i, Endian.little).abs());
    }
    return m / 32768;
  }

  Future<bool> start(void Function(Uint8List chunk) onChunk) async {
    if (!await _recorder.hasPermission()) return false;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: AppConfig.sampleRate,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
    ));
    _sub = stream.listen((chunk) {
      if (muted) return;
      _sent++;
      _peak = math.max(_peak, peakOf(chunk));
      onChunk(chunk);
    });
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
