import 'package:shared_preferences/shared_preferences.dart';

/// Настройки родителя. Хранятся только на устройстве.
class ChildProfile {
  const ChildProfile({
    this.name = '',
    this.ageYears = 3,
    this.sessionMinutes = 10,
  });

  final String name;
  final int ageYears;
  final int sessionMinutes;

  ChildProfile copyWith({String? name, int? ageYears, int? sessionMinutes}) =>
      ChildProfile(
        name: name ?? this.name,
        ageYears: ageYears ?? this.ageYears,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      );

  static Future<ChildProfile> load() async {
    final p = await SharedPreferences.getInstance();
    return ChildProfile(
      name: p.getString('child_name') ?? '',
      ageYears: p.getInt('child_age') ?? 3,
      sessionMinutes: p.getInt('session_minutes') ?? 10,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('child_name', name);
    await p.setInt('child_age', ageYears);
    await p.setInt('session_minutes', sessionMinutes);
  }
}
