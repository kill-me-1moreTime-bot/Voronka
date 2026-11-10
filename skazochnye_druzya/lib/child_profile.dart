import 'package:shared_preferences/shared_preferences.dart';

/// Настройки родителя. Хранятся только на устройстве.
class ChildProfile {
  const ChildProfile({
    this.name = '',
    this.ageYears = 3,
    this.sessionMinutes = 10,
    this.notes = '',
  });

  final String name;
  final int ageYears;
  final int sessionMinutes;

  /// Что персонажу знать о ребёнке: увлечения, питомцы, друзья, садик.
  /// Уходит в промпт, хранится только на телефоне.
  final String notes;

  /// Чтобы промпт не разрастался: заметки длиннее обрезаются.
  static const maxNotes = 500;

  ChildProfile copyWith({
    String? name,
    int? ageYears,
    int? sessionMinutes,
    String? notes,
  }) =>
      ChildProfile(
        name: name ?? this.name,
        ageYears: ageYears ?? this.ageYears,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        notes: notes ?? this.notes,
      );

  static Future<ChildProfile> load() async {
    final p = await SharedPreferences.getInstance();
    return ChildProfile(
      name: p.getString('child_name') ?? '',
      ageYears: p.getInt('child_age') ?? 3,
      sessionMinutes: p.getInt('session_minutes') ?? 10,
      notes: p.getString('child_notes') ?? '',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('child_name', name);
    await p.setInt('child_age', ageYears);
    await p.setInt('session_minutes', sessionMinutes);
    await p.setString('child_notes', notes);
  }
}
