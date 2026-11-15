import 'package:shared_preferences/shared_preferences.dart';

/// Настройки родителя. Хранятся только на устройстве.
class ChildProfile {
  const ChildProfile({
    this.name = '',
    this.ageYears = 3,
    this.sessionMinutes = 10,
    this.notes = '',
    this.speechRate = 0.9,
    this.keepScreenOn = true,
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
  }) =>
      ChildProfile(
        name: name ?? this.name,
        ageYears: ageYears ?? this.ageYears,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        notes: notes ?? this.notes,
        speechRate: speechRate ?? this.speechRate,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
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
  }
}
