// Скобки в ${_l} оставлены нарочно: так видно, где кончается переменная.
// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:math' as math;

import 'characters.dart';

/// Что показать на экране, пока персонаж говорит.
///
/// Сцена выбирается по тексту ответа, а не вызовом функции модели:
/// текст уже прошёл фильтр безопасности, а сцена гарантированно
/// совпадает с тем, что малыш слышит.
sealed class Scene {
  const Scene();
}

/// Счёт: [n] предметов [thing] появляются по одному.
class CountScene extends Scene {
  const CountScene(this.thing, this.n);
  final String thing;
  final int n;
}

/// Прятки: персонаж сидит за одним из трёх кустов ([place] 0..2).
class HideScene extends Scene {
  const HideScene(this.place);
  final int place;
}

/// «Угадай, кто я»: пока [animal] нет — знак вопроса, потом зверь.
class GuessScene extends Scene {
  const GuessScene([this.animal]);
  final String? animal;
}

/// Картина дома персонажа, рисуется по шагам.
class HomeScene extends Scene {
  const HomeScene();
}

class SceneDetector {
  SceneDetector._();

  static String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  // В Dart `\b` не работает для кириллицы — границы слов задаём сами.
  static const _l = r'(?<![а-я])';
  static const _r = r'(?![а-я])';

  /// Что умеем считать: основа слова → картинка.
  static final things = <RegExp, String>{
    RegExp('шишк|шишеч'): 'cone',
    RegExp('малин'): 'raspberry',
    RegExp('морков'): '🥕',
    RegExp('цветоч|цветк|${_l}цветы'): '🌼',
    RegExp('звезд'): '⭐',
    RegExp('желуд|орех|ореш'): '🌰',
    RegExp('листоч|листик|листь'): '🍂',
    RegExp('яблок|яблоч'): '🍎',
    RegExp('${_l}мяч'): '⚽',
    RegExp('ягод'): '🍓',
    RegExp('гриб'): '🍄',
    RegExp('палоч|веточ'): '🪵',
    RegExp('бабоч'): '🦋',
    RegExp('рыбк|рыбок'): '🐟',
    RegExp('конфет'): '🍬',
  };

  static final _numerals = <RegExp, int>{
    RegExp('$_l(один|одна|одну|одно|раз)$_r'): 1,
    RegExp('$_l(два|две|двух)$_r'): 2,
    RegExp('$_l(три|трех)$_r'): 3,
    RegExp('$_l(четыре|четырех)$_r'): 4,
    RegExp('$_l(пять|пяти)$_r'): 5,
    RegExp('$_l(шесть|шести)$_r'): 6,
    RegExp('$_l(семь|семи)$_r'): 7,
    RegExp('$_l(восемь|восьми)$_r'): 8,
    RegExp('$_l(девять|девяти)$_r'): 9,
    RegExp('$_l(десять|десяти)$_r'): 10,
  };

  /// Звери из игры «Угадай, кто я».
  static final animals = <RegExp, String>{
    RegExp('коров'): '🐄',
    RegExp('кошк|кошеч|котик|котен'): '🐈',
    RegExp('собак|собач|песик|щенок|щенк'): '🐕',
    RegExp('петух|петуш'): '🐓',
    RegExp('куроч|куриц'): '🐔',
    RegExp('${_l}утк|уточк|утенок|утенк'): '🦆',
    RegExp('лошад|конь$_r|коник'): '🐎',
    RegExp('овеч|${_l}овц|барашек|барашк'): '🐑',
    RegExp('свин|поросен|хрюш'): '🐖',
    RegExp('лягуш'): '🐸',
    RegExp('${_l}еж|ежик'): '🦔',
    RegExp('белк|белоч'): '🐿️',
    RegExp('${_l}лис'): '🦊',
    RegExp('${_l}сов(а|у|ы|ушк|енок)'): '🦉',
    RegExp('${_l}мыш'): '🐁',
    RegExp('рыбк|${_l}рыб'): '🐟',
    RegExp('медвед|${_l}мишк'): '🐻',
    RegExp('${_l}зайк|${_l}заяц|зайчик|зайч'): '🐰',
    RegExp('${_l}волк|волчон'): '🐺',
  };

