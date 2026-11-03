import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skazochnye_druzya/child_profile.dart';
import 'package:skazochnye_druzya/config.dart';
import 'package:skazochnye_druzya/ui/parent_settings_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('без настроек приложение не считается подключённым', () async {
    await AppConfig.load();
    expect(AppConfig.isConfigured, isFalse);
  });

  test('настройки с телефона сохраняются и читаются', () async {
    await AppConfig.save(
      url: ' wss://example.test/realtime ',
      key: 'k123',
      scheme: 'Bearer',
      folder: '',
    );
    await AppConfig.load();
    expect(AppConfig.realtimeUrl, 'wss://example.test/realtime');
    expect(AppConfig.isConfigured, isTrue);
    expect(AppConfig.headers, {'Authorization': 'Bearer k123'});
  });

  test('пустое поле стирает значение с телефона', () async {
    await AppConfig.save(
        url: 'wss://a', key: 'k', scheme: 'Api-Key', folder: 'f');
    await AppConfig.save(url: '', key: '', scheme: 'Api-Key', folder: '');
    expect(AppConfig.isConfigured, isFalse);
    expect(AppConfig.headers.containsKey('x-folder-id'), isFalse);
  });

  testWidgets('форма родителя сохраняет адрес и ключ', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParentSettingsScreen(initial: ChildProfile()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Адрес (wss://…)'), 'wss://x.test/rt');
    await tester.enterText(
        find.widgetWithText(TextField, 'API-ключ'), 'secret');
    await tester.scrollUntilVisible(
      find.text('Сохранить'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(AppConfig.realtimeUrl, 'wss://x.test/rt');
    expect(AppConfig.apiKey, 'secret');
  });

  testWidgets('адрес не с wss:// не сохраняется', (tester) async {
    await AppConfig.load();
    await tester.pumpWidget(const MaterialApp(
      home: ParentSettingsScreen(initial: ChildProfile()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Адрес (wss://…)'), 'https://x.test');
    await tester.pump();
    expect(find.text('Адрес должен начинаться с wss://'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Сохранить'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(AppConfig.isConfigured, isFalse);
  });
}
