import 'dart:math';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/characters.dart';
import 'package:skazochnye_druzya/child_profile.dart';
import 'package:skazochnye_druzya/prompts.dart';
import 'package:skazochnye_druzya/scenes.dart';
import 'package:skazochnye_druzya/ui/home_painter.dart';
import 'package:skazochnye_druzya/ui/scene_view.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadCharacters();
  });

  Scene? d(String t, [Scene? cur]) =>
      SceneDetector.detect(t, current: cur, rnd: Random(1));

  group('счёт', () {
    test('«посчитаем шишки» — шишки, пять штук', () {
      final s = d('Давай посчитаем шишки вместе!') as CountScene;
      expect(s.thing, 'cone');
      expect(s.n, 5);
    });

    test('число на экране — самое большое названное', () {
      final s = d('Посчитаем малинки: раз, два, три!') as CountScene;
      expect(s.thing, 'raspberry');
      expect(s.n, 3);
    });

    test('продолжение счёта без названия предмета', () {
      final s =
          d('Раз, два, три, четыре!', const CountScene('🥕', 2)) as CountScene;
      expect(s.thing, '🥕');
      expect(s.n, 4);
    });

    test('не больше десяти', () {
      final s = d('Сколько звёздочек? Девять, десять!') as CountScene;
      expect(s.n, 10);
    });

    test('просто упомянул морковку — сцены нет', () {
      expect(d('Я потеряла свою морковку в траве.'), isNull);
      expect(d('Ты любишь малину?'), isNull);
    });

    test('«раз» внутри слова — не число', () {
      expect(SceneDetector.numerals('Какие разные цветы, два цвета'), [2]);
    });

    test('предметы появляются по одному, к концу фразы — все', () {
      expect(SceneViewTest.visible(5, 0), 0);
      expect(SceneViewTest.visible(5, 0.5), 2);
      expect(SceneViewTest.visible(5, 1), 5);
    });
  });

  group('прятки', () {
    test('спрятался — три куста, персонаж за одним', () {
      final s = d('Я спрятался! Найди меня!') as HideScene;
      expect(s.place, inInclusiveRange(0, 2));
    });

    test('пока не нашли — прячется дальше', () {
      const cur = HideScene(1);
      expect(d('Я тут, совсем рядом. Ищи лучше!', cur), same(cur));
    });

    test('нашли — сцена убирается', () {
      expect(d('Ура, ты меня нашёл!', const HideScene(1)), isNull);
    });
  });

  group('угадай, кто я', () {
    test('загадка — знак вопроса, отгадка — зверь', () {
      final q = d('Я говорю му-у и даю молоко. Угадай, кто я!') as GuessScene;
      expect(q.animal, isNull);
      final hint = d('Подсказка: у меня рожки.', q);
      expect(hint, same(q));
      final a = d('Правильно, это корова!', q) as GuessScene;
      expect(a.animal, '🐄');
    });

    test('«совсем» — не сова', () {
      const q = GuessScene();
      expect(d('Ты совсем близко!', q), same(q));
      expect((d('Это сова!', q) as GuessScene).animal, '🦉');
    });

    test('после отгадки следующий ответ убирает картинку', () {
      expect(
          d('Молодец! Во что ещё поиграем?', const GuessScene('🐄')), isNull);
    });
  });

  group('дом', () {
    test('«я живу» — картина дома', () {
      expect(d('Я живу в уютной берлоге под старой елью.'), isA<HomeScene>());
    });

    test('«живут» про других — нет', () {
      expect(d('Волки живут дружной стаей.'), isNull);
    });

    test('у всех шести персонажей картина рисуется на любом шаге', (() async {
      for (final c in characters) {
        for (final p in [0.0, 0.4, 1.0, 2.5, 3.9, 5.2, 6.0]) {
          final rec = PictureRecorder();
          HomePainter(character: c, progress: p)
              .paint(Canvas(rec), const Size(390, 360));
          rec.endRecording();
        }
      }
    }));
  });

  group('звонок другу', () {
    test('«позвоним Зайке» — звоним Зайке', () {
      final bear = characters.firstWhere((c) => c.id == 'bear');
      final others = characters.where((c) => c.id != 'bear');
      expect(SceneDetector.detectCall('Давай позвоним Зайке!', others)?.id,
          'bunny');
      expect(
          SceneDetector.detectCall('А давай позвоним Поросёнку Боре?', others)
              ?.id,
          'pig');
      // Себе не звонит, без «позвоним» — тоже нет.
      expect(SceneDetector.detectCall('Позвоним Мишке!', others), isNull);
      expect(SceneDetector.detectCall('Зайка любит морковку.', others), isNull);
      expect(bear.name, 'Мишка Топтыжка');
    });

    test('на «позвони маме» никому не звонит', () {
      expect(
          SceneDetector.detectCall(
              'Я умею звонить только сказочным друзьям.', characters),
          isNull);
    });

    test('друг попрощался — звонок заканчивается', () {
      expect(SceneDetector.saysBye('Пока, Ева! Пока, Мишка!'), isTrue);
      expect(SceneDetector.saysBye('Покажи мне мячик!'), isFalse);
    });

    test('промпт друга на звонке: его характер и кто позвонил', () {
      final bear = characters.firstWhere((c) => c.id == 'bear');
      final bunny = characters.firstWhere((c) => c.id == 'bunny');
      final p = '${buildInstructions(bunny, const ChildProfile())}'
          '\n\n${callContext(bear)}';
      expect(p, contains('Ты — Зайка Зоя'));
      expect(p, contains('позвонил твой друг Мишка Топтыжка'));
      expect(p, contains('спички')); // правила безопасности на месте
      expect(callGoodbyeInstruction(bear), contains('пока'));
    });

    test('в промпте: звонить только сказочным друзьям', () {
      final bear = characters.firstWhere((c) => c.id == 'bear');
      final p = buildInstructions(bear, const ChildProfile());
      expect(p, contains('Давай позвоним'));
      expect(p, contains('только сказочным друзьям'));
      expect(p, contains('## Что малыш видит на экране'));
    });
  });

  testWidgets('сцены строятся; верный куст находит персонажа', (t) async {
    final bear = characters.first;
    int? tapped;
    for (final s in <Scene>[
      const CountScene('cone', 5),
      const CountScene('🥕', 10),
      const GuessScene(),
      const GuessScene('🐄'),
      const HomeScene(),
      const HideScene(2),
    ]) {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SceneView(
            scene: s,
            character: bear,
            progress: 1,
            onHideTap: (i) {
              tapped = i;
              return i == 2;
            },
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull, reason: '$s');
    }
    // Последняя сцена — прятки: нажимаем третий куст.
    // Кусты по 150 в ширину, по центру экрана.
    final box = t.getRect(find.byType(SceneView));
    await t.tapAt(Offset(box.center.dx + 150, box.center.dy + 50));
    await t.pump(const Duration(milliseconds: 500));
    expect(tapped, 2);
    // Убираем бесконечные анимации персонажа перед концом теста.
    await t.pumpWidget(const SizedBox());
  });

  group('звонок: отдельный промпт друга', () {
    test('о прошлом звонке — не новый звонок', () {
      final others = characters.where((c) => c.id != 'pig');
      expect(
          SceneDetector.detectCall(
              'Как здорово, что мы позвонили Зайке!', others),
          isNull);
      expect(
          SceneDetector.detectCall('А теперь я позвоню Лисичке!', others)?.id,
          'fox');
    });

    test('у друга на звонке нет «давай позвоним», у главного — есть', () {
      final pig = characters.firstWhere((c) => c.id == 'pig');
      final bunny = characters.firstWhere((c) => c.id == 'bunny');
      final friend =
          buildInstructions(bunny, const ChildProfile(), canCall: false);
      expect(friend, isNot(contains('Давай позвоним')));
      final ctx = callContext(pig, 'Поросёнок Боря: Давай позвоним Зайке!');
      expect(ctx, contains('а не Поросёнок Боря'));
      expect(ctx, contains('не проси ничего нажимать'));
      expect(ctx, contains('Давай позвоним Зайке'));
      final main = buildInstructions(pig, const ChildProfile());
      expect(main, contains('Ничего нажимать малышу не нужно'));
    });

    test('после звонка главный персонаж знает, что сказал друг', () {
      final bunny = characters.firstWhere((c) => c.id == 'bunny');
      final s = afterCallInstruction(bunny, 'Привет! Я собираю цветочки.');
      expect(s, contains('Зайка Зоя говорила'));
      expect(s, contains('собираю цветочки'));
      expect(s, contains('Больше не звони'));
    });
  });
}
