import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/cost_meter.dart';

void main() {
  // 1 секунда звука PCM16 моно при 44100 Гц.
  const sec = 44100 * 2;

  test('звук считается по секундам и по прайсу', () {
    final m = CostMeter(live: false, sampleRate: 44100)
      ..addInputAudio(sec * 25)
      ..addOutputAudio(sec * 30);
    expect(m.inSeconds, 25);
    expect(m.outSeconds, 30);
    expect(m.audioRub, closeTo(25 * 0.0264 + 30 * 0.0203, 1e-9));
  });

  test('живые голоса дороже', () {
    final m = CostMeter(live: true, sampleRate: 44100)
      ..addOutputAudio(sec * 30);
    expect(m.audioRub, closeTo(30 * 0.05, 1e-9));
  });

  test('токены из ответа сервера, кеш дешевле', () {
    final m = CostMeter(live: false)
      ..addResponse(
        usage: {
          'input_tokens': 3000,
          'output_tokens': 40,
          'input_token_details': {'cached_tokens': 2000},
        },
        contextChars: 99999,
        answerChars: 99999,
      );
    expect(m.estimated, isFalse);
    expect(m.inTokens, 3000);
    expect(m.cachedTokens, 2000);
    expect(m.textRub, closeTo(1.0 * 0.3 + 2.0 * 0.075 + 0.04 * 0.5, 1e-9));
  });

  test('если сервер делит токены — берём только текстовые', () {
    final m = CostMeter(live: false)
      ..addResponse(
        usage: {
          'input_tokens': 5000,
          'output_tokens': 900,
          'input_token_details': {'text_tokens': 3000, 'audio_tokens': 2000},
          'output_token_details': {'text_tokens': 50, 'audio_tokens': 850},
        },
        contextChars: 0,
        answerChars: 0,
      );
    expect(m.inTokens, 3000);
    expect(m.outTokens, 50);
  });

  test('сервер не прислал токены — оценка по символам, с пометкой', () {
    final m = CostMeter(live: false)
      ..addResponse(usage: null, contextChars: 6000, answerChars: 90);
    expect(m.estimated, isTrue);
    expect(m.inTokens, 2000);
    expect(m.outTokens, 30);
    expect(m.summary(), contains('оценка'));
  });

  test('итоговая строка: рубли, секунды, токены', () {
    final m = CostMeter(live: true, sampleRate: 44100)
      ..addInputAudio(sec * 10)
      ..addOutputAudio(sec * 20)
      ..addResponse(
        usage: {'input_tokens': 1000, 'output_tokens': 100},
        contextChars: 0,
        answerChars: 0,
      );
    // 10·0,0264 + 20·0,05 + 0,3 + 0,05 = 1,61
    expect(m.rub, closeTo(1.614, 1e-9));
    final s = m.summary();
    expect(s, contains('1,61 ₽'));
    expect(s, contains('микрофон 10 с'));
    expect(s, contains('речь 20 с'));
    expect(s, contains('1000 вх / 100 вых'));
  });
}
