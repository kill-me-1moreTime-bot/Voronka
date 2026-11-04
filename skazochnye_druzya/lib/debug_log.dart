import 'package:flutter/foundation.dart';

/// Технический журнал для взрослого: события сервера и ошибки.
/// Только в памяти, последние строки; на диск не пишется.
/// Нужен, чтобы видеть `[RT] …` на телефоне без компьютера.
class DebugLog {
  DebugLog._();

  static const _max = 200;
  static final lines = <String>[];

  /// Москва — UTC+3 круглый год, без перехода на летнее время.
  static DateTime moscow(DateTime t) => t.toUtc().add(const Duration(hours: 3));

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Время по Москве: 10:07:53.
  static String clock(DateTime t) {
    final m = moscow(t);
    return '${_two(m.hour)}:${_two(m.minute)}:${_two(m.second)}';
  }

  /// Дата по Москве: 04.11.2026.
  static String date(DateTime t) {
    final m = moscow(t);
    return '${_two(m.day)}.${_two(m.month)}.${m.year}';
  }

  static void add(String line) {
    lines.add('${clock(DateTime.now())} $line');
    if (lines.length > _max) lines.removeRange(0, lines.length - _max);
    if (kDebugMode) debugPrint(line);
  }

  /// Новый разговор — новый журнал. Первая строка — дата, чтобы в
  /// скопированном тексте было понятно, когда это было.
  static void clear() {
    lines
      ..clear()
      ..add('Журнал от ${date(DateTime.now())}, время МСК');
  }
}