  static final _hide = RegExp(
      'спрятал|спрячусь|прячусь|найди меня|ищи меня|поищи меня|где же я');
  static final _found = RegExp(
      'нашел|нашла|нашли|вот я|вот он я|вылез|выхожу|вышел|вышла|выглянул');
  static final _guess = RegExp('угадай');
  static final _count = RegExp('посчита|считаем|считай|сосчита|сколько');
  static final _home = RegExp(
      '$_l(живу|живем)$_r|мой дом|моя берлог|моя норк|моя будк|мой домик');

  /// Все числительные в тексте.
  static List<int> numerals(String text) {
    final t = _norm(text);
    return [
      for (final e in _numerals.entries)
        if (e.key.hasMatch(t)) e.value,
    ];
  }

  static String? _first(Map<RegExp, String> map, String t) {
    for (final e in map.entries) {
      if (e.key.hasMatch(t)) return e.value;
    }
    return null;
  }

  /// Сцена для нового ответа персонажа. [current] — что сейчас на экране:
  /// прятки и неотгаданная загадка остаются, пока не закончатся.
  static Scene? detect(String text, {Scene? current, math.Random? rnd}) {
    final t = _norm(text);

    // Прятки закончились: нашли.
    if (current is HideScene && _found.hasMatch(t)) current = null;

    // Новая загадка.
    if (_guess.hasMatch(t) && t.contains('кто')) return const GuessScene();

    // Отгадка: персонаж назвал зверя.
    if (current is GuessScene && current.animal == null) {
      final a = _first(animals, t);
      return a == null ? current : GuessScene(a);
    }

    if (_hide.hasMatch(t)) {
      return current is HideScene
          ? current
          : HideScene((rnd ?? math.Random()).nextInt(3));
    }
    if (current is HideScene) return current;

    // Счёт: названо, что считаем, и видно, что именно считаем.
    final nums = numerals(t);
    final thing = _first(things, t);
    if (thing != null && (_count.hasMatch(t) || nums.length >= 2)) {
      return CountScene(thing, _n(nums));
    }
    // Продолжение счёта без названия предмета: «Раз, два, три!»
    if (current is CountScene && nums.length >= 2) {
      return CountScene(current.thing, _n(nums));
    }

    if (_home.hasMatch(t)) return const HomeScene();
    return null;
  }

  /// Сколько показать: самое большое названное число, без чисел — пять.
  static int _n(List<int> nums) =>
      nums.isEmpty ? 5 : nums.reduce(math.max).clamp(1, 10);

  /// Корни имени для поиска в речи: «Зайка Зоя» → зай, зоя.
  static List<String> nameStems(CharacterProfile c) => [
        for (final w in _norm(c.name).split(' '))
          w.substring(0, math.max(3, w.length - 2).clamp(0, w.length)),
      ];

  /// Персонаж предложил позвонить другу: «Давай позвоним Зайке!»
  static CharacterProfile? detectCall(
    String text,
    Iterable<CharacterProfile> friends,
  ) {
    final t = _norm(text);
    // Только приглашение («позвоним», «позвоню»), а не рассказ о прошлом
    // звонке («как хорошо, что мы позвонили»).
    if (!RegExp('позвон(им|ю)$_r').hasMatch(t)) return null;
    for (final f in friends) {
      if (nameStems(f).any(t.contains)) return f;
    }
    return null;
  }

  /// Друг попрощался сам — звонок пора заканчивать.
  static bool saysBye(String text) =>
      RegExp('$_l(пока|до свидания|до встречи|до скорого)$_r')
          .hasMatch(_norm(text));
}
