import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../characters.dart';
import '../scenes.dart';
import 'character_view.dart';
import 'home_painter.dart';

/// Сцена на экране разговора: счёт, прятки, загадка, картина дома.
/// Без слов — малыш не читает; цифра у счёта крупная.
class SceneView extends StatelessWidget {
  const SceneView({
    super.key,
    required this.scene,
    required this.character,
    required this.progress,
    required this.onHideTap,
  });

  final Scene scene;
  final CharacterProfile character;

  /// Сколько ответа прозвучало, 0..1.
  final double progress;

  /// Нажали на куст; true — персонаж был за ним.
  final bool Function(int place) onHideTap;

  @override
  Widget build(BuildContext context) {
    return switch (scene) {
      CountScene(:final thing, :final n) =>
        _CountView(thing: thing, n: n, progress: progress),
      HideScene(:final place) =>
        _HideView(place: place, character: character, onTap: onHideTap),
      GuessScene(:final animal) => _GuessView(animal: animal),
      HomeScene() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AspectRatio(
            aspectRatio: 1.05,
            child: CustomPaint(
              painter: HomePainter(
                character: character,
                progress: progress * HomePainter.layers,
              ),
            ),
          ),
        ),
    };
  }
}

/// Предмет счёта: картинка-значок или рисунок (шишка, малинка).
class ThingIcon extends StatelessWidget {
  const ThingIcon(this.thing, {super.key, this.size = 64});

  final String thing;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (thing == 'cone' || thing == 'raspberry') {
      return CustomPaint(
        size: Size.square(size),
        painter: _ThingPainter(thing),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(child: Text(thing)),
    );
  }
}

class _ThingPainter extends CustomPainter {
  _ThingPainter(this.thing);
  final String thing;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    if (thing == 'raspberry') {
      final berry = Paint()..color = const Color(0xFFD83A5C);
      final light = Paint()..color = const Color(0xFFEF6B86);
      var row = 0;
      for (final count in [3, 4, 3, 2]) {
        for (var i = 0; i < count; i++) {
          final p = Offset(
            c.dx + (i - (count - 1) / 2) * s * 0.2,
            s * (0.34 + row * 0.16),
          );
          canvas.drawCircle(p, s * 0.115, (i + row).isEven ? berry : light);
        }
        row++;
      }
      final leaf = Paint()..color = const Color(0xFF5FA34F);
      for (final dx in [-0.16, 0.0, 0.16]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(c.dx + dx * s, s * 0.2),
            width: s * 0.2,
            height: s * 0.13,
          ),
          leaf,
        );
      }
      return;
    }
    // Шишка: коричневый овал с чешуйками.
    final body = Rect.fromCenter(center: c, width: s * 0.56, height: s * 0.82);
    canvas.drawOval(body, Paint()..color = const Color(0xFF9A6B42));
    final scale = Paint()
      ..color = const Color(0xFF6E4A2C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    for (var row = 0; row < 6; row++) {
      final y = body.top + body.height * (0.14 + row * 0.15);
      for (var i = -2; i <= 2; i++) {
        final x = c.dx + (i + (row.isEven ? 0 : 0.5)) * s * 0.18;
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(x, y), width: s * 0.18, height: s * 0.16),
          0,
          math.pi,
          false,
          scale,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThingPainter old) => old.thing != thing;
}

/// Нажал — подпрыгнуло. Для предметов счёта и кустов.
class _Bouncy extends StatefulWidget {
  const _Bouncy({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<_Bouncy> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _a.forward(from: 0);
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -18 * math.sin(_a.value * math.pi)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _CountView extends StatelessWidget {
  const _CountView({
    required this.thing,
    required this.n,
    required this.progress,
  });

  final String thing;
  final int n;
  final double progress;

  /// Сколько предметов уже видно: появляются по одному, пока персонаж
  /// считает; к концу фразы — все.
  static int visible(int n, double progress) =>
      (progress * (n + 0.5)).floor().clamp(0, n);

  @override
  Widget build(BuildContext context) {
    final shown = visible(n, progress);
    final size = n <= 4 ? 84.0 : (n <= 6 ? 72.0 : 60.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          shown == 0 ? ' ' : '$shown',
          style: TextStyle(
            fontSize: 72,
            height: 1,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < n; i++)
                AnimatedScale(
                  scale: i < shown ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: _Bouncy(child: ThingIcon(thing, size: size)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HideView extends StatelessWidget {
  const _HideView({
    required this.place,
    required this.character,
    required this.onTap,
  });

  final int place;
  final CharacterProfile character;
  final bool Function(int place) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(box.maxWidth / 3, 150.0);
        // Кусты по центру экрана, а не у нижнего края.
        return Center(
            child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              _Bouncy(
                onTap: () => onTap(i),
                child: SizedBox(
                  width: w,
                  height: w * 1.5,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // За своим кустом персонаж выглядывает: видны
                      // макушка и ушки.
                      if (i == place)
                        Positioned(
                          bottom: w * 0.46,
                          width: w * 0.8,
                          height: w * 0.8,
                          child: CharacterView(character: character),
                        ),
                      CustomPaint(
                        size: Size(w, w * 0.95),
                        painter: _BushPainter(i),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ));
      },
    );
  }
}

class _BushPainter extends CustomPainter {
  _BushPainter(this.variant);
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const greens = [0xFF5FA34F, 0xFF4F9447, 0xFF6DB15A];
    final a = Paint()..color = Color(greens[variant % 3]);
    final b = Paint()..color = Color(greens[(variant + 1) % 3]);
    canvas.drawCircle(Offset(w * 0.28, h * 0.62), w * 0.28, b);
    canvas.drawCircle(Offset(w * 0.72, h * 0.62), w * 0.28, b);
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), w * 0.36, a);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.62, w * 0.92, h * 0.38),
        Radius.circular(w * 0.18),
      ),
      a,
    );
    // Ягодки или цветочки — чтобы кусты отличались.
    const dots = [0xFFE8574B, 0xFFFFD95A, 0xFFF08CA8];
    final d = Paint()..color = Color(dots[variant % 3]);
    for (final p in const [
      Offset(0.3, 0.55),
      Offset(0.55, 0.4),
      Offset(0.7, 0.66),
      Offset(0.42, 0.78),
    ]) {
      canvas.drawCircle(Offset(w * p.dx, h * p.dy), w * 0.035, d);
    }
  }

  @override
  bool shouldRepaint(_BushPainter old) => old.variant != variant;
}

class _GuessView extends StatelessWidget {
  const _GuessView({this.animal});

  final String? animal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: child,
        ),
        child: _Bouncy(
          key: ValueKey(animal),
          child: SizedBox(
            width: 220,
            height: 220,
            child: FittedBox(child: Text(animal ?? '❓')),
          ),
        ),
      ),
    );
  }
}

/// Для тестов: сколько предметов счёта видно при таком прогрессе речи.
abstract final class SceneViewTest {
  static int visible(int n, double progress) => _CountView.visible(n, progress);
}
