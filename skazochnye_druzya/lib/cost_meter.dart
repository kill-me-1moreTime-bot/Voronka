import 'config.dart';

/// Счётчик расхода одного разговора: сколько секунд звука ушло и пришло,
/// сколько токенов текста — и оценка в рублях по прайсу Яндекса.
///
/// Это оценка для ориентира, а не счёт: точные суммы — в биллинге
/// Yandex Cloud. Цены — с НДС, со страницы тарифов AI Studio
/// (aistudio.yandex.ru/docs/ru/ai-studio/pricing) на ноябрь 2026 года.
class CostMeter {
  CostMeter({required this.live, this.sampleRate = AppConfig.sampleRate});

  /// Модель «Живые голоса»: её речь дороже.
  final bool live;
  final int sampleRate;

  static const inAudioPerSec = 0.0264;
  static const outAudioPerSec = 0.0203;
  static const outLiveAudioPerSec = 0.05;
  static const inTextPer1k = 0.3;
  static const cachedTextPer1k = 0.075;
  static const outTextPer1k = 0.5;

  /// Средняя длина токена для русского текста — когда сервер не
  /// прислал точные числа и токены приходится оценивать по символам.
  static const charsPerToken = 3.0;

  int _inBytes = 0;
  int _outBytes = 0;
  int inTokens = 0;
  int cachedTokens = 0;
  int outTokens = 0;
  int responses = 0;

  /// true — токены посчитаны по символам, сервер их не прислал.
  bool estimated = false;

  final _clock = Stopwatch();

  void start() => _clock.start();

  /// Звук с микрофона, отправленный на сервер (PCM16 моно).
  void addInputAudio(int bytes) => _inBytes += bytes;

  /// Звук ответа, пришедший с сервера. Оплачивается, даже если ответ
  /// не прозвучал (отменён или не прошёл фильтр).
  void addOutputAudio(int bytes) => _outBytes += bytes;

  double get inSeconds => _inBytes / 2 / sampleRate;
  double get outSeconds => _outBytes / 2 / sampleRate;
  double get minutes => _clock.elapsedMilliseconds / 60000;

  /// Токены одного ответа. [usage] — что прислал сервер в response.done
  /// (формат OpenAI Realtime); если его нет — оценка по длине промпта и
  /// разговора ([contextChars]) и ответа ([answerChars]).
  void addResponse({
    Map<String, dynamic>? usage,
    required int contextChars,
    required int answerChars,
  }) {
    responses++;
    final input = _int(usage?['input_tokens']);
    final output = _int(usage?['output_tokens']);
    if (usage == null || (input == 0 && output == 0)) {
      estimated = true;
      inTokens += (contextChars / charsPerToken).round();
      outTokens += (answerChars / charsPerToken).round();
      return;
    }
    final inD = usage['input_token_details'];
    final outD = usage['output_token_details'];
    // Звук Яндекс считает секундами, поэтому из токенов берём только
    // текстовые, если сервер их разделяет.
    final cached = inD is Map ? _int(inD['cached_tokens']) : 0;
    final inText = inD is Map && inD['text_tokens'] != null
        ? _int(inD['text_tokens'])
        : input;
    final outText = outD is Map && outD['text_tokens'] != null
        ? _int(outD['text_tokens'])
        : output;
    cachedTokens += cached.clamp(0, inText);
    inTokens += inText;
    outTokens += outText;
  }

  static int _int(Object? v) => v is num ? v.round() : 0;

  double get audioRub =>
      inSeconds * inAudioPerSec +
      outSeconds * (live ? outLiveAudioPerSec : outAudioPerSec);

  double get textRub =>
      (inTokens - cachedTokens) / 1000 * inTextPer1k +
      cachedTokens / 1000 * cachedTextPer1k +
      outTokens / 1000 * outTextPer1k;

  double get rub => audioRub + textRub;

  double get rubPerMinute => minutes < 0.05 ? 0 : rub / minutes;

  static String _r(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  /// Строка для журнала.
  String summary() {
    final tokens = '$inTokens вх'
        '${cachedTokens > 0 ? ' (из кеша $cachedTokens)' : ''}'
        ' / $outTokens вых${estimated ? ', оценка' : ''}';
    return 'примерно ${_r(rub)} ₽ за ${minutes.toStringAsFixed(1)} мин'
        '${rubPerMinute > 0 ? ' (${_r(rubPerMinute)} ₽/мин)' : ''}: '
        'микрофон ${inSeconds.round()} с — ${_r(inSeconds * inAudioPerSec)} ₽, '
        'речь ${outSeconds.round()} с — '
        '${_r(outSeconds * (live ? outLiveAudioPerSec : outAudioPerSec))} ₽, '
        'текст $tokens — ${_r(textRub)} ₽';
  }
}
