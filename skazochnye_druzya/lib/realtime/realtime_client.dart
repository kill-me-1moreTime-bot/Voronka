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

  // Текст ответа. Yandex присылает его кусками (output_text.delta),
  // у OpenAI — расшифровкой звука (output_audio_transcript). Собираем
  // всё и отдаём один раз, перед ResponseDone.
  final _textParts = StringBuffer();
  String? _finalText;

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

  /// Начинаем слушать. Очистку буфера (input_audio_buffer.clear) Yandex
  /// не поддерживает и закрывает связь с ошибкой malformed_event, поэтому
  /// её не шлём: пока персонаж думает и говорит, микрофон и так молчит.
  void markListening() => _audioLogged = false;

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

  bool _audioLogged = false;

  void _send(Map<String, Object?> event) {
    final type = event['type'] as String? ?? '';
    // Звук с микрофона идёт десятками кусков — в журнал только первый
    // после каждой очистки буфера.
    if (type == 'input_audio_buffer.append') {
      if (!_audioLogged) {
        _audioLogged = true;
        DebugLog.add('[RT→] $type (микрофон пошёл)');
      }
    } else {
      DebugLog.add('[RT→] $type');
    }
    _channel?.sink.add(jsonEncode(event));
  }

  void _emit(RealtimeEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  /// Разбор одного сообщения сервера. Открыт для тестов.
  @visibleForTesting
  void handleMessage(String raw) => _onMessage(raw);

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
        _textParts.clear();
        _finalText = null;
        _emit(const ResponseStarted());
      // Новые и старые имена событий OpenAI Realtime.
      case 'response.output_audio.delta' || 'response.audio.delta':
        final delta = m['delta'] as String?;
        if (delta != null) _emit(AudioDelta(base64Decode(delta)));
      case 'response.output_text.delta' ||
            'response.output_audio_transcript.delta' ||
            'response.audio_transcript.delta':
        _textParts.write(m['delta'] as String? ?? '');
      case 'response.output_text.done':
        _keepFinal(m['text']);
      case 'response.output_audio_transcript.done' ||
            'response.audio_transcript.done':
        _keepFinal(m['transcript']);
      case 'conversation.item.input_audio_transcription.completed':
        _emit(UserTranscript(m['transcript'] as String? ?? ''));
      case 'response.done':
        final output = (m['response'] as Map?)?['output'] as List? ?? const [];
        final ids = output
            .whereType<Map>()
            .map((o) => o['id'])
            .whereType<String>()
            .toList();
        // Порядок: итоговый текст, собранные куски, текст внутри response.done.
        var text = _finalText ?? _textParts.toString();
        if (text.trim().isEmpty) text = _textFromOutput(output);
        DebugLog.add('[RT] текст ответа: ${text.length} симв.');
        _emit(AssistantTranscript(text));
        _emit(ResponseDone(ids));
      case 'error':
        final err = m['error'];
        final msg = err is Map ? (err['message'] ?? err).toString() : '$m';
        DebugLog.add('[RT] ошибка сервера: ${err ?? m}');
        _emit(RealtimeError(msg));
    }
  }

  void _keepFinal(Object? t) {
    if (t is String && t.trim().isNotEmpty) _finalText = t;
  }

  static String _textFromOutput(List output) {
    final b = StringBuffer();
    for (final item in output.whereType<Map>()) {
      for (final c in (item['content'] as List? ?? const []).whereType<Map>()) {
        final t = c['transcript'] ?? c['text'];
        if (t is String) b.write(t);
      }
    }
    return b.toString();
  }
}
