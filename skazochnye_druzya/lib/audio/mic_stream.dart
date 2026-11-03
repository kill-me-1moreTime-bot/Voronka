import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../config.dart';

/// Поток с микрофона в PCM16 моно. Пока `muted`, звук никуда не уходит —
/// так персонаж не слышит сам себя из динамика.
class MicStream {
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool muted = false;

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
      if (!muted) onChunk(chunk);
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
