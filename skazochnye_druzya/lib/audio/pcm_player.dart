import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../debug_log.dart';

/// Проигрывает ответ персонажа целиком и параллельно отдаёт громкость
/// для анимации рта (липсинк по амплитуде).
///
/// Ответ сначала собирается полностью — это добавляет задержку, но даёт
/// проверить текст фильтром безопасности до того, как ребёнок его услышит.
class PcmPlayer {
  PcmPlayer() {
    // Не забираем аудиофокус у микрофона и играем через динамик.
    _player.setAudioContext(AudioContextConfig(
      route: AudioContextConfigRoute.speaker,
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build());
  }

  final _player = AudioPlayer();
  Completer<void>? _done;

  static const _windowMs = 50;

  Future<void> play(
    Uint8List pcm,
    int sampleRate,
    void Function(double level) onLevel, {
    double rate = 1.0,
  }) async {
    await stop();
    // В PCM16 на сэмпл два байта — нечётный хвост отбрасываем.
    if (pcm.length.isOdd) pcm = Uint8List.sublistView(pcm, 0, pcm.length - 1);

    final envelope = _envelope(pcm, sampleRate);
    // При замедлении звук длится дольше — и рот, и ожидание конца
    // считаем по реальному времени.
    final durationMs = (pcm.length ~/ 2 * 1000 / sampleRate / rate).round();
    final done = Completer<void>();
    _done = done;

    final sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    Timer? timer;
    try {
      await _player.play(BytesSource(_wav(pcm, sampleRate)));
      // Скорость ставим после запуска: на Android установка до play()
      // в некоторых версиях сама запускает звук. Высота голоса не меняется.
      if (rate != 1.0) await _player.setPlaybackRate(rate);
      // stop() мог прийти, пока звук запускался.
      if (done.isCompleted) {
        await _player.stop();
        return;
      }

      final clock = Stopwatch()..start();
      timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
        final i = (clock.elapsedMilliseconds * rate) ~/ _windowMs;
        onLevel(i < envelope.length ? envelope[i] : 0);
      });

      await done.future.timeout(
        Duration(milliseconds: durationMs + 3000),
        // Плеер не сообщил о конце — микрофон откроется на 3 с позже.
        onTimeout: () => DebugLog.add('[Audio] нет сигнала о конце звука'),
      );
    } finally {
      timer?.cancel();
      await sub.cancel();
      onLevel(0);
    }
  }

  Future<void> stop() async {
    final d = _done;
    if (d != null && !d.isCompleted) d.complete();
    await _player.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  /// Громкость по окнам 50 мс, нормированная в 0..1.
  static List<double> _envelope(Uint8List pcm, int sampleRate) {
    final data = ByteData.sublistView(pcm);
    final samples = pcm.length ~/ 2;
    final win = sampleRate * _windowMs ~/ 1000;
    final out = <double>[];
    var peak = 1e-6;
    for (var start = 0; start < samples; start += win) {
      final end = math.min(start + win, samples);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        final s = data.getInt16(i * 2, Endian.little) / 32768.0;
        sum += s * s;
      }
      final rms = math.sqrt(sum / math.max(1, end - start));
      peak = math.max(peak, rms);
      out.add(rms);
    }
    return [for (final v in out) math.sqrt((v / peak).clamp(0.0, 1.0))];
  }

  /// Оборачивает PCM16 моно в WAV-заголовок.
  static Uint8List _wav(Uint8List pcm, int sampleRate) {
    final header = ByteData(44);
    void str(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // моно
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    str(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(pcm))
        .takeBytes();
  }
}
