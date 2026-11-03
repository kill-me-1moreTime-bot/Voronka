// Запуск из корня проекта: dart tool/patch_android.dart
// Добавляет разрешения на интернет и микрофон и поднимает minSdk до 23.
// Запускать один раз после `flutter create --platforms android .`
import 'dart:io';

void main() {
  _patchManifest();
  _patchGradle();
  stdout.writeln('Готово. Теперь: flutter pub get');
}

void _patchManifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln('Нет ${f.path}. Сначала выполните: '
        'flutter create --platforms android .');
    exit(1);
  }
  var s = f.readAsStringSync();
  const perms = [
    'android.permission.INTERNET',
    'android.permission.RECORD_AUDIO',
    'android.permission.MODIFY_AUDIO_SETTINGS',
  ];
  final missing = perms.where((p) => !s.contains(p)).toList();
  if (missing.isEmpty) {
    stdout.writeln('Манифест: разрешения уже есть.');
    return;
  }
  final lines =
      missing.map((p) => '    <uses-permission android:name="$p"/>').join('\n');
  // Вставляем сразу после открывающего тега <manifest ...>.
  final idx = s.indexOf('>', s.indexOf('<manifest')) + 1;
  s = '${s.substring(0, idx)}\n$lines${s.substring(idx)}';
  f.writeAsStringSync(s);
  stdout.writeln('Манифест: добавлены ${missing.join(', ')}');
}

void _patchGradle() {
  for (final path in [
    'android/app/build.gradle.kts',
    'android/app/build.gradle',
  ]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final s = f.readAsStringSync();
    final re = RegExp(r'minSdk(Version)?\s*=?\s*flutter\.minSdkVersion');
    if (re.hasMatch(s)) {
      final kts = path.endsWith('.kts');
      // Не ниже 23 (нужно микрофону), но и не ниже значения Flutter по умолчанию.
      f.writeAsStringSync(s.replaceFirst(
          re,
          kts
              ? 'minSdk = maxOf(23, flutter.minSdkVersion)'
              : 'minSdkVersion Math.max(23, flutter.minSdkVersion)'));
      stdout.writeln('$path: minSdk не ниже 23');
    } else {
      stdout.writeln('$path: minSdk не тронут — проверьте, что он не ниже 23.');
    }
    return;
  }
  stderr.writeln('Не найден android/app/build.gradle(.kts).');
}
