import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/characters.dart';
import 'package:skazochnye_druzya/child_profile.dart';
import 'package:skazochnye_druzya/prompts.dart';

void main() {
  final bear = characters.first;

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
      'живу в телефоне',
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
}
