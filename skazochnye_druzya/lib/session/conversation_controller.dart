import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../audio/mic_stream.dart';
import '../audio/pcm_player.dart';
import '../characters.dart';
import '../child_memory.dart';
import '../child_profile.dart';
import '../config.dart';
import '../cost_meter.dart';
import '../debug_log.dart';
import '../prompts.dart';
import '../realtime/realtime_client.dart';
import '../safety/safety_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../scenes.dart';

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
/// Разговор полудуплексный: пока персонаж говорит, микрофон не передаёт
/// звук — это защищает от эха из динамика. Пока думает — передаёт:
/// малыш может договорить фразу после паузы.
class ConversationController extends ChangeNotifier {
  ConversationController({required this.character, required this.child});

  final CharacterProfile character;
  final ChildProfile child;

  TalkState state = TalkState.connecting;

  /// Открытость рта 0..1 для анимации.
  double mouth = 0;

  String? errorText;

  /// Счётчик расхода этого разговора (оценка в рублях).
  final cost = CostMeter(live: AppConfig.model == VoiceModel.live);

  /// Длины реплик — для оценки: на сервере остаются только последние.
  final _msgChars = <int>[];
  int _recentChars() {
    final n = trimBroken ? _msgChars.length : keepItems;
    final from = _msgChars.length > n ? _msgChars.length - n : 0;
    return _msgChars.skip(from).fold(0, (a, b) => a + b);
  }

  bool _usageLogged = false;
  bool _costLogged = false;

  // ── Короткая история ──────────────────────────────────────────────
  /// Сколько последних реплик держать на сервере. Сервер перечитывает всю
  /// историю на каждом ответе, и каждая реплика дорожает все следующие.
  static const keepItems = 14;

  /// id реплик главного соединения, по порядку.
  final _items = <String>[];
  DateTime? _lastTrimAt;

  /// Сервер не принял удаление — больше не пробуем (запоминается).
  static bool trimBroken = false;
  static const _kTrimBroken = 'history_trim_broken';

  static Future<void> loadTrimFlag() async {
    final p = await SharedPreferences.getInstance();
    trimBroken = p.getBool(_kTrimBroken) ?? false;
  }

  /// Удалить на сервере всё, что старше последних [keepItems] реплик.
  void _trimHistory() {
    if (trimBroken || !identical(_client, _main)) return;
    final extra = _items.length - keepItems;
    if (extra <= 0) return;
    final old = _items.sublist(0, extra);
    _items.removeRange(0, extra);
    old.forEach(_main.deleteItem);
    _lastTrimAt = DateTime.now();
    DebugLog.add('[История] удалено старых реплик: ${old.length}, '
        'осталось ${_items.length}');
  }

  /// Что сейчас показано на экране: счёт, прятки, загадка, картина дома.
  Scene? scene;

  /// Сколько ответа уже прозвучало, 0..1 — по нему появляются предметы
  /// счёта и слои картины.
  double speechProgress = 0;
  int _sceneAge = 0;

  /// Друг, которому сейчас «звонят»: он говорит своим голосом вместо
  /// главного персонажа. null — звонка нет.
  CharacterProfile? friend;

  /// Кто сейчас говорит.
  CharacterProfile get speaker => friend ?? character;

  CharacterProfile? _pendingCall;
  int _friendReplies = 0;
  bool _callEnding = false;
  String? _callInstructions;

  /// Отдельное соединение друга на время звонка: свой промпт, голос и
  /// чистая история. В общем соединении друг видел реплики главного
  /// персонажа и продолжал говорить за него.
  RealtimeClient? _friendClient;
  StreamSubscription<RealtimeEvent>? _friendSub;

  bool _justCalled = false;

  /// Что друг сказал за звонок — коротко передаём главному персонажу.
  final _friendLines = <String>[];

