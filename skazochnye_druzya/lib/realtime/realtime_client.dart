import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import '../config.dart';
import '../debug_log.dart';

/// События сервера, которые нужны приложению.
sealed class RealtimeEvent {
  const RealtimeEvent();
}

class SessionReady extends RealtimeEvent {
  const SessionReady();
}

class SpeechStarted extends RealtimeEvent {
  const SpeechStarted();
}

class SpeechStopped extends RealtimeEvent {
  const SpeechStopped();
}

class ResponseStarted extends RealtimeEvent {
  const ResponseStarted();
}

class AudioDelta extends RealtimeEvent {
  const AudioDelta(this.bytes);
  final Uint8List bytes;
}

class AssistantTranscript extends RealtimeEvent {
  const AssistantTranscript(this.text);
  final String text;
}

class UserTranscript extends RealtimeEvent {
  const UserTranscript(this.text);
  final String text;
}

class ResponseDone extends RealtimeEvent {
  const ResponseDone(this.itemIds);

  /// Идентификаторы реплик ответа — нужны, чтобы удалить
  /// заблокированный ответ из контекста разговора.
  final List<String> itemIds;
}

class RealtimeError extends RealtimeEvent {
  const RealtimeError(this.message);
  final String message;
}

class Disconnected extends RealtimeEvent {
  const Disconnected();
}

/// Клиент Realtime API Yandex AI Studio (протокол совместим с OpenAI Realtime).
class RealtimeClient {
  IOWebSocketChannel? _channel;
  final _events = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;

  final _seenDeltas = <String>{};

  Future<void> connect() async {
    final channel = IOWebSocketChannel.connect(
      Uri.parse(AppConfig.realtimeUrl),
      headers: AppConfig.headers,
      pingInterval: const Duration(seconds: 20),
      connectTimeout: const Duration(seconds: 10),
    );
    await channel.ready;
    _channel = channel;
    channel.stream.listen(
      _onMessage,
      onError: (Object e) {
        DebugLog.add('[RT] ошибка сокета: $e');
        _emit(RealtimeError('$e'));
      },
      onDone: () {
        DebugLog.add('[RT] сокет закрыт: ${channel.closeCode} '
            '${channel.closeReason ?? ''}');
        _emit(const Disconnected());
      },
    );
  }

  /// Настройка сессии: промпт, голос, формат звука, детектор речи.
  void configure({required String instructions, required String voice}) {
    final format = {'type': 'audio/pcm', 'rate': AppConfig.sampleRate};
    _send({
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'instructions': instructions,
        'output_modalities': ['audio'],
        'audio': {
          'input': {
            'format': format,
            'turn_detection': {
              'type': 'server_vad',
              // Малыши делают длинные паузы внутри фразы.
              'silence_duration_ms': 1000,
              'prefix_padding_ms': 300,
            },
          },
          'output': {'format': format, 'voice': voice},
        },
      },
    });
  }

  void appendAudio(Uint8List pcm) =>
      _send({'type': 'input_audio_buffer.append', 'audio': base64Encode(pcm)});

  void clearInput() => _send({'type': 'input_audio_buffer.clear'});

  void requestResponse({String? instructions}) => _send({
        'type': 'response.create',
        if (instructions != null) 'response': {'instructions': instructions},
      });

  void cancelResponse() => _send({'type': 'response.cancel'});

  void deleteItem(String itemId) =>
      _send({'type': 'conversation.item.delete', 'item_id': itemId});

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    close();
    _events.close();
  }

  void _send(Map<String, Object?> event) {
    _channel?.sink.add(jsonEncode(event));
  }

  void _emit(RealtimeEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = m['type'] as String? ?? '';
    // Дельты приходят десятками — в журнал только первая каждого вида.
    if (!type.endsWith('.delta') || _seenDeltas.add(type)) {
      DebugLog.add('[RT] $type');
    }

    switch (type) {
      case 'session.updated':
        _emit(const SessionReady());
      case 'input_audio_buffer.speech_started':
        _emit(const SpeechStarted());
      case 'input_audio_buffer.speech_stopped':
        _emit(const SpeechStopped());
      case 'response.created':
        _seenDeltas.clear();
        _emit(const ResponseStarted());
      // Новые и старые имена событий OpenAI Realtime.
      case 'response.output_audio.delta' || 'response.audio.delta':
        final delta = m['delta'] as String?;
        if (delta != null) _emit(AudioDelta(base64Decode(delta)));
      case 'response.output_audio_transcript.done' ||
            'response.audio_transcript.done':
        _emit(AssistantTranscript(m['transcript'] as String? ?? ''));
      case 'conversation.item.input_audio_transcription.completed':
        _emit(UserTranscript(m['transcript'] as String? ?? ''));
      case 'response.done':
        final output = (m['response'] as Map?)?['output'] as List? ?? const [];
        final ids = output
            .whereType<Map>()
            .map((o) => o['id'])
            .whereType<String>()
            .toList();
        _emit(ResponseDone(ids));
      case 'error':
        final err = m['error'];
        final msg = err is Map ? (err['message'] ?? err).toString() : '$m';
        DebugLog.add('[RT] ошибка сервера: ${err ?? m}');
        _emit(RealtimeError(msg));
    }
  }
}
