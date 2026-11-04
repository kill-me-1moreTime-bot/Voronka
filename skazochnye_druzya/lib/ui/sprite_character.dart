import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Набор картинок персонажа из assets/characters/<id>/.
///
/// Все картинки — одного размера и в одной позе, отличаются только
/// ртом, глазами или выражением:
/// - `base.png`    — обычный вид, рот закрыт, глаза открыты (обязательно);
/// - `mouth1.png`  — рот приоткрыт;
/// - `mouth2.png`  — рот широко открыт;
/// - `blink.png`   — глаза закрыты;
/// - `listen.png`  — слушает (например, ушки торчком, взгляд вверх);
/// - `think.png`   — думает (взгляд в сторону).
/// Кроме base, все необязательны: чего нет, то не показывается.
class SpriteSet {
  const SpriteSet(this.frames);

  /// Имя кадра без .png → путь к файлу.
  final Map<String, String> frames;

  static const names = ['base', 'mouth1', 'mouth2', 'blink', 'listen', 'think'];

  static final _cache = <String, SpriteSet?>{};

  /// Ищет картинки персонажа в сборке. null — картинок нет,
  /// тогда показывается нарисованный кодом персонаж.
  static Future<SpriteSet?> load(String id, {AssetBundle? bundle}) async {
    if (_cache.containsKey(id)) return _cache[id];
    final b = bundle ?? rootBundle;
    Set<String> assets;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(b);
      assets = manifest.listAssets().toSet();
    } catch (_) {
      assets = {};
    }
    final set = fromAssets(id, assets);
    _cache[id] = set;
    return set;
  }

  /// Открыто для тестов: выбирает кадры персонажа из списка файлов сборки.
  static SpriteSet? fromAssets(String id, Iterable<String> assets) {
    final have = assets.toSet();
    final frames = <String, String>{};
    for (final n in names) {
      final path = 'assets/characters/$id/$n.png';
      if (have.contains(path)) frames[n] = path;
    }
    return frames.containsKey('base') ? SpriteSet(frames) : null;
  }

  /// Какой кадр показать сейчас. Рот важнее моргания: во время речи
  /// персонаж не «закрывает глаза» вместо того, чтобы говорить.
  String frameFor({
    required double mouth,
    required double blink,
    required bool listening,
    required bool thinking,
  }) {
    String? pick(String n) => frames[n];
    if (mouth > 0.55) {
      final f = pick('mouth2') ?? pick('mouth1');
      if (f != null) return f;
    }
    if (mouth > 0.18) {
      final f = pick('mouth1') ?? pick('mouth2');
      if (f != null) return f;
    }
    if (blink > 0.5) {
      final f = pick('blink');
      if (f != null) return f;
    }
    if (thinking) {
      final f = pick('think');
      if (f != null) return f;
    }
    if (listening) {
      final f = pick('listen');
      if (f != null) return f;
    }
    return frames['base']!;
  }
}

/// Персонаж из картинок: кадры сменяются мгновенно (без растворения,
/// чтобы рот не «двоился»), а движение даёт трансформация всей фигуры.
class SpriteCharacter extends StatelessWidget {
  const SpriteCharacter({
    super.key,
    required this.sprites,
    required this.mouth,
    required this.blink,
    required this.breath,
    required this.lookUp,
    required this.lookSide,
    required this.listening,
    required this.thinking,
  });

  final SpriteSet sprites;
  final double mouth;
  final double blink;

  /// 0..1, медленное «дыхание».
  final double breath;

  /// 0..1, плавные переходы в «слушает» и «думает».
  final double lookUp;
  final double lookSide;
  final bool listening;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final frame = sprites.frameFor(
      mouth: mouth,
      blink: blink,
      listening: listening,
      thinking: thinking,
    );
    // Дыхание — чуть выше и уже, речь — лёгкий подскок, слушает —
    // тянется вверх, думает — наклоняет голову.
    final sy = 1 + 0.02 * breath + 0.02 * mouth;
    final sx = 1 - 0.008 * breath;
    final dy = -6.0 * mouth - 8.0 * lookUp;
    final angle = -0.07 * lookSide + 0.015 * math.sin(breath * math.pi);
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..translateByDouble(0, dy, 0, 1)
        ..rotateZ(angle)
        ..scaleByDouble(sx, sy, 1, 1),
      child: Image.asset(
        frame,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Заранее загружает все кадры, чтобы при первом открытии рта
/// картинка не мигала пустотой.
Future<void> precacheSprites(BuildContext context, SpriteSet s) async {
  for (final p in s.frames.values) {
    await precacheImage(AssetImage(p), context);
  }
}
