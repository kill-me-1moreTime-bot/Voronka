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

  test('адрес собирается из каталога, если не задан вручную', () async {
    await AppConfig.save(url: '', key: 'k', scheme: 'Api-Key', folder: 'b1gX');
    expect(
      AppConfig.realtimeUrl,
      'wss://ai.api.cloud.yandex.net/v1/realtime'
      '?model=gpt://b1gX/speech-realtime-deepseek-v4-flash',
    );
    expect(AppConfig.isConfigured, isTrue);
    expect(AppConfig.headers, {'Authorization': 'Api-Key k'});
  });

  test('адрес, вставленный в поле каталога, переносится в адрес', () {
    const link = 'wss://ai.api.cloud.yandex.net/v1/realtime'
        '?model=gpt://b1gabc123/speech-realtime-deepseek-v4-flash';
    final r = AppConfig.fixFields(url: '', folder: ' $link ');
    expect(r.url, link);
    expect(r.folder, 'b1gabc123');
  });

  test('каталог достаётся из адреса страницы AI Studio', () {
    final r = AppConfig.fixFields(
      url: '',
      folder: 'https://aistudio.yandex.ru/platform/folders/b1gxyz/agents',
    );
    expect(r.folder, 'b1gxyz');
    expect(r.url, '');
  });

  test('обычный каталог не меняется', () {
    final r = AppConfig.fixFields(url: '', folder: ' b1gjc7 ');
    expect(r, (url: '', folder: 'b1gjc7'));
  });

  testWidgets('форма родителя сохраняет адрес и ключ', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParentSettingsScreen(initial: ChildProfile()),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Идентификатор каталога'), 'b1gTEST');
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
    expect(AppConfig.realtimeUrl, contains('gpt://b1gTEST/'));
    expect(AppConfig.apiKey, 'secret');
  });

  testWidgets('адрес не с wss:// не сохраняется', (tester) async {
    await AppConfig.load();
    await tester.pumpWidget(const MaterialApp(
      home: ParentSettingsScreen(initial: ChildProfile()),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Дополнительно'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дополнительно'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Адрес (wss://…), необязательно'),
        'https://x.test');
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
