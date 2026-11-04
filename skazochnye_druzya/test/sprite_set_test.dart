import 'package:flutter_test/flutter_test.dart';
import 'package:skazochnye_druzya/ui/sprite_character.dart';

void main() {
  String p(String n) => 'assets/characters/wolf/$n.png';

  test('без base.png картинок нет — рисуем кодом', () {
    expect(SpriteSet.fromAssets('wolf', [p('mouth1')]), isNull);
    expect(SpriteSet.fromAssets('wolf', const []), isNull);
  });

  test('чужие папки и лишние файлы не берутся', () {
    final s = SpriteSet.fromAssets('wolf', [
      p('base'),
      'assets/characters/bear/mouth1.png',
      'assets/characters/wolf/other.png',
    ])!;
    expect(s.frames.keys, ['base']);
  });

  group('выбор кадра', () {
    final full = SpriteSet.fromAssets('wolf', [
      for (final n in SpriteSet.names) p(n),
    ])!;

    String f(SpriteSet s,
            {double mouth = 0,
            double blink = 0,
            bool listening = false,
            bool thinking = false}) =>
        s.frameFor(
            mouth: mouth,
            blink: blink,
            listening: listening,
            thinking: thinking);

    test('рот по громкости', () {
      expect(f(full), p('base'));
      expect(f(full, mouth: 0.3), p('mouth1'));
      expect(f(full, mouth: 0.9), p('mouth2'));
    });

    test('во время речи не моргает', () {
      expect(f(full, mouth: 0.9, blink: 1), p('mouth2'));
      expect(f(full, blink: 1), p('blink'));
    });

    test('слушает и думает', () {
      expect(f(full, listening: true), p('listen'));
      expect(f(full, thinking: true), p('think'));
    });

    test('если есть только один открытый рот — он для любой громкости', () {
      final s = SpriteSet.fromAssets('wolf', [p('base'), p('mouth1')])!;
      expect(f(s, mouth: 0.9), p('mouth1'));
      expect(f(s, blink: 1, listening: true), p('base'));
    });
  });
}
