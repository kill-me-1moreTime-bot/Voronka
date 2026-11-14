import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/realtime/realtime_client.dart';

/// Разбор событий сервера: текст ответа должен дойти до фильтра
/// безопасности при любом способе, каким его присылает сервер.
void main() {
  Future<List<RealtimeEvent>> run(List<Map<String, Object?>> msgs) async {
    final c = RealtimeClient();
    final got = <RealtimeEvent>[];
    final sub = c.events.listen(got.add);
    for (final m in msgs) {
      c.handleMessage(jsonEncode(m));
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return got;
  }

  String textOf(List<RealtimeEvent> ev) =>
      ev.whereType<AssistantTranscript>().single.text;

  test('Yandex: текст кусками output_text.delta', () async {
    final ev = await run([
      {'type': 'response.created'},
      {'type': 'response.output_text.delta', 'delta': 'Привет, '},
      {
        'type': 'response.output_audio.delta',
        'delta': base64Encode([1, 2])
      },
      {'type': 'response.output_text.delta', 'delta': 'малыш!'},
      {
        'type': 'response.done',
        'response': {'output': []}
      },
    ]);
    expect(textOf(ev), 'Привет, малыш!');
    expect(ev.whereType<AudioDelta>().single.bytes, [1, 2]);
    // Текст приходит раньше, чем конец ответа: фильтр проверяет его до звука.
    expect(ev.indexWhere((e) => e is AssistantTranscript),
        lessThan(ev.indexWhere((e) => e is ResponseDone)));
  });

  test('OpenAI: итоговая расшифровка звука важнее кусков', () async {
    final ev = await run([
      {'type': 'response.created'},
      {'type': 'response.output_audio_transcript.delta', 'delta': 'Прив'},
      {
        'type': 'response.output_audio_transcript.done',
        'transcript': 'Привет!'
      },
      {
        'type': 'response.done',
        'response': {'output': []}
      },
    ]);
    expect(textOf(ev), 'Привет!');
  });

  test('текст только внутри response.done', () async {
    final ev = await run([
      {'type': 'response.created'},
      {
        'type': 'response.done',
        'response': {
          'output': [
            {
              'id': 'item1',
              'content': [
                {'type': 'output_audio', 'transcript': 'Давай рисовать!'},
              ],
            },
          ],
        },
      },
    ]);
    expect(textOf(ev), 'Давай рисовать!');
    expect(ev.whereType<ResponseDone>().single.itemIds, ['item1']);
  });

  test('текст прошлого ответа не переносится в новый', () async {
    final ev = await run([
      {'type': 'response.created'},
      {'type': 'response.output_text.delta', 'delta': 'Первый'},
      {
        'type': 'response.done',
        'response': {'output': []}
      },
      {'type': 'response.created'},
      {
        'type': 'response.done',
        'response': {'output': []}
      },
    ]);
    final texts = ev.whereType<AssistantTranscript>().map((e) => e.text);
    expect(texts, ['Первый', '']);
  });

  test('отменённый сервером ответ помечен — его не играем', () async {
    final ev = await run([
      {'type': 'response.created'},
      {'type': 'response.output_text.delta', 'delta': 'Полфразы'},
      {
        'type': 'response.done',
        'response': {'status': 'cancelled', 'output': []},
      },
    ]);
    expect(ev.whereType<ResponseDone>().single.cancelled, isTrue);
  });

  test('обычный ответ не помечен отменённым', () async {
    final ev = await run([
      {'type': 'response.created'},
      {
        'type': 'response.done',
        'response': {'status': 'completed', 'output': []},
      },
    ]);
    expect(ev.whereType<ResponseDone>().single.cancelled, isFalse);
  });

  test('вызов функции «запомнить» разбирается', () async {
    final ev = await run([
      {
        'type': 'response.output_item.done',
        'item': {
          'type': 'function_call',
          'name': 'remember',
          'call_id': 'c1',
          'arguments': '{"fact":"кота зовут Барсик"}',
        },
      },
    ]);
    final f = ev.whereType<FunctionCall>().single;
    expect(f.name, 'remember');
    expect(f.callId, 'c1');
    expect(f.arguments['fact'], 'кота зовут Барсик');
  });

  test('сломанные аргументы функции не роняют разбор', () async {
    final ev = await run([
      {
        'type': 'response.output_item.done',
        'item': {
          'type': 'function_call',
          'name': 'remember',
          'call_id': 'c2',
          'arguments': '{сломано',
        },
      },
    ]);
    expect(ev.whereType<FunctionCall>().single.arguments, isEmpty);
  });

  test('«нечего отменять» не считается ошибкой', () async {
    final ev = await run([
      {
        'type': 'error',
        'error': {'code': 'response_cancel_not_active', 'message': 'x'},
      },
      {
        'type': 'error',
        'error': {'code': 'other', 'message': 'настоящая'},
      },
    ]);
    expect(ev.whereType<RealtimeError>().map((e) => e.message), ['настоящая']);
  });
}
