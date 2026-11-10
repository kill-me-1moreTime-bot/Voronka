import 'package:shared_preferences/shared_preferences.dart';

import 'characters.dart';

/// Модель Realtime API. Голоса у моделей разные и между собой
/// несовместимы, поэтому у каждого персонажа два голоса.
enum VoiceModel {
  /// Живые голоса LiveTTS (sofia, vera, vasily, sergey, denis, irina).
  live('speech-realtime-max-tts-live/latest', 'Живые голоса'),

  /// Экспериментальная, голоса general (ermil, filipp, jane).
  deepseek('speech-realtime-deepseek-v4-flash', 'Прежняя');

  const VoiceModel(this.path, this.label);
  final String path;
  final String label;
}

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
  static const _kModel = 'rt_model';

  /// Модель из списка Realtime API в документации AI Studio. Старая
  /// speech-realtime-250923 из примера на GitHub отвечает model_access_denied.
  static VoiceModel model = VoiceModel.live;

  /// Голос персонажа для выбранной модели.
  static String voiceFor(CharacterProfile c) =>
      model == VoiceModel.live ? c.liveVoice : c.voice;

  /// Адрес, введённый вручную (или из config.json). Пусто — собрать сам.
  static String _url = _builtUrl;

  /// Адрес WebSocket Realtime API. Если не задан вручную, собирается из
  /// идентификатора каталога: модель живёт в каталоге пользователя.
  static String get realtimeUrl {
    if (_url.isNotEmpty) return _url;
    if (folderId.isEmpty) return '';
    return defaultUrlFor(folderId);
  }

  static String defaultUrlFor(String folder, [VoiceModel? m]) =>
      'wss://ai.api.cloud.yandex.net/v1/realtime'
      '?model=gpt://$folder/${(m ?? model).path}';

  /// Адрес, собранный по нашему же шаблону (вставлен вручную раньше,
  /// когда модель нельзя было выбрать). Такой адрес не держим: иначе
  /// он перебивает выбор модели.
  static bool isTemplateUrl(String u) => RegExp(
        r'^wss://ai\.api\.cloud\.yandex\.net/v1/realtime\?model=gpt://'
        r'[A-Za-z0-9]+/speech-realtime-[a-z0-9./-]+$',
      ).hasMatch(u.trim());

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
    final stored = p.getString(_kUrl);
    if (stored != null && isTemplateUrl(stored)) await p.remove(_kUrl);
    _url = _pick(p.getString(_kUrl), _builtUrl);
    model = VoiceModel.values.firstWhere(
      (m) => m.name == p.getString(_kModel),
      orElse: () => VoiceModel.live,
    );
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
    VoiceModel? voiceModel,
  }) async {
    final p = await SharedPreferences.getInstance();
    Future<void> put(String k, String v) =>
        v.isEmpty ? p.remove(k) : p.setString(k, v);
    final fixed = fixFields(url: url, folder: folder);
    await put(_kUrl, isTemplateUrl(fixed.url) ? '' : fixed.url);
    if (voiceModel != null) await p.setString(_kModel, voiceModel.name);
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
