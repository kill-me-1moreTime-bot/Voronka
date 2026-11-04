import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../audio/mic_stream.dart';
import '../audio/pcm_player.dart';
import '../characters.dart';
import '../child_profile.dart';
import '../config.dart';
import '../debug_log.dart';
import '../prompts.dart';
import '../realtime/realtime_client.dart';
import '../safety/safety_filter.dart';

enum TalkState {
  connecting,
  listening,
  childSpeaking,
  thinking,
  speaking,
  paused,
  finished,
  error,
}

/// Ведёт один разговор с персонажем.
///
/// Разговор полудуплексный: пока персонаж думает и говорит, микрофон
/// не передаёт звук. Это защищает от эха из динамика и проще для малыша.
class ConversationController extends ChangeNotifier {
  ConversationController({required this.character, required this.child});

  final CharacterProfile character;
  final ChildProfile child;

  TalkState state = TalkState.connecting;

  /// Открытость рта 0..1 для анимации.
  double mouth = 0;

  String? errorText;

  /// Журнал реплик только в памяти, для отладки родителем. Не сохраняется.
  final log = <String>[];

  final _client = RealtimeClient();
  final _mic = MicStream();
  final _player = PcmPlayer();
  final _audio = BytesBuilder(copy: false);
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _limitTimer;

  late final String _instructions = buildInstructions(character, child);

  String _transcript = '';

  /// Замер задержки: от конца фразы ребёнка (или просьбы) до готового ответа.
  final _wait = Stopwatch();
  bool _firstAudio = false;

  /// Сколько ждать после конца звука, прежде чем открыть микрофон.
  /// Звук выходит из динамика с задержкой, а микрофон отдаёт кусками
  /// по ~0,1–0,2 с. Без запаса хвост фразы попадёт в микрофон, и
  /// сервер решит, что ребёнок заговорил. С Bluetooth-колонкой может
  /// понадобиться больше.
  static const _echoGuard = Duration(milliseconds: 500);
  int _safetyRetries = 0;
  bool _wrapRequested = false;
  bool _goodbyeSent = false;
  bool _disposed = false;

  bool get _closed =>
      _disposed || state == TalkState.finished || state == TalkState.error;

  Future<void> start() async {
    if (!AppConfig.isConfigured) {
      _fail('Не заданы адрес и ключ. Откройте настройки для родителей.');
      return;
    }
    DebugLog.clear();
    DebugLog.add('[App] подключаемся к ${Uri.parse(AppConfig.realtimeUrl).host}, '
        'голос ${character.voice}');
    try {
      await _client.connect();
    } catch (e) {
      _fail('Не удалось подключиться: $e');
      return;
    }
    if (_disposed) {
      await _client.close();
      return;
    }
    _sub = _client.events.listen(_onEvent);
    _client.configure(instructions: _instructions, voice: character.voice);

    _mic.muted = true; // персонаж говорит первым
    final micOk = await _mic.start(_client.appendAudio);
    if (_disposed) {
      await _mic.stop();
      await _client.close();
      return;
    }
    if (!micOk) {
      _fail('Нет доступа к микрофону. Разрешите его в настройках телефона.');
      return;
    }

    _ask(greetingInstruction);

    _limitTimer = Timer(Duration(minutes: child.sessionMinutes), () {
      _wrapRequested = true;
      // Если ребёнок сейчас говорит, прощание будет после ответа на его фразу.
      if (state == TalkState.listening) _sayGoodbye();
    });
  }

  /// Пауза по кнопке родителя.
  Future<void> pause() async {
    if (_closed || state == TalkState.connecting || state == TalkState.paused) {
      return;
    }
    // Состояние — до остановки звука, чтобы прерванный play() не открыл микрофон.
    _mic.muted = true;
    _set(TalkState.paused);
    _client.cancelResponse();
    await _player.stop();
  }

  void resume() {
    if (state != TalkState.paused) return;
    _resumeListening();
  }

  /// Касание персонажа во время речи — замолчать и слушать.
  Future<void> interrupt() async {
    if (state != TalkState.speaking) return;
    await _player.stop(); // play() вернётся и сам переведёт в listening
  }

  Future<void> finish() async {
    if (state == TalkState.finished) return;
    // Состояние меняем сразу, чтобы закрытие сокета не считалось обрывом.
    mouth = 0;
    _set(TalkState.finished);
    _limitTimer?.cancel();
    _mic.muted = true;
    await _mic.stop();
    await _player.stop();
    await _client.close();
  }