  /// Сколько реплик говорит друг (вместе с приветствием), прежде чем
  /// попрощаться: звонок короткий.
  static const _friendTurns = 3;

  /// Журнал реплик только в памяти, для отладки родителем. Не сохраняется.
  final log = <String>[];

  /// Активное соединение: главного персонажа или друга во время звонка.
  RealtimeClient _client = RealtimeClient();
  late final RealtimeClient _main = _client;
  final _mic = MicStream();
  final _player = PcmPlayer();
  final _audio = BytesBuilder(copy: false);
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _limitTimer;

  /// Пока персонаж слушает: раз в 5 с пишет в журнал, идёт ли звук,
  /// и через 15 с тишины сам продолжает разговор.
  Timer? _micLogTimer;
  Timer? _silenceTimer;
  int _silentNudges = 0;
  static const _silenceWait = Duration(seconds: 15);

  /// Больше двух раз подряд в тишину не говорим — ждём молча.
  static const _maxNudges = 2;

  /// История на этот разговор — случайная из нескольких, чтобы
  /// разговоры не повторялись.
  late final String _hook = character.randomHook();

  /// Три случайных факта на разговор вместо всех восьми — короче промпт,
  /// а от разговора к разговору факты разные.
  late final List<String> _facts =
      (List.of(character.facts)..shuffle()).take(3).toList();
  late final String _instructions = buildInstructions(
    character,
    child,
    hook: _hook,
    facts: _facts,
    memory: ChildMemory.facts,
    canRemember: ChildMemory.active,
  );

  /// Функцию «запомнить» отправили, а сервер ещё не подтвердил настройки:
  /// ошибка в это время — скорее всего, модель её не принимает.
  bool _toolsSent = false;
  bool _sessionReady = false;

  /// Модель вызвала «запомнить» и ничего не сказала — после ответа
  /// функции просим её продолжить разговор.
  bool _needFollowUp = false;

  String _transcript = '';

  /// Сервер начал отвечать, а ребёнок продолжил говорить: этот ответ
  /// на полфразы, его не играем, ждём ответ на всю фразу.
  bool _responseOpen = false;
  bool _dropOpenResponse = false;

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
    DebugLog.add(
        '[App] подключаемся к ${Uri.parse(AppConfig.realtimeUrl).host}, '
        '${AppConfig.model.label.toLowerCase()} модель, '
        'голос ${AppConfig.voiceFor(character)}');
    try {
      await _client.connect();
    } catch (e) {
      DebugLog.add('[App] не удалось подключиться: $e');
      _fail(connectErrorText(e));
      return;
    }
    if (_disposed) {
      await _client.close();
      return;
    }
    _sub = _main.events.listen((e) {
      // Пока идёт звонок, говорит соединение друга. Обрыв главного
      // соединения важен всегда.
      if (identical(_client, _main) || e is Disconnected) _onEvent(e);
    });
    cost.start();
    _toolsSent = ChildMemory.active;
    _configure(character, _instructions);

    _mic.muted = true; // персонаж говорит первым
    // Звук — в то соединение, что сейчас активно (во время звонка — другу).
    final micOk = await _mic.start((chunk) {
      cost.addInputAudio(chunk.length);
      _client.appendAudio(chunk);
    });
    if (_disposed) {
      await _mic.stop();
      await _client.close();
      return;
    }
    if (!micOk) {
      _fail('Нет доступа к микрофону. Разрешите его в настройках телефона.');
      return;
    }
    // Сервер мог закрыть связь, пока включался микрофон.
    if (_closed) return;

    _ask(greetingInstruction);

