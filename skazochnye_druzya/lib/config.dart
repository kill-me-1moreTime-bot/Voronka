/// Настройки подключения. Значения приходят из config.json через
/// `flutter run --dart-define-from-file=config.json` и не хранятся в коде.
class AppConfig {
  /// Адрес WebSocket Realtime API. Скопируйте его из примера интеграции
  /// на странице голосового агента в Yandex AI Studio.
  static const realtimeUrl = String.fromEnvironment('REALTIME_URL');

  /// API-ключ сервисного аккаунта Yandex Cloud.
  static const apiKey = String.fromEnvironment('YANDEX_API_KEY');

  /// Схема авторизации: у Yandex Cloud это "Api-Key", у OpenAI-совместимых
  /// клиентов иногда "Bearer". Берите ту, что в примере на странице агента.
  static const authScheme =
      String.fromEnvironment('AUTH_SCHEME', defaultValue: 'Api-Key');

  /// Идентификатор каталога Yandex Cloud (если пример его требует).
  static const folderId = String.fromEnvironment('FOLDER_ID');

  /// Частота дискретизации PCM16 для микрофона и ответа.
  static const sampleRate =
      int.fromEnvironment('SAMPLE_RATE', defaultValue: 24000);

  static bool get isConfigured => realtimeUrl.isNotEmpty && apiKey.isNotEmpty;

  static Map<String, String> get headers => {
        'Authorization': '$authScheme $apiKey',
        if (folderId.isNotEmpty) 'x-folder-id': folderId,
      };
}
