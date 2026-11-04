import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/debug_log.dart';

void main() {
  test('время в журнале московское, с часами', () {
    final t = DateTime.utc(2026, 11, 4, 7, 53, 9);
    expect(DebugLog.clock(t), '10:53:09');
    expect(DebugLog.date(t), '04.11.2026');
  });

  test('после полуночи по Москве — уже следующий день', () {
    final t = DateTime.utc(2026, 11, 3, 22, 5, 0);
    expect(DebugLog.clock(t), '01:05:00');
    expect(DebugLog.date(t), '04.11.2026');
  });

  test('новый журнал начинается с даты', () {
    DebugLog.clear();
    DebugLog.add('[App] проверка');
    expect(DebugLog.lines.first, startsWith('Журнал от '));
    expect(DebugLog.lines.first, endsWith('время МСК'));
    expect(DebugLog.lines.last,
        matches(RegExp(r'^\d\d:\d\d:\d\d \[App\] проверка$')));
  });
}
