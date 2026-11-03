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

    // Мордочка
    final muzzle = Rect.fromCenter(
      center: c.translate(0, r * 0.38),
      width: r * (kind == CharacterKind.wolf ? 1.0 : 0.95),
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

    // Нос
    final nose = c.translate(0, r * 0.2);
    canvas.drawOval(
      Rect.fromCenter(center: nose, width: r * 0.24, height: r * 0.16),
      ink,
    );

    // Рот: улыбка или открытый овал
    final mouthTop = nose.translate(0, r * 0.18);
    if (mouth < 0.08) {
      final smile = Path()
        ..moveTo(mouthTop.dx - r * 0.18, mouthTop.dy)
        ..quadraticBezierTo(
            mouthTop.dx, mouthTop.dy + r * 0.14, mouthTop.dx + r * 0.18,
            mouthTop.dy);
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
