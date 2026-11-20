import 'package:shared_preferences/shared_preferences.dart';

/// Пол ребёнка — чтобы персонаж говорил «ты нашла» или «ты нашёл».
/// Задаёт родитель; по имени и голосу не угадываем.
enum ChildGender {
  unknown('Не указывать'),
  girl('Девочка'),
  boy('Мальчик');

  const ChildGender(this.label);
  final String label;

  /// Форма слова для этого ребёнка: [boy] — мужской род, [girl] —
  /// женский, [neutral] — когда пол не указан.
  String pick(String boy, String girl, String neutral) => switch (this) {
        ChildGender.boy => boy,
        ChildGender.girl => girl,
        ChildGender.unknown => neutral,
      };
}

/// Настройки родителя. Хранятся только на устройстве.
class ChildProfile {
  const ChildProfile({
    this.name = '',
    this.ageYears = 3,
    this.sessionMinutes = 10,
    this.notes = '',
    this.speechRate = 0.9,
    this.keepScreenOn = true,
    this.gender = ChildGender.unknown,
  });

  final String name;
  final int ageYears;
  final int sessionMinutes;

  /// Что персонажу знать о ребёнке: увлечения, питомцы, друзья, садик.
  /// Уходит в промпт, хранится только на телефоне.
  final String notes;

  /// Скорость, с которой приложение проигрывает речь персонажа.
  /// Живые голоса Yandex к концу фразы ускоряются, а задать скорость
  /// в Realtime API нельзя, поэтому замедляем у себя.
  final double speechRate;

  final ChildGender gender;

  /// Не гасить экран, пока идёт разговор.
  final bool keepScreenOn;

  static final speechRates = <double, String>{
    1.0: 'Обычная',
    0.9: 'Медленнее',
    0.8: 'Ещё медленнее'
  };

  /// Чтобы промпт не разрастался: заметки длиннее обрезаются.
  static const maxNotes = 500;

  ChildProfile copyWith({
    String? name,
    int? ageYears,
    int? sessionMinutes,
    String? notes,
    double? speechRate,
    bool? keepScreenOn,
    ChildGender? gender,
  }) =>
      ChildProfile(
        name: name ?? this.name,
        ageYears: ageYears ?? this.ageYears,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        notes: notes ?? this.notes,
        speechRate: speechRate ?? this.speechRate,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        gender: gender ?? this.gender,
      );

  static Future<ChildProfile> load() async {
    final p = await SharedPreferences.getInstance();
    return ChildProfile(
      name: p.getString('child_name') ?? '',
      ageYears: p.getInt('child_age') ?? 3,
      sessionMinutes: p.getInt('session_minutes') ?? 10,
      notes: p.getString('child_notes') ?? '',
      speechRate: p.getDouble('speech_rate') ?? 0.9,
      keepScreenOn: p.getBool('keep_screen_on') ?? true,
      gender: ChildGender.values.firstWhere(
        (g) => g.name == p.getString('child_gender'),
        orElse: () => ChildGender.unknown,
      ),
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('child_name', name);
    await p.setInt('child_age', ageYears);
    await p.setInt('session_minutes', sessionMinutes);
    await p.setString('child_notes', notes);
    await p.setDouble('speech_rate', speechRate);
    await p.setBool('keep_screen_on', keepScreenOn);
    await p.setString('child_gender', gender.name);
  }
}
