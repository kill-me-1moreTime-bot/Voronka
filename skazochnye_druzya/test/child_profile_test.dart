import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skazochnye_druzya/child_profile.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('по умолчанию речь чуть медленнее', () async {
    expect((await ChildProfile.load()).speechRate, 0.9);
  });

  test('скорость и заметки сохраняются', () async {
    await const ChildProfile(notes: 'Кот Барсик', speechRate: 0.8).save();
    final p = await ChildProfile.load();
    expect(p.speechRate, 0.8);
    expect(p.notes, 'Кот Барсик');
  });

  test('все скорости из выбора — в разумных пределах', () {
    for (final r in ChildProfile.speechRates.keys) {
      expect(r, inInclusiveRange(0.7, 1.0));
    }
  });
}
