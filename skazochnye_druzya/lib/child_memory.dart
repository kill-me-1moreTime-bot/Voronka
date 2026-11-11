import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'safety/safety_filter.dart';

/// Что персонаж запомнил о ребёнке. Хранится только на телефоне
/// (shared_preferences, резервная копия Google выключена). В разговор
/// уходит внутри промпта — как и «О ребёнке».
class ChildMemory {
  ChildMemory._();

  static const maxFacts = 30;
  static const maxLength = 120;

  static const _kFacts = 'child_memory';
  static const _kEnabled = 'child_memory_on';
  static const _kToolsBroken = 'child_memory_tools_broken';

  /// Записи, старые сначала.
  static List<String> facts = [];

  /// Родитель может выключить память в настройках.
  static bool enabled = true;

  /// Модель не приняла функцию «запомнить» — больше не предлагаем её,
  /// чтобы разговор не обрывался. Сбрасывается сменой модели.
  static bool toolsBroken = false;

  static bool get active => enabled && !toolsBroken;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kFacts);
    facts = raw == null
        ? []
        : (jsonDecode(raw) as List).map((e) => e as String).toList();
    enabled = p.getBool(_kEnabled) ?? true;
    toolsBroken = p.getBool(_kToolsBroken) ?? false;
  }

  static Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFacts, jsonEncode(facts));
  }

  static Future<void> setEnabled(bool on) async {
    enabled = on;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, on);
  }

  static Future<void> setToolsBroken(bool broken) async {
    toolsBroken = broken;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kToolsBroken, broken);
  }

  /// Личное и тяжёлое не запоминаем никогда, даже если модель попросит.
  static final _private = RegExp(
    r'адрес|улиц|проспект|переул|квартир|подъезд|этаж|телефон|номер|'
    r'фамили|паспорт|садик|детск\S* сад|школ|'
    r'боле|болит|больниц|врач|доктор|аллерги|лекарств|таблет|'
    r'ссор|(?<![а-я])руга|наказ|бьют|(?<![а-я])бил[аи]?(?![а-я])|развод|плак|страшн|боит|'
    r'пароль|карт[аоуы]? (банк|сбер)',
    unicode: true,
  );

  /// Почему запись не годится; null — годится.
  static String? reject(String fact) {
    final f = fact.trim();
    if (f.isEmpty) return 'пусто';
    if (f.length > maxLength) return 'слишком длинно';
    // Цифры — это чаще всего номер дома, телефон, садика.
    if (RegExp(r'\d').hasMatch(f)) return 'цифры';
    final low = f.toLowerCase().replaceAll('ё', 'е');
    if (_private.hasMatch(low)) return 'личное';
    if (!SafetyFilter.check(f).ok) return 'фильтр безопасности';
    return null;
  }

  /// Сохраняет запись. Возвращает причину отказа или null, если сохранено.
  /// Список меняется сразу (синхронно), на диск пишется в фоне: ответ
  /// модели нельзя задерживать, иначе он разойдётся с концом её ответа.
  static String? remember(String fact) {
    final why = reject(fact);
    if (why != null) return why;
    final f = fact.trim();
    final key = f.toLowerCase();
    facts.removeWhere((e) => e.toLowerCase() == key);
    facts.add(f);
    if (facts.length > maxFacts) {
      facts.removeRange(0, facts.length - maxFacts);
    }
    _save();
    return null;
  }

  static Future<void> forget(String fact) async {
    facts.remove(fact);
    await _save();
  }

  static Future<void> forgetAll() async {
    facts.clear();
    await _save();
  }

  /// Описание функции для Realtime API.
  static const tool = {
    'type': 'function',
    'name': 'remember',
    'description': 'Запомнить что-то хорошее о малыше, чтобы вспомнить в '
        'следующих разговорах: любимое, имена питомцев и друзей, увлечения, '
        'чему научился. Никогда — адрес, садик, фамилию, телефон, здоровье, '
        'ссоры.',
    'parameters': {
      'type': 'object',
      'properties': {
        'fact': {
          'type': 'string',
          'description': 'Одна короткая фраза о малыше, например '
              '«любит динозавров, любимый — трицератопс».',
        },
      },
      'required': ['fact'],
      'additionalProperties': false,
    },
  };
}
