import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/characters.dart';
import 'package:skazochnye_druzya/child_profile.dart';
import 'package:skazochnye_druzya/prompts.dart';
import 'package:skazochnye_druzya/safety/safety_filter.dart';

void main() {
  late CharacterProfile bear;
  late CharacterProfile bunny;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadCharacters();
    bear = characters.firstWhere((c) => c.id == 'bear');
    bunny = characters.firstWhere((c) => c.id == 'bunny');
  });

  test('правила безопасности на месте', () {
    final p = buildInstructions(bear, const ChildProfile());
    for (final must in [
      'спички',
      'розетки',
      'лекарства',
      'секреты от родителей',
      'не повторяй',
      'ничего покупать',
      'позвать маму или папу',
      'сказочный',
      'через телефон',
    ]) {
      expect(p, contains(must), reason: must);
    }
  });

  test('на обычные вопросы отвечает сам', () {
    final p = buildInstructions(bear, const ChildProfile());
    expect(p, contains('отвечай сам'));
    expect(p, contains('не больше двадцати слов'));
    // Старое правило «на любой вопрос — к маме» больше не стоит.
    expect(p, isNot(contains('На любой вопрос, где нужен взрослый')));
  });

  test('не подсказывает модели добавлять «да или нет?»', () {
    final p = buildInstructions(bear, const ChildProfile());
    expect(p, isNot(contains('«да или нет?»')));
    expect(p, contains('Не добавляй к вопросу «да или нет»'));
  });

  test('заметки родителей попадают в промпт, пустые — нет', () {
    const notes = 'Кота зовут Барсик.';
    expect(buildInstructions(bear, const ChildProfile(notes: notes)),
        contains(notes));
    expect(buildInstructions(bear, const ChildProfile()),
        isNot(contains('Что рассказали родители')));
  });

  test('у каждого персонажа есть голос для обеих моделей', () {
    const live = {'sofia', 'vera', 'irina', 'vasily', 'sergey', 'denis'};
    for (final c in characters) {
      expect(live, contains(c.liveVoice), reason: c.id);
      expect(c.voice, isNotEmpty);
    }
  });

  test('просьба при молчании — без упрёков и коротко', () {
    expect(silenceInstruction, contains('Не упрекай'));
    expect(silenceInstruction, contains('одной-двумя фразами'));
  });

  group('characters.json', () {
    test('три персонажа, у всех дом, факты и несколько историй', () {
      expect(characters.map((c) => c.id), ['bear', 'wolf', 'bunny']);
      for (final c in characters) {
        expect(c.home, isNotEmpty, reason: c.id);
        expect(c.facts.length, greaterThanOrEqualTo(6), reason: c.id);
        expect(c.hooks.length, greaterThanOrEqualTo(3), reason: c.id);
      }
    });

    test('факты, истории и дома проходят фильтр безопасности', () {
      for (final c in characters) {
        for (final t in [...c.facts, ...c.hooks, c.home, c.family, c.day]) {
          expect(SafetyFilter.check(t).ok, isTrue, reason: '${c.id}: $t');
        }
      }
    });

    test('история на разговор — одна из списка', () {
      for (var i = 0; i < 20; i++) {
        expect(bear.hooks, contains(bear.randomHook()));
      }
    });
  });

  test('свой дом вместо «живу в телефоне»', () {
    final p = buildInstructions(bear, const ChildProfile());
    expect(p, isNot(contains('живу в телефоне')));
    expect(p, contains('## Твой мир'));
    expect(p, contains(bear.home));
    expect(p, contains(bear.facts.first));
    expect(p, contains('через телефон'));
  });

  test('друзья: Зайка знает Мишку и Волчонка, но не себя', () {
    final p = buildInstructions(bunny, const ChildProfile());
    final friends =
        p.substring(p.indexOf('## Твои друзья'), p.indexOf('## Как говорить'));
    expect(friends, contains('Мишка Топтыжка'));
    expect(friends, contains('Волчонок Вова'));
    expect(friends, isNot(contains('- Зайка Зоя')));
  });

  test('история на сегодня — та, что выбрана на разговор', () {
    final hook = bear.hooks.last;
    expect(buildInstructions(bear, const ChildProfile(), hook: hook),
        contains('Твоя история на сегодня: $hook.'));
  });

  test('игра «Угадай, кто я» описана в промпте и кнопке', () {
    final p = buildInstructions(bear, const ChildProfile());
    expect(p, contains('«Угадай, кто я»'));
    expect(guessGameInstruction, contains('Угадай, кто я'));
  });

  test('промпт не разросся', () {
    for (final c in characters) {
      final p = buildInstructions(c, const ChildProfile(notes: 'Кот Барсик.'));
      expect(p.length, lessThan(9000), reason: c.id);
    }
  });
}
