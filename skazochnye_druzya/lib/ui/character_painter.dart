import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../characters.dart';

/// Временный нарисованный персонаж. Задача 1 в docs/CURSOR_TASKS.md —
/// заменить его на Rive с теми же входами: mouth, blink, lookUp, lookSide.
class CharacterPainter extends CustomPainter {
  CharacterPainter({
    required this.kind,
    required this.color,
    this.mouth = 0,
    this.blink = 0,
    this.lookUp = 0,
    this.lookSide = 0,
  });

  final CharacterKind kind;
  final Color color;

  /// 0 — рот закрыт, 1 — широко открыт.
  final double mouth;

  /// 0 — глаза открыты, 1 — закрыты.
  final double blink;

  /// Взгляд вверх (слушает) и в сторону (думает), 0..1.
  final double lookUp;
  final double lookSide;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height * 0.56);
    final r = s * 0.32;

    final fur = Paint()..color = color;
    final dark = Paint()..color = Color.lerp(color, Colors.black, 0.35)!;
    final light = Paint()..color = Color.lerp(color, Colors.white, 0.55)!;
    final ink = Paint()..color = const Color(0xFF2B2522);
    final pink = Paint()..color = const Color(0x55FF7A8A);

    _ears(canvas, c, r, fur, dark);

    canvas.drawCircle(c, r, fur);

    // Щенок: пятнышко вокруг глаза.
    if (kind == CharacterKind.puppy) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(r * 0.38, -r * 0.1),
          width: r * 0.62,
          height: r * 0.7,
        ),
        dark,
      );
    }

    // Мордочка
    final muzzle = Rect.fromCenter(
      center: c.translate(0, r * 0.38),
      width: r *
          (kind == CharacterKind.wolf || kind == CharacterKind.fox
              ? 1.0
              : 0.95),
      height: r * 0.72,
    );
    canvas.drawOval(muzzle, light);

    // Щёчки
    canvas.drawCircle(c.translate(-r * 0.58, r * 0.28), r * 0.13, pink);
    canvas.drawCircle(c.translate(r * 0.58, r * 0.28), r * 0.13, pink);

    // Глаза
    final eyeShift = Offset(lookSide * r * 0.08, -lookUp * r * 0.06);
    for (final dx in [-0.36, 0.36]) {
      final eye = c.translate(dx * r, -r * 0.08) + eyeShift;
      final h = r * 0.2 * (1 - blink).clamp(0.08, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: r * 0.16, height: h),
        ink,
      );
      if (blink < 0.5) {
        canvas.drawCircle(
          eye.translate(r * 0.03, -r * 0.04),
          r * 0.03,
          Paint()..color = Colors.white,
        );
      }
    }

    // Нос. У поросёнка — пятачок с двумя ноздрями.
    final nose = c.translate(0, r * 0.2);
    if (kind == CharacterKind.pig) {
      canvas.drawOval(
        Rect.fromCenter(center: nose, width: r * 0.52, height: r * 0.36),
        Paint()..color = Color.lerp(color, const Color(0xFFE0607A), 0.45)!,
      );
      for (final dx in [-0.09, 0.09]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: nose.translate(dx * r, 0),
            width: r * 0.07,
            height: r * 0.13,
          ),
          dark,
        );
      }
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: nose, width: r * 0.24, height: r * 0.16),
        ink,
      );
    }

    // Рот: улыбка или открытый овал
    final mouthTop =
        nose.translate(0, r * (kind == CharacterKind.pig ? 0.26 : 0.18));
    if (mouth < 0.08) {
      final smile = Path()
        ..moveTo(mouthTop.dx - r * 0.18, mouthTop.dy)
        ..quadraticBezierTo(mouthTop.dx, mouthTop.dy + r * 0.14,
            mouthTop.dx + r * 0.18, mouthTop.dy);
      canvas.drawPath(
        smile,
        Paint()
          ..color = ink.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final h = r * (0.06 + 0.26 * mouth);
      final mouthRect = Rect.fromCenter(
        center: mouthTop.translate(0, h / 2),
        width: r * (0.26 + 0.08 * mouth),
        height: h,
      );
      canvas.drawOval(mouthRect, Paint()..color = const Color(0xFF6B2A2E));
      canvas.drawOval(
        Rect.fromCenter(
          center: mouthRect.bottomCenter.translate(0, -h * 0.25),
          width: mouthRect.width * 0.6,
          height: h * 0.4,
        ),
        Paint()..color = const Color(0xFFE5737F),
      );
    }
  }

  void _ears(Canvas canvas, Offset c, double r, Paint fur, Paint inner) {
    switch (kind) {
      case CharacterKind.bear:
        for (final dx in [-0.72, 0.72]) {
          final p = c.translate(dx * r, -r * 0.72);
          canvas.drawCircle(p, r * 0.32, fur);
          canvas.drawCircle(p, r * 0.18, inner);
        }
      case CharacterKind.pig:
        // Маленькие треугольные ушки с загнутым кончиком. Рисуем одно
        // и отражаем — так они точно одинаковые.
        for (final side in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.scale(side, 1);
          final ear = Path()
            ..moveTo(r * 0.3, -r * 0.82)
            ..quadraticBezierTo(r * 0.78, -r * 1.3, r * 0.98, -r * 0.92)
            ..quadraticBezierTo(r * 0.95, -r * 0.6, r * 0.82, -r * 0.42)
            ..close();
          canvas.drawPath(
            ear,
            Paint()..color = Color.lerp(color, const Color(0xFFD9778A), 0.6)!,
          );
          canvas.restore();
        }
      case CharacterKind.puppy:
        // Висячие уши по бокам.
        for (final side in [-1.0, 1.0]) {
          canvas.save();
          final base = c.translate(side * r * 0.82, -r * 0.35);
          canvas.translate(base.dx, base.dy);
          canvas.rotate(side * -0.35);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(0, r * 0.3),
              width: r * 0.46,
              height: r * 0.95,
            ),
            inner,
          );
          canvas.restore();
        }
      case CharacterKind.fox:
        // Острые уши с тёмными кончиками.
        for (final side in [-1.0, 1.0]) {
          final base = c.translate(side * r * 0.55, -r * 0.6);
          final tip = Offset(base.dx + side * r * 0.14, base.dy - r * 0.72);
          final outer = Path()
            ..moveTo(base.dx - r * 0.34, base.dy + r * 0.2)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(base.dx + r * 0.34, base.dy + r * 0.2)
            ..close();
          canvas.drawPath(outer, fur);
          final dx0 = base.dx - r * 0.34, dx1 = base.dx + r * 0.34;
          final y0 = base.dy + r * 0.2;
          // Кончик — верхняя треть уха.
          final cap = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(
                tip.dx + (dx0 - tip.dx) * 0.38, tip.dy + (y0 - tip.dy) * 0.38)
            ..lineTo(
                tip.dx + (dx1 - tip.dx) * 0.38, tip.dy + (y0 - tip.dy) * 0.38)
            ..close();
          canvas.drawPath(cap, Paint()..color = const Color(0xFF3B2A22));
        }
      case CharacterKind.wolf:
        for (final side in [-1.0, 1.0]) {
          final base = c.translate(side * r * 0.55, -r * 0.6);
          final outer = Path()
            ..moveTo(base.dx - r * 0.32, base.dy + r * 0.2)
            ..lineTo(base.dx + side * r * 0.12, base.dy - r * 0.62)
            ..lineTo(base.dx + r * 0.32, base.dy + r * 0.2)
            ..close();
          canvas.drawPath(outer, fur);
          final inn = Path()
            ..moveTo(base.dx - r * 0.16, base.dy + r * 0.12)
            ..lineTo(base.dx + side * r * 0.08, base.dy - r * 0.38)
            ..lineTo(base.dx + r * 0.16, base.dy + r * 0.12)
            ..close();
          canvas.drawPath(inn, inner);
        }
      case CharacterKind.bunny:
        for (final side in [-1.0, 1.0]) {
          canvas.save();
          final base = c.translate(side * r * 0.4, -r * 0.85);
          canvas.translate(base.dx, base.dy);
          canvas.rotate(side * 0.18);
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(0, -r * 0.35), width: r * 0.42, height: r * 1.2),
            fur,
          );
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(0, -r * 0.35), width: r * 0.2, height: r * 0.9),
            Paint()..color = const Color(0xFFF4B7C0),
          );
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(CharacterPainter old) =>
      old.mouth != mouth ||
      old.blink != blink ||
      old.lookUp != lookUp ||
      old.lookSide != lookSide ||
      old.color != color ||
      old.kind != kind;
}
