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

  test('экран не гаснет по умолчанию, выключатель сохраняется', () async {
    expect((await ChildProfile.load()).keepScreenOn, isTrue);
    await const ChildProfile(keepScreenOn: false).save();
    expect((await ChildProfile.load()).keepScreenOn, isFalse);
  });

  test('пол: по умолчанию не указан, выбор сохраняется', () async {
    expect((await ChildProfile.load()).gender, ChildGender.unknown);
    await const ChildProfile(gender: ChildGender.girl).save();
    expect((await ChildProfile.load()).gender, ChildGender.girl);
  });
}
