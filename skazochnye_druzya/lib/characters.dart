import 'package:flutter/material.dart';

/// Форма персонажа для рисования (пока без Rive).
enum CharacterKind { bear, wolf, bunny }

/// Оригинальные персонажи. Стихи и образы Агнии Барто охраняются
/// авторским правом до 31.12.2051, поэтому здесь свои истории.
class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.kind,
    required this.color,
    required this.voice,
    required this.persona,
    required this.hook,
  });

  final String id;
  final String name;
  final CharacterKind kind;
  final Color color;

  /// Голос Yandex SpeechKit. Проверьте доступные имена в плейграунде
  /// AI Studio и замените при необходимости.
  final String voice;

  /// Характер и манера речи.
  final String persona;

  /// Маленькая проблема, с которой персонаж начинает разговор.
  final String hook;
}

const characters = <CharacterProfile>[
  CharacterProfile(
    id: 'bear',
    name: 'Мишка Топтыжка',
    kind: CharacterKind.bear,
    color: Color(0xFFB07A4F),
    voice: 'ermil',
    persona: 'Добродушный, немного неуклюжий медвежонок. Говорит медленно, '
        'басом, любит мёд и малину. Иногда смешно ворчит, но быстро радуется.',
    hook: 'в лесу с ёлки на тебя всё время падают шишки, и ты не знаешь, '
        'что с ними делать — может, ребёнок подскажет',
  ),
  CharacterProfile(
    id: 'wolf',
    name: 'Волчонок Вова',
    kind: CharacterKind.wolf,
    color: Color(0xFF8A94A6),
    voice: 'filipp',
    persona: 'Совсем не страшный, весёлый волчонок. Любит выть на луну '
        '«у-у-у», но только потому, что ему скучно одному. Мечтает о друзьях.',
    hook: 'тебе скучно, ты воешь на луну «у-у-у» и ищешь друга, '
        'с которым можно поиграть',
  ),
  CharacterProfile(
    id: 'bunny',
    name: 'Зайка Зоя',
    kind: CharacterKind.bunny,
    color: Color(0xFFE6E0D8),
    voice: 'jane',
    persona: 'Ласковая, чуть-чуть плаксивая зайка. Иногда хнычет, но быстро '
        'утешается, когда ей помогают. Любит морковку и прыгать.',
    hook: 'ты потеряла в траве свою оранжевую морковку и немножко хнычешь — '
        'может, ребёнок поможет её найти',
  ),
];