  void _onEvent(RealtimeEvent e) {
    switch (e) {
      case SpeechStarted():
        if (state == TalkState.listening) _set(TalkState.childSpeaking);
      case SpeechStopped():
        if (state == TalkState.childSpeaking || state == TalkState.listening) {
          _mic.muted = true;
          _wait.reset();
          _wait.start();
          _set(TalkState.thinking);
        }
      case ResponseStarted():
        _audio.clear();
        _transcript = '';
        _firstAudio = false;
        if (state == TalkState.listening || state == TalkState.childSpeaking) {
          _mic.muted = true;
          _set(TalkState.thinking);
        }
      case AudioDelta(:final bytes):
        if (!_firstAudio) {
          _firstAudio = true;
          DebugLog.add('[Задержка] первый звук через ${_sec(_wait)} с');
        }
        _audio.add(bytes);
      case AssistantTranscript(:final text):
        _transcript = text;
      case UserTranscript(:final text):
        if (text.trim().isNotEmpty) log.add('Ребёнок: $text');
      case ResponseDone(:final itemIds):
        _onResponseDone(itemIds);
      case RealtimeError(:final message):
        errorText = message;
        if (!_disposed) notifyListeners();
      case Disconnected():
        if (!_closed) _fail('Связь прервалась.');
      case SessionReady():
        break;
    }
  }

  Future<void> _onResponseDone(List<String> itemIds) async {
    final pcm = _audio.takeBytes();
    final text = _transcript;
    DebugLog.add('[Задержка] ответ целиком через ${_sec(_wait)} с, '
        'длина ${(pcm.length / 2 / AppConfig.sampleRate).toStringAsFixed(1)} с, '
        'текст ${text.length} симв.');
    // Ответы, пришедшие после паузы или отмены, не играем.
    if (state != TalkState.thinking) return;

    if (pcm.isEmpty) {
      _resumeListening();
      return;
    }

    // Пустой текст фильтр считает опасным: без него проверить нечего.
    final verdict = SafetyFilter.check(text);
    if (!verdict.ok) {
      log.add('[заблокировано: ${verdict.reason}] $text');
      DebugLog.add('[Safety] заблокировано: ${verdict.reason}');
      itemIds.forEach(_client.deleteItem);
      _safetyRetries++;
      if (_safetyRetries <= 2) {
        _ask(_safetyRetries == 1
            ? SafetyFilter.redirectInstruction
            : SafetyFilter.fallbackInstruction);
        return;
      }
      _safetyRetries = 0;
      _resumeListening();
      return;
    }
    _safetyRetries = 0;

    log.add('${character.name}: $text');
    _set(TalkState.speaking);
    try {
      await _player.play(pcm, AppConfig.sampleRate, (level) {
        mouth = level;
        if (!_disposed) notifyListeners();
      });
    } catch (e) {
      DebugLog.add('[Audio] ошибка воспроизведения: $e');
    }
    mouth = 0;
    if (_disposed || state != TalkState.speaking) return;
    _resumeListening();
  }

  Future<void> _resumeListening() async {
    if (_closed) return;
    if (_goodbyeSent) {
      await finish();
      return;
    }
    if (_wrapRequested) {
      _sayGoodbye();
      return;
    }
    _client.markListening();
    _set(TalkState.listening);
    // Короткая пауза, чтобы хвост собственного голоса не попал в микрофон.
    await Future<void>.delayed(_echoGuard);
    if (state == TalkState.listening) _mic.muted = false;
  }

  void _sayGoodbye() {
    _goodbyeSent = true;
    _mic.muted = true;
    _ask(goodbyeInstruction);
  }

  /// Просьба к модели. Инструкции ответа в протоколе Realtime заменяют
  /// промпт сессии, поэтому промпт персонажа отправляется вместе с ними.
  static String _sec(Stopwatch w) =>
      (w.elapsedMilliseconds / 1000).toStringAsFixed(1);

  void _ask(String extra) {
    _wait.reset();
    _wait.start();
    _client.requestResponse(
      instructions: '$_instructions\n\n## Сейчас\n$extra',
    );
    _set(TalkState.thinking);
  }

  void _fail(String message) {
    DebugLog.add('[App] $message');
    errorText = message;
    _mic.muted = true;
    _set(TalkState.error);
  }

  void _set(TalkState s) {
    state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _limitTimer?.cancel();
    _sub?.cancel();
    _mic.dispose();
    _player.dispose();
    _client.dispose();
    log.clear();
    super.dispose();
  }
}
