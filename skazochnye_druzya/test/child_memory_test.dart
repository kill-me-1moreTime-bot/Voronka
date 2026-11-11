import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skazochnye_druzya/characters.dart';
import 'package:skazochnye_druzya/child_memory.dart';
import 'package:skazochnye_druzya/child_profile.dart';
import 'package:skazochnye_druzya/prompts.dart';
import 'package:skazochnye_druzya/ui/parent_settings_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadCharacters();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ChildMemory.load();
  });

  group('что запоминается', () {
    for (final ok in [
      'любит динозавров, любимый — трицератопс',
      'кота зовут Барсик',
      'лучшего друга зовут Миша',
      'научилась прыгать на одной ножке',
      'любит синий цвет и классную музыку',
      'раньше любил машинки, теперь поезда',
      'дружит с Зайкой и любит прыгать',
    ]) {
      test(ok, () => expect(ChildMemory.reject(ok), isNull));
    }
  });

  group('что не запоминается никогда', () {
    for (final no in [
      'живёт на улице Ленина',
      'ходит в садик Ромашка',
      'телефон мамы восемь девятьсот',
      'дом номер 5',
      'фамилия Иванов',
      'у него аллергия на орехи',
      'мама с папой ссорятся',
      'папа ругает за игрушки',
      'боится темноты',
      'а' * 200,
      '',
    ]) {
      test(no.length > 40 ? 'слишком длинно' : (no.isEmpty ? 'пусто' : no),
          () => expect(ChildMemory.reject(no), isNotNull));
    }
  });

  test('сохраняется, без повторов, не больше 30, переживает перезапуск',
      () async {
    expect(ChildMemory.remember('кота зовут Барсик'), isNull);
    expect(ChildMemory.remember('Кота зовут Барсик'), isNull);
    expect(ChildMemory.facts, ['Кота зовут Барсик']);
    for (var i = 0; i < 40; i++) {
      ChildMemory.remember(
          'любит игрушку ${'а' * (i % 5 + 1)}${'б' * (i ~/ 5 + 1)}');
    }
    expect(ChildMemory.facts.length, ChildMemory.maxFacts);
    await Future<void>.delayed(Duration.zero);
    final saved = List.of(ChildMemory.facts);
    ChildMemory.facts = [];
    await ChildMemory.load();
    expect(ChildMemory.facts, saved);
  });

  test('модель не приняла функцию — память неактивна, пока не включат снова',
      () async {
    await ChildMemory.setToolsBroken(true);
    expect(ChildMemory.active, isFalse);
    await ChildMemory.load();
    expect(ChildMemory.active, isFalse);
    await ChildMemory.setToolsBroken(false);
    expect(ChildMemory.active, isTrue);
  });

  test('память и правила запоминания попадают в промпт', () {
    final bear = characters.first;
    final p = buildInstructions(bear, const ChildProfile(),
        memory: const ['кота зовут Барсик'], canRemember: true);
    expect(p, contains('## Что ты помнишь о малыше'));
    expect(p, contains('- кота зовут Барсик'));
    expect(p, contains('функцию remember'));
    final off = buildInstructions(bear, const ChildProfile());
    expect(off, isNot(contains('Что ты помнишь')));
    expect(off, isNot(contains('remember')));
  });

  testWidgets('в настройках видно запомненное, можно забыть', (t) async {
    t.view.physicalSize = const Size(800, 6000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    ChildMemory.remember('кота зовут Барсик');
    await t.pumpWidget(const MaterialApp(
      home: ParentSettingsScreen(initial: ChildProfile()),
    ));
    await t.pumpAndSettle();
    expect(find.text('кота зовут Барсик'), findsOneWidget);
    await t.tap(find.byTooltip('Забыть'));
    await t.pumpAndSettle();
    expect(find.text('кота зовут Барсик'), findsNothing);
    expect(ChildMemory.facts, isEmpty);
  });
}
