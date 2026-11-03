import 'package:flutter/foundation.dart';

/// Технический журнал для взрослого: события сервера и ошибки.
/// Только в памяти, последние строки; на диск не пишется.
/// Нужен, чтобы видеть `[RT] …` на телефоне без компьютера.
class DebugLog {
  DebugLog._();

  static const _max = 200;
  static final lines = <String>[];

  static void add(String line) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    lines.add('${two(t.minute)}:${two(t.second)} $line');
    if (lines.length > _max) lines.removeRange(0, lines.length - _max);
    if (kDebugMode) debugPrint(line);
  }

  static void clear() => lines.clear();
}