    _limitTimer = Timer(Duration(minutes: child.sessionMinutes), () {
      _wrapRequested = true;
      // Если ребёнок сейчас говорит, прощание будет после ответа на его фразу.
      if (state == TalkState.listening) _sayGoodbye();
    });
  }

  void _configure(CharacterProfile who, String instructions) {
    _client.configure(
      instructions: instructions,
      voice: AppConfig.voiceFor(who),
      tools: _toolsSent ? [ChildMemory.tool] : const [],
    );
  }

  /// Пауза по кнопке родителя.
  Future<void> pause() async {
    if (_closed || state == TalkState.connecting || state == TalkState.paused) {
      return;
    }
    // Состояние — до остановки звука, чтобы прерванный play() не открыл микрофон.
    _mic.muted = true;
    _set(TalkState.paused);
    // Отменять есть что, только пока сервер ещё готовит ответ.
    if (_responseOpen) _client.cancelResponse();
    await _player.stop();
  }

  void resume() {
    if (state != TalkState.paused) return;
    _resumeListening();
  }

  /// Касание персонажа во время речи — замолчать и слушать.
  Future<void> interrupt() async {
    if (state == TalkState.listening) {
      nudge();
      return;
    }
    if (state != TalkState.speaking) return;
    await _player.stop(); // play() вернётся и сам переведёт в listening
  }

  Future<void> finish() async {
    if (state == TalkState.finished) return;
    // Состояние меняем сразу, чтобы закрытие сокета не считалось обрывом.
    mouth = 0;
    _set(TalkState.finished);
    _logFinalCost();
    _limitTimer?.cancel();
    _mic.muted = true;
    await _mic.stop();
    await _player.stop();
    _restoreAfterCall();
    await _main.close();
  }

  void _onEvent(RealtimeEvent e) {
    switch (e) {
      case SpeechStarted():
        _silenceTimer?.cancel();
        _silentNudges = 0;
        if (state == TalkState.listening) _set(TalkState.childSpeaking);
        // Договаривает после паузы: микрофон во время «думает» не
        // выключаем, сервер дослушает и ответит на всю фразу.
        if (state == TalkState.thinking && !_mic.muted) {
          if (_responseOpen) _dropOpenResponse = true;
          _audio.clear();
          DebugLog.add('[App] ребёнок договаривает — ждём конец фразы');
          _set(TalkState.childSpeaking);
        }
      case SpeechStopped():
        // Микрофон не выключаем: если ребёнок продолжит после паузы,
        // сервер это услышит. Выключится перед тем, как персонаж заговорит.
        if (state == TalkState.childSpeaking || state == TalkState.listening) {
          _wait.reset();
          _wait.start();
          _set(TalkState.thinking);
        }
      case ResponseStarted():
        _audio.clear();
        _transcript = '';
        _firstAudio = false;
        _responseOpen = true;
        if (state == TalkState.listening || state == TalkState.childSpeaking) {
          _set(TalkState.thinking);
        }
      case AudioDelta(:final bytes):
        if (!_firstAudio) {
          _firstAudio = true;
          DebugLog.add('[Задержка] первый звук через ${_sec(_wait)} с');
        }
        cost.addOutputAudio(bytes.length);
        _audio.add(bytes);
      case AssistantTranscript(:final text):
        _transcript = text;
      case UserTranscript(:final text):
        if (text.trim().isNotEmpty) {
          log.add('Ребёнок: $text');
          _msgChars.add(text.length);
          // Что расслышал Яндекс — видно, когда «плохо понимает».
          DebugLog.add('[Ребёнок] $text');
        }
      case ResponseDone(:final itemIds, :final cancelled, :final usage):
        _responseOpen = false;
        _countCost(usage);
        _trimHistory();
        if (_dropOpenResponse) {
          _dropOpenResponse = false;
          _audio.clear();
          DebugLog.add('[App] ответ на полфразы пропущен');
          return;
        }
        if (cancelled) {
          _needFollowUp = false;
          _audio.clear();
          if (state == TalkState.thinking) _resumeListening();
          return;
        }
        _onResponseDone(itemIds);
      case RealtimeError(:final message):
        final t = _lastTrimAt;
        if (t != null &&
            DateTime.now().difference(t) < const Duration(seconds: 3)) {
          // Ошибка сразу после удаления — сервер его не принимает.
          trimBroken = true;
          SharedPreferences.getInstance()
              .then((p) => p.setBool(_kTrimBroken, true));
          DebugLog.add('[История] сервер не принял удаление старых реплик — '
              'больше не удаляем');
        }
        if (RealtimeClient.noteRole == 'system' &&
            message.toLowerCase().contains('role')) {
          RealtimeClient.noteRole = 'user';
          DebugLog.add('[App] сервер не принял служебное сообщение — '
              'дальше обычным, с пометкой');
        }
        if (_toolsSent && !_sessionReady && identical(_client, _main)) {
          // Разговор не должен ломаться из-за памяти: в следующий раз
          // подключимся без функции.
          ChildMemory.setToolsBroken(true);
          DebugLog.add('[Память] модель не приняла функцию «запомнить» — '
              'память выключена до смены модели');
        }
        errorText = message;
        if (!_disposed) notifyListeners();
      case Disconnected():
        if (!_closed) _fail('Связь прервалась.');
      case SessionReady():
        _sessionReady = true;
      case ItemCreated(:final id):
        if (identical(_client, _main)) _items.add(id);
      case FunctionCall(:final name, :final callId, :final arguments):
        _onFunctionCall(name, callId, arguments);
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
      if (_needFollowUp) {
        // Персонаж только запомнил и промолчал — пусть продолжит.
        _needFollowUp = false;
        _wait
          ..reset()
          ..start();
        _client.requestResponse();
        return;
      }
      _resumeListening();
      return;
    }
    _needFollowUp = false;

    // Пустой текст фильтр считает опасным: без него проверить нечего.
    final verdict = SafetyFilter.check(text);
    if (!verdict.ok) {
      log.add('[заблокировано: ${verdict.reason}] $text');
      DebugLog.add('[Safety] заблокировано: ${verdict.reason}');
      itemIds.forEach(_client.deleteItem);
      _items.removeWhere(itemIds.contains);
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

    log.add('${speaker.name}: $text');
    if (friend != null) _friendLines.add(text);
    DebugLog.add('[Ответ] ${friend == null ? '' : '(${friend!.name}) '}$text');
    // Сцена и звонок — только из ответа, который прошёл фильтр.
    _afterSafeText(text);
    // Перед речью — выключить микрофон, чтобы персонаж не слышал себя.
    _mic.muted = true;
    speechProgress = 0;
    _set(TalkState.speaking);
    final totalMs =
        pcm.length / 2 / AppConfig.sampleRate / child.speechRate * 1000;
    final clock = Stopwatch()..start();
    try {
      await _player.play(
        pcm,
        AppConfig.sampleRate,
        (level) {
          mouth = level;
          speechProgress =
              (clock.elapsedMilliseconds / totalMs).clamp(0.0, 1.0);
          if (!_disposed) notifyListeners();
        },
        rate: child.speechRate,
      );
    } catch (e) {
      DebugLog.add('[Audio] ошибка воспроизведения: $e');
    }
    mouth = 0;
    if (_disposed || state != TalkState.speaking) return;
    speechProgress = 1;

    if (friend != null) {
      if (_callEnding) {
        _finishCall();
        return;
      }
      _friendReplies++;
      if (_friendReplies >= _friendTurns) {
        _callEnding = true;
        _mic.muted = true;
        _ask(callGoodbyeInstruction(character));
        return;
      }
    } else if (_pendingCall != null && !_wrapRequested) {
      final f = _pendingCall!;
      _pendingCall = null;
      _beginCall(f);
      return;
    }
    _resumeListening();
  }

  /// По тексту ответа: что показать на экране и не пора ли звонить другу.
  void _afterSafeText(String text) {
    if (friend != null) {
      // Во время звонка сцен нет; друг может попрощаться раньше срока.
      if (SceneDetector.saysBye(text)) _callEnding = true;
      return;
    }
    // Первая реплика после звонка — рассказ о нём, а не новый звонок.
    _pendingCall = _justCalled
        ? null
        : SceneDetector.detectCall(
            text,
            characters.where((c) => c.id != character.id),
          );
    _justCalled = false;
    final next = SceneDetector.detect(text, current: scene);
    if (identical(next, scene) && scene != null) {
      // Прятки и загадка не висят вечно, если разговор ушёл в сторону.
      _sceneAge++;
      if (_sceneAge >= 4) scene = null;
    } else {
      scene = next;
      _sceneAge = 0;
      if (next != null) DebugLog.add('[Сцена] ${_sceneName(next)}');
    }
  }

  /// Учитывает расход ответа и пишет итог в журнал.
  void _countCost(Map<String, dynamic>? usage) {
    if (usage != null && !_usageLogged) {
      // Один раз показываем, что именно присылает сервер: по этому
      // видно, работает ли кеш и как считаются токены.
      _usageLogged = true;
      DebugLog.add('[Расход] сервер считает так: $usage');
    }
    cost.addResponse(
      usage: usage,
      contextChars:
          (_callInstructions ?? _instructions).length + _recentChars(),
      answerChars: _transcript.length,
    );
    _msgChars.add(_transcript.length);
    DebugLog.add('[Расход] ${cost.summary()}');
  }

  /// Итог разговора — один раз, при завершении или выходе.
  void _logFinalCost() {
    if (_costLogged || cost.responses == 0) return;
    _costLogged = true;
    DebugLog.add('[Расход] итог разговора: ${cost.summary()}');
  }

  static String _sceneName(Scene s) => switch (s) {
        CountScene(:final thing, :final n) => 'счёт: $thing × $n',
        HideScene(:final place) => 'прятки, куст ${place + 1}',
        GuessScene(:final animal) => 'загадка: ${animal ?? 'вопрос'}',
        HomeScene() => 'картина дома',
      };

  // ── Звонок другу ──────────────────────────────────────────────────

  /// Позвонить можно, пока персонаж слушает и никому не звонит.
  bool get canCall => state == TalkState.listening && friend == null;

  /// Кнопка-трубка: позвонить выбранному другу.
  void callFriend(CharacterProfile f) {
    if (!canCall || f.id == character.id) return;
    _stopListeningTimers();
    _beginCall(f);
  }

  Future<void> _beginCall(CharacterProfile f) async {
    DebugLog.add('[Звонок] ${character.name} звонит: ${f.name}');
    friend = f;
    _friendReplies = 0;
    _callEnding = false;
    _friendLines.clear();
    scene = null;
    _mic.muted = true;
    _set(TalkState.thinking);

    final fc = RealtimeClient();
    try {
      await fc.connect();
    } catch (e) {
      DebugLog.add('[Звонок] не дозвонились: $e');
      fc.dispose();
      friend = null;
      if (_closed) return;
      _ask(callFailedInstruction(f));
      return;
    }
    // Пока подключались, разговор могли закончить или положить трубку.
    if (_closed || friend != f) {
      fc.dispose();
      return;
    }
    _friendClient = fc;
    _friendSub = fc.events.listen((e) {
      if (identical(_client, fc)) _onEvent(e);
    });
    _callInstructions =
        '${buildInstructions(f, child, hook: f.hooks.first, canCall: false)}'
        '\n\n${callContext(character, _recap())}';
    fc.configure(
      instructions: _callInstructions!,
      voice: AppConfig.voiceFor(f),
    );
    _resetResponseState();
    _client = fc;
    _ask(callGreetingInstruction(character));
  }

  /// Последние реплики разговора — чтобы друг знал, о чём шла речь.
  String _recap() {
    final last = log.where((l) => !l.startsWith('[')).toList();
    return last.skip(last.length > 4 ? last.length - 4 : 0).join('\n');
  }

  void _resetResponseState() {
    _responseOpen = false;
    _dropOpenResponse = false;
    _needFollowUp = false;
    _audio.clear();
    _transcript = '';
  }

  /// Кнопка «положить трубку».
  Future<void> endCall() async {
    if (friend == null) return;
    if (_friendClient == null) {
      // Ещё дозваниваемся — просто не соединяем.
      friend = null;
      _resumeListening();
      return;
    }
    if (state == TalkState.speaking) {
      _callEnding = true;
      await _player.stop(); // play() вернётся и закончит звонок
      return;
    }
    if (state == TalkState.listening || state == TalkState.childSpeaking) {
      _stopListeningTimers();
      _mic.muted = true;
      _finishCall();
    } else {
      _callEnding = true; // друг договорит — и звонок закончится
    }
  }

  /// Закрыть соединение друга и вернуться к главному персонажу.
  void _restoreAfterCall() {
    final f = friend;
    if (f == null) return;
    DebugLog.add('[Звонок] закончен: ${f.name}');
    friend = null;
    _callEnding = false;
    _callInstructions = null;
    final fc = _friendClient;
    _friendClient = null;
    _client = _main;
    _resetResponseState();
    _friendSub?.cancel();
    _friendSub = null;
    fc?.dispose();
  }

  void _finishCall() {
    final f = friend;
    if (f == null) return;
    final said = _friendLines.join(' ');
    _restoreAfterCall();
    _justCalled = true;
    _mic.muted = true;
    _ask(afterCallInstruction(f, said));
  }

  void _stopListeningTimers() {
    _silenceTimer?.cancel();
    _micLogTimer?.cancel();
    _silentNudges = 0;
  }

  // ── Сцены: нажатия малыша и кнопка «мой дом» ──────────────────────

  /// Нажали на куст в прятках. Верный — персонаж выглядывает.
  bool tapHidePlace(int place) {
    final s = scene;
    if (s is! HideScene || s.place != place) return false;
    scene = null;
    DebugLog.add('[Сцена] малыш нашёл персонажа');
    if (state == TalkState.listening || state == TalkState.childSpeaking) {
      _stopListeningTimers();
      _mic.muted = true;
      _ask(foundInstruction(child.gender));
    } else {
      // Персонаж ещё говорит или думает: обрадуется, как только договорит.
      // Иначе находка терялась, и он снова звал «найди меня».
      _foundPending = true;
      notifyListeners();
    }
    return true;
  }

  bool _foundPending = false;

  /// Кнопка-домик: персонаж рассказывает, где живёт, и рисуется картина.
  void showHome() {
    if (!canStartGame) return;
    _stopListeningTimers();
    DebugLog.add('[App] кнопка «мой дом»');
    _mic.muted = true;
    _ask(homeInstruction);
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
    if (_foundPending) {
      _foundPending = false;
      scene = null; // ответ мог снова спрятать персонажа — он уже найден
      _mic.muted = true;
      _ask(foundInstruction(child.gender));
      return;
    }
    _client.markListening();
    _set(TalkState.listening);
    // Короткая пауза, чтобы хвост собственного голоса не попал в микрофон.
    await Future<void>.delayed(_echoGuard);
    if (state == TalkState.listening) {
      _mic.muted = false;
      _mic.takeStats();
      _watchListening();
    }
  }

  void _sayGoodbye() {
    // Время вышло посреди звонка — прощается главный персонаж.
    _restoreAfterCall();
    scene = null;
    _goodbyeSent = true;
    _mic.muted = true;
    _ask(goodbyeInstruction);
  }

  /// Просьба к модели: служебное сообщение с указанием и запрос ответа.
  static String _sec(Stopwatch w) =>
      (w.elapsedMilliseconds / 1000).toStringAsFixed(1);

  void _ask(String extra) {
    _wait.reset();
    _wait.start();
    _client.addSystemNote('Сейчас: $extra');
    _client.requestResponse();
    _set(TalkState.thinking);
  }

  /// Понятная причина для взрослого вместо текста исключения.
  /// Полный текст ошибки остаётся в журнале.
  @visibleForTesting
  static String connectErrorText(Object e) {
    final s = '$e';
    if (e is TimeoutException || s.contains('TimeoutException')) {
      return 'Сервер не отвечает. Проверьте интернет. Если включён VPN — '
          'выключите его и попробуйте ещё раз.';
    }
    if (s.contains('401') || s.contains('403')) {
      return 'Сервер не принял ключ. Проверьте API-ключ в настройках.';
    }
    if (s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable') ||
        s.contains('HandshakeException')) {
      return 'Нет интернета. Проверьте мобильную сеть или Wi-Fi.';
    }
    return 'Не удалось подключиться. Подробности — в журнале.';
  }

  void _fail(String message) {
    DebugLog.add('[App] $message');
    errorText = message;
    _mic.muted = true;
    _set(TalkState.error);
  }

  void _watchListening() {
    _micLogTimer?.cancel();
    _micLogTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (state != TalkState.listening && state != TalkState.childSpeaking) {
        t.cancel();
        return;
      }
      final st = _mic.takeStats();
      DebugLog.add('[Mic] за 5 с: кусков ${st.chunks}, '
          'громкость ${(st.peak * 100).round()}%');
    });
    _silenceTimer?.cancel();
    if (_silentNudges >= _maxNudges) return;
    _silenceTimer = Timer(_silenceWait, () {
      if (state == TalkState.listening) nudge(auto: true);
    });
  }

  /// Кнопка «Угадай, кто я»: персонаж начинает игру. Работает, пока он
  /// слушает — не перебиваем его на полуслове.
  bool get canStartGame => state == TalkState.listening && friend == null;

  void startGuessGame() {
    if (!canStartGame) return;
    _stopListeningTimers();
    DebugLog.add('[App] игра «Угадай, кто я»');
    _mic.muted = true;
    _ask(guessGameInstruction);
  }

  /// Персонаж сам продолжает разговор: малыш молчит, или взрослый
  /// нажал на персонажа, пока тот слушает.
  void nudge({bool auto = false}) {
    if (state != TalkState.listening) return;
    _silenceTimer?.cancel();
    _micLogTimer?.cancel();
    if (auto) _silentNudges++;
    DebugLog.add(auto
        ? '[App] тишина ${_silenceWait.inSeconds} с — персонаж продолжает сам'
        : '[App] нажали на персонажа — он продолжает сам');
    _mic.muted = true;
    _ask(silenceInstruction);
  }

  void _onFunctionCall(String name, String callId, Map<String, dynamic> args) {
    if (name != 'remember') {
      _client.sendFunctionOutput(callId, 'Такой функции нет.');
      _needFollowUp = true;
      return;
    }
    final fact = (args['fact'] as String? ?? '').trim();
    final why = ChildMemory.remember(fact);
    if (why == null) {
      DebugLog.add('[Память] запомнил: $fact');
      _client.sendFunctionOutput(callId, 'Запомнил.');
    } else {
      DebugLog.add('[Память] не запомнил ($why): $fact');
      _client.sendFunctionOutput(
        callId,
        'Это не запоминай: такое знают только мама и папа. '
        'Просто продолжай разговор и не говори об этом.',
      );
    }
    _needFollowUp = true;
  }

  void _set(TalkState s) {
    state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _logFinalCost();
    _disposed = true;
    _limitTimer?.cancel();
    _micLogTimer?.cancel();
    _silenceTimer?.cancel();
    _sub?.cancel();
    _mic.dispose();
    _player.dispose();
    _friendSub?.cancel();
    _friendClient?.dispose();
    _main.dispose();
    log.clear();
    super.dispose();
  }
}
