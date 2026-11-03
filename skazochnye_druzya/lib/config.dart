import 'package:shared_preferences/shared_preferences.dart';

/// Настройки подключения.
///
/// Есть два способа их задать:
/// 1. В настройках для родителей на телефоне. Хранятся только на этом
///    телефоне. Так работает APK, собранный на GitHub: в нём ключа нет.
/// 2. В config.json при сборке (`--dart-define-from-file=config.json`).
///
/// Значение с телефона важнее значения из сборки. Ключи в код не писать.
class AppConfig {
  AppConfig._();

  // Значения из config.json при сборке (пусто, если файла не было).
  static const _builtUrl = String.fromEnvironment('REALTIME_URL');
  static const _builtKey = String.fromEnvironment('YANDEX_API_KEY');
  static const _builtScheme =
      String.fromEnvironment('AUTH_SCHEME', defaultValue: 'Api-Key');
  static const _builtFolder = String.fromEnvironment('FOLDER_ID');

  static const schemes = ['Api-Key', 'Bearer'];

  static const _kUrl = 'rt_url';
  static const _kKey = 'rt_key';
  static const _kScheme = 'rt_scheme';
  static const _kFolder = 'rt_folder';

  /// Модель по умолчанию. Из списка моделей Realtime API в документации
  /// AI Studio выбрана та, что работает с голосами `general`
  /// (ermil, filipp, jane). Старая speech-realtime-250923 из примера
  /// на GitHub отвечает model_access_denied.
  static const defaultModel = 'speech-realtime-deepseek-v4-flash';

  /// Адрес, введённый вручную (или из config.json). Пусто — собрать сам.
  static String _url = _builtUrl;

  /// Адрес WebSocket Realtime API. Если не задан вручную, собирается из
  /// идентификатора каталога: модель живёт в каталоге пользователя.
  static String get realtimeUrl {
    if (_url.isNotEmpty) return _url;
    if (folderId.isEmpty) return '';
    return defaultUrlFor(folderId);
  }

  static String defaultUrlFor(String folder) =>
      'wss://ai.api.cloud.yandex.net/v1/realtime'
      '?model=gpt://$folder/$defaultModel';

  /// API-ключ сервисного аккаунта Yandex Cloud.
  static String apiKey = _builtKey;

  /// Схема авторизации: у Yandex Cloud это "Api-Key", у OpenAI-совместимых
  /// клиентов иногда "Bearer". Берите ту, что в примере на странице агента.
  static String authScheme = _builtScheme;

  /// Идентификатор каталога Yandex Cloud (b1g…).
  static String folderId = _builtFolder;

  /// Частота дискретизации PCM16 для микрофона и ответа.
  /// 44100 — как в официальном примере Yandex.
  static const sampleRate =
      int.fromEnvironment('SAMPLE_RATE', defaultValue: 44100);

  static bool get isConfigured =>
      realtimeUrl.startsWith('wss://') && apiKey.isNotEmpty;

  /// Каталог передаётся в адресе (model=gpt://каталог/…), заголовок
  /// x-folder-id в примере Yandex не нужен.
  static Map<String, String> get headers => {
        'Authorization': '$authScheme $apiKey',
      };

  /// Читает настройки с телефона. Вызывается один раз при запуске.
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _url = _pick(p.getString(_kUrl), _builtUrl);
    apiKey = _pick(p.getString(_kKey), _builtKey);
    authScheme = _pick(p.getString(_kScheme), _builtScheme);
    folderId = _pick(p.getString(_kFolder), _builtFolder);
  }

  /// Сохраняет настройки на телефоне. Пустое поле — взять значение из сборки.
  static Future<void> save({
    required String url,
    required String key,
    required String scheme,
    required String folder,
  }) async {
    final p = await SharedPreferences.getInstance();
    Future<void> put(String k, String v) =>
        v.isEmpty ? p.remove(k) : p.setString(k, v);
    final fixed = fixFields(url: url, folder: folder);
    await put(_kUrl, fixed.url);
    await put(_kKey, key.trim());
    await put(_kScheme, scheme);
    await put(_kFolder, fixed.folder);
    await load();
  }

  /// Исправляет вставку не в то поле: адрес в поле каталога — переносит
  /// в адрес, а каталог достаёт из `gpt://каталог/…` или `folders/каталог`.
  static ({String url, String folder}) fixFields({
    required String url,
    required String folder,
  }) {
    var u = url.trim();
    var f = folder.trim();
    if (f.startsWith('wss://')) {
      if (u.isEmpty) u = f;
      f = folderFrom(f) ?? '';
    } else if (f.contains('/')) {
      f = folderFrom(f) ?? f;
    }
    if (f.isEmpty && u.isNotEmpty) f = folderFrom(u) ?? '';
    return (url: u, folder: f);
  }

  /// Каталог из ссылки: `gpt://b1g…/модель` или `…/folders/b1g…/…`.
  static String? folderFrom(String s) =>
      RegExp(r'(?:gpt://|folders/)([a-z0-9]+)').firstMatch(s)?.group(1);

  /// Что сейчас сохранено на телефоне (без значений из сборки) — для формы.
  static Future<Map<String, String>> stored() async {
    final p = await SharedPreferences.getInstance();
    return {
      'url': p.getString(_kUrl) ?? '',
      'key': p.getString(_kKey) ?? '',
      'scheme': p.getString(_kScheme) ?? authScheme,
      'folder': p.getString(_kFolder) ?? '',
    };
  }

  static String _pick(String? phone, String built) =>
      (phone != null && phone.isNotEmpty) ? phone : built;
}
