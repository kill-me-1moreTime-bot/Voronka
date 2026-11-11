import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Форма персонажа, нарисованного кодом (если нет картинок).
enum CharacterKind { bear, wolf, bunny }

/// Персонаж. Все данные — в assets/characters.json: новый персонаж
/// добавляется записью там, без правки кода.
class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.who,
    required this.kin,
    required this.kind,
    required this.color,
    required this.voice,
    required this.liveVoice,
    required this.persona,
    required this.home,
    required this.family,
    required this.day,
    required this.facts,
    required this.hooks,
  });

  final String id;
  final String name;

  /// Кто он: «медвежонок», «зайка» — для рассказов друзей о нём.
  final String who;

  /// Сородичи во множественном числе: «медведи», «зайцы».
  final String kin;
  final CharacterKind kind;
  final Color color;

  /// Голос прежней модели (general): ermil, filipp, jane…
  final String voice;

  /// Голос модели «Живые голоса» (LiveTTS): sofia, vera, irina —
  /// женские, vasily, sergey, denis — мужские.
  final String liveVoice;

  /// Характер и манера речи.
  final String persona;

  /// Где живёт, кто рядом, чем обычно занят.
  final String home;
  final String family;
  final String day;

  /// Добрые факты о своём звере — рассказывает «про себя».
  final List<String> facts;

  /// Маленькие истории-завязки. На каждый разговор выбирается одна.
  final List<String> hooks;

  /// Первое предложение характера — для рассказа о нём другим.
  String get short {
    final i = persona.indexOf('.');
    return i < 0 ? persona : persona.substring(0, i + 1);
  }

  String randomHook([math.Random? rnd]) =>
      hooks[(rnd ?? math.Random()).nextInt(hooks.length)];

  factory CharacterProfile.fromJson(Map<String, dynamic> j) {
    List<String> list(String k) =>
        (j[k] as List).map((e) => e as String).toList();
    final hex = (j['color'] as String).replaceFirst('#', '');
    final hooks = list('hooks');
    if (hooks.isEmpty) throw FormatException('у ${j['id']} нет hooks');
    return CharacterProfile(
      id: j['id'] as String,
      name: j['name'] as String,
      who: j['who'] as String,
      kin: j['kin'] as String,
      kind: CharacterKind.values.byName(j['kind'] as String),
      color: Color(int.parse('FF$hex', radix: 16)),
      voice: j['voice'] as String,
      liveVoice: j['liveVoice'] as String,
      persona: j['persona'] as String,
      home: j['home'] as String,
      family: j['family'] as String,
      day: j['day'] as String,
      facts: list('facts'),
      hooks: hooks,
    );
  }
}

/// Все персонажи. Заполняется при запуске из assets/characters.json.
List<CharacterProfile> characters = const [];

List<CharacterProfile> parseCharacters(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  return (root['characters'] as List)
      .map((e) => CharacterProfile.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> loadCharacters({AssetBundle? bundle}) async {
  final text =
      await (bundle ?? rootBundle).loadString('assets/characters.json');
  characters = parseCharacters(text);
}
