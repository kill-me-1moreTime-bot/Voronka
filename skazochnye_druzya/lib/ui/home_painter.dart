import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../characters.dart';
import 'character_painter.dart';

/// Картина дома персонажа. Рисуется шестью слоями, каждый проявляется
/// по очереди — будто картину пишут на глазах:
/// 0 небо и земля, 1 сам дом, 2 деревья и кусты, 3 мелочи из жизни
/// персонажа, 4 сам персонаж у дома, 5 солнце, облака, птицы, цветы.
///
/// Нарисовано кодом, в стиле нарисованных персонажей. Когда появятся
/// картинки домов, их можно будет показывать вместо этого рисунка.
class HomePainter extends CustomPainter {
  HomePainter({required this.character, required this.progress});

  final CharacterProfile character;

  /// 0..[layers]: целая часть — сколько слоёв готово, дробная — как
  /// проявился следующий.
  final double progress;

  static const layers = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.06),
    ));
    // Бумага под картиной.
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFFBF6EC));

    final steps = <void Function(Canvas, double, double)>[
      _skyAndGround,
      _home,
      _plants,
      _details,
      _hero,
      _sunAndBirds,
    ];
    for (var i = 0; i < steps.length; i++) {
      final a = (progress - i).clamp(0.0, 1.0);
      if (a <= 0) break;
      // Слой проявляется слева направо, как мазок кисти.
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
      if (a < 1) {
        canvas.clipRect(Rect.fromLTWH(0, 0, w * (0.15 + 0.85 * a), h));
      }
      steps[i](canvas, w, h);
      canvas.restore();
    }
    canvas.restore();
  }

  String get _id => character.id;

  double get _horizon => switch (_id) {
        'bunny' => 0.62,
        'pig' || 'puppy' => 0.6,
        _ => 0.58,
      };

  static Paint _p(int color) => Paint()..color = Color(color);

  // ── 0. Небо и земля ───────────────────────────────────────────────

  void _skyAndGround(Canvas c, double w, double h) {
    final sky = Rect.fromLTWH(0, 0, w, h);
    c.drawRect(
      sky,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBFE3F7), Color(0xFFEAF6FB)],
        ).createShader(sky),
    );
    final y = h * _horizon;
    final ground = switch (_id) {
      'bunny' => 0xFF9BD27A, // луг
      'pig' || 'puppy' => 0xFFB5D889, // двор
      _ => 0xFF86B86B, // лес
    };
    // Мягкий холм вместо ровной линии.
    final hill = Path()
      ..moveTo(0, y + h * 0.03)
      ..quadraticBezierTo(w * 0.3, y - h * 0.05, w * 0.6, y + h * 0.01)
      ..quadraticBezierTo(w * 0.85, y + h * 0.04, w, y - h * 0.01)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    c.drawPath(hill, _p(ground));
    // Тропинка к дому.
    final path = Path()
      ..moveTo(w * 0.42, h)
      ..quadraticBezierTo(w * 0.5, h * 0.84, w * 0.47, h * 0.74)
      ..lineTo(w * 0.55, h * 0.74)
      ..quadraticBezierTo(w * 0.6, h * 0.86, w * 0.62, h)
      ..close();
    c.drawPath(path, _p(0xFFE7D3A8));
  }

  // ── 1. Дом ────────────────────────────────────────────────────────

  void _home(Canvas c, double w, double h) {
    final base = h * 0.76;
    switch (_id) {
      case 'bear':
        _mound(c, Offset(w * 0.5, base), w * 0.56, h * 0.3, 0xFF8A6A4A);
        _hole(c, Offset(w * 0.5, base), w * 0.2, h * 0.17);
      case 'wolf':
        _mound(c, Offset(w * 0.42, base), w * 0.5, h * 0.24, 0xFF93A77A);
        _hole(c, Offset(w * 0.42, base), w * 0.17, h * 0.14);
        // Ручей.
        final stream = Path()
          ..moveTo(w * 0.62, h * 0.66)
          ..quadraticBezierTo(w * 0.82, h * 0.74, w * 0.7, h * 0.86)
          ..quadraticBezierTo(w * 0.62, h * 0.94, w * 0.78, h)
          ..lineTo(w, h)
          ..lineTo(w, h * 0.9)
          ..quadraticBezierTo(w * 0.86, h * 0.84, w * 0.95, h * 0.72)
          ..quadraticBezierTo(w * 0.9, h * 0.64, w * 0.74, h * 0.63)
          ..close();
        c.drawPath(stream, _p(0xFF8CCBEE));
      case 'bunny':
        _house(c, w, h, wall: 0xFFFFF3DC, roof: 0xFFE8736B, door: 0xFFB9794C);
      case 'fox':
        _mound(c, Offset(w * 0.52, base), w * 0.52, h * 0.22, 0xFFB98B5E);
        _hole(c, Offset(w * 0.52, base), w * 0.18, h * 0.14);
        // Корни сосны над входом.
        final root = Paint()
          ..color = const Color(0xFF7A5234)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.022
          ..strokeCap = StrokeCap.round;
        for (final dx in [-0.16, -0.06, 0.07, 0.17]) {
          c.drawPath(
            Path()
              ..moveTo(w * 0.52, h * 0.5)
              ..quadraticBezierTo(
                  w * (0.52 + dx * 0.6), h * 0.6, w * (0.52 + dx), h * 0.7),
            root,
          );
        }
      case 'pig':
        _house(c, w, h,
            wall: 0xFFFBE7B5, roof: 0xFFE2B33C, door: 0xFF9A6A3F, straw: true);
      case 'puppy':
        // Будка.
        final body = Rect.fromLTWH(w * 0.33, h * 0.52, w * 0.36, h * 0.25);
        c.drawRRect(
          RRect.fromRectAndRadius(body, Radius.circular(w * 0.015)),
          _p(0xFFD79A5B),
        );
        final plank = Paint()
          ..color = const Color(0xFFB87C43)
          ..strokeWidth = w * 0.006;
        for (var i = 1; i < 4; i++) {
          final y = body.top + body.height * i / 4;
          c.drawLine(Offset(body.left, y), Offset(body.right, y), plank);
        }
        final roof = Path()
          ..moveTo(w * 0.29, h * 0.54)
          ..lineTo(w * 0.51, h * 0.36)
          ..lineTo(w * 0.73, h * 0.54)
          ..close();
        c.drawPath(roof, _p(0xFFC0503F));
        _hole(c, Offset(w * 0.51, h * 0.77), w * 0.17, h * 0.16);
      default:
        _house(c, w, h, wall: 0xFFFFF3DC, roof: 0xFFB56B4A, door: 0xFF8C5B3A);
    }
  }

  void _mound(
      Canvas c, Offset bottomCenter, double width, double height, int color) {
    final r = Rect.fromCenter(
      center: bottomCenter,
      width: width,
      height: height * 2,
    );
    c.save();
    c.clipRect(Rect.fromLTRB(r.left, r.top, r.right, bottomCenter.dy));
    c.drawOval(r, _p(color));
    c.restore();
  }

  void _hole(Canvas c, Offset bottomCenter, double width, double height) {
    final r = Rect.fromCenter(
      center: bottomCenter,
      width: width,
      height: height * 2,
    );
    c.save();
    c.clipRect(Rect.fromLTRB(r.left, r.top, r.right, bottomCenter.dy));
    c.drawOval(r, _p(0xFF3E2C22));
    c.restore();
  }

  void _house(Canvas c, double w, double h,
      {required int wall,
      required int roof,
      required int door,
      bool straw = false}) {
    final body = Rect.fromLTWH(w * 0.3, h * 0.5, w * 0.4, h * 0.27);
    c.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.015)),
      _p(wall),
    );
    final r = Path()
      ..moveTo(w * 0.24, h * 0.52)
      ..quadraticBezierTo(w * 0.5, h * (straw ? 0.24 : 0.3), w * 0.76, h * 0.52)
      ..close();
    c.drawPath(r, _p(roof));
    if (straw) {
      final line = Paint()
        ..color = const Color(0xFFB98A22)
        ..strokeWidth = w * 0.006;
      for (var i = 0; i < 9; i++) {
        final x = w * (0.3 + i * 0.05);
        c.drawLine(Offset(x, h * 0.4), Offset(x - w * 0.02, h * 0.515), line);
      }
    }
    // Дверь и окошко.
    c.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.45, h * 0.61, w * 0.1, h * 0.16),
        topLeft: Radius.circular(w * 0.05),
        topRight: Radius.circular(w * 0.05),
      ),
      _p(door),
    );
    final win = Rect.fromLTWH(w * 0.6, h * 0.58, w * 0.065, w * 0.065);
    c.drawRect(win, _p(0xFFBFE3F7));
    final frame = Paint()
      ..color = Color(door)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008;
    c.drawRect(win, frame);
    c.drawLine(win.topCenter, win.bottomCenter, frame);
    c.drawLine(win.centerLeft, win.centerRight, frame);
  }

  // ── 2. Деревья и кусты ────────────────────────────────────────────

  void _plants(Canvas c, double w, double h) {
    switch (_id) {
      case 'bear':
        _spruce(c, Offset(w * 0.5, h * 0.52), w * 0.4, h * 0.36);
        _spruce(c, Offset(w * 0.12, h * 0.66), w * 0.2, h * 0.28);
        _spruce(c, Offset(w * 0.9, h * 0.64), w * 0.18, h * 0.24);
      case 'wolf':
        _tree(c, Offset(w * 0.14, h * 0.66), w * 0.24, h * 0.36);
        _tree(c, Offset(w * 0.3, h * 0.56), w * 0.2, h * 0.3);
        _spruce(c, Offset(w * 0.56, h * 0.58), w * 0.16, h * 0.26);
      case 'bunny':
        _bush(c, Offset(w * 0.2, h * 0.74), w * 0.3, 0xFF5FA34F, 0xFFF08CA8);
        _bush(c, Offset(w * 0.84, h * 0.72), w * 0.22, 0xFF6FB25C, 0xFFF08CA8);
      case 'fox':
        _pine(c, Offset(w * 0.52, h * 0.56), w * 0.36, h * 0.4);
        _bush(c, Offset(w * 0.14, h * 0.74), w * 0.2, 0xFF5E9A4A, 0xFF5E9A4A);
        _bush(c, Offset(w * 0.88, h * 0.76), w * 0.2, 0xFF6DAA55, 0xFF6DAA55);
      case 'pig':
        _tree(c, Offset(w * 0.86, h * 0.64), w * 0.28, h * 0.42);
        _fence(c, w, h, from: 0.0, to: 0.26);
      case 'puppy':
        _bush(c, Offset(w * 0.2, h * 0.68), w * 0.36, 0xFF5E9A4A, 0xFFB79BE8);
        _fence(c, w, h, from: 0.74, to: 1.0);
      default:
        _tree(c, Offset(w * 0.15, h * 0.66), w * 0.24, h * 0.36);
    }
  }

  void _spruce(Canvas c, Offset base, double width, double height) {
    c.drawRect(
      Rect.fromCenter(
        center: base.translate(0, -height * 0.04),
        width: width * 0.12,
        height: height * 0.14,
      ),
      _p(0xFF6B4A2E),
    );
    for (var i = 0; i < 3; i++) {
      final y0 = base.dy - height * (0.08 + i * 0.27);
      final half = width * (0.5 - i * 0.12);
      c.drawPath(
        Path()
          ..moveTo(base.dx - half, y0)
          ..lineTo(base.dx, y0 - height * 0.4)
          ..lineTo(base.dx + half, y0)
          ..close(),
        _p(i.isEven ? 0xFF3E7D4A : 0xFF4A8F57),
      );
    }
  }

  void _tree(Canvas c, Offset base, double width, double height) {
    c.drawRect(
      Rect.fromLTWH(base.dx - width * 0.07, base.dy - height * 0.5,
          width * 0.14, height * 0.5),
      _p(0xFF7A5234),
    );
    final top = base.translate(0, -height * 0.66);
    c.drawCircle(top, width * 0.42, _p(0xFF5FA34F));
    c.drawCircle(top.translate(-width * 0.26, width * 0.12), width * 0.3,
        _p(0xFF6FB25C));
    c.drawCircle(
        top.translate(width * 0.26, width * 0.14), width * 0.3, _p(0xFF55964A));
  }

  void _pine(Canvas c, Offset base, double width, double height) {
    c.drawRect(
      Rect.fromLTWH(base.dx - width * 0.06, base.dy - height * 0.8,
          width * 0.12, height * 0.8),
      _p(0xFFB8763F),
    );
    final top = base.translate(0, -height * 0.84);
    c.drawOval(
      Rect.fromCenter(center: top, width: width, height: height * 0.3),
      _p(0xFF3F7F4C),
    );
    c.drawOval(
      Rect.fromCenter(
        center: top.translate(-width * 0.2, -height * 0.08),
        width: width * 0.6,
        height: height * 0.2,
      ),
      _p(0xFF4C925A),
    );
  }

  void _bush(Canvas c, Offset base, double width, int leaf, int bloom) {
    final r = width / 2;
    c.drawCircle(base.translate(-r * 0.5, -r * 0.45), r * 0.6, _p(leaf));
    c.drawCircle(base.translate(r * 0.5, -r * 0.45), r * 0.6, _p(leaf));
    c.drawCircle(base.translate(0, -r * 0.8), r * 0.7, _p(leaf));
    if (bloom == leaf) return;
    final rnd = math.Random(base.dx.round());
    for (var i = 0; i < 9; i++) {
      final a = rnd.nextDouble() * math.pi;
      final d = r * (0.2 + rnd.nextDouble() * 0.7);
      c.drawCircle(
        base.translate(math.cos(a) * d, -r * 0.3 - math.sin(a) * d * 0.9),
        r * 0.09,
        _p(bloom),
      );
    }
  }

  void _fence(Canvas c, double w, double h,
      {required double from, required double to}) {
    final wood = _p(0xFFE9D3A6);
    final y = h * 0.66;
    for (var x = from + 0.02; x < to; x += 0.045) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * x, y, w * 0.026, h * 0.13),
          Radius.circular(w * 0.01),
        ),
        wood,
      );
    }
    c.drawRect(
        Rect.fromLTWH(w * from, y + h * 0.04, w * (to - from), h * 0.018),
        wood);
  }

  // ── 3. Мелочи из жизни персонажа ──────────────────────────────────

  void _details(Canvas c, double w, double h) {
    switch (_id) {
      case 'bear':
        // Горшочек мёда и малина.
        final pot = Offset(w * 0.76, h * 0.82);
        c.drawOval(
          Rect.fromCenter(center: pot, width: w * 0.13, height: w * 0.12),
          _p(0xFFC9803F),
        );
        c.drawOval(
          Rect.fromCenter(
            center: pot.translate(0, -w * 0.05),
            width: w * 0.1,
            height: w * 0.035,
          ),
          _p(0xFFF2C14E),
        );
        _berries(c, Offset(w * 0.2, h * 0.86), w * 0.03, 0xFFD83A5C);
      case 'wolf':
        c.drawCircle(Offset(w * 0.2, h * 0.86), w * 0.05, _p(0xFFE8574B));
        c.drawCircle(Offset(w * 0.2, h * 0.86), w * 0.02, _p(0xFFFFFFFF));
        // Камушки у ручья.
        for (final p in [
          Offset(w * 0.64, h * 0.8),
          Offset(w * 0.72, h * 0.93)
        ]) {
          c.drawOval(
            Rect.fromCenter(center: p, width: w * 0.07, height: w * 0.04),
            _p(0xFFB9B4AC),
          );
        }
      case 'bunny':
        for (final x in [0.72, 0.8, 0.88]) {
          _carrot(c, Offset(w * x, h * 0.88), w * 0.05);
        }
      case 'fox':
        final rnd = math.Random(7);
        for (var i = 0; i < 7; i++) {
          final p = Offset(w * (0.1 + rnd.nextDouble() * 0.8),
              h * (0.8 + rnd.nextDouble() * 0.15));
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(rnd.nextDouble() * 3);
          c.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: w * 0.06, height: w * 0.03),
            _p(i.isEven ? 0xFFE58A3C : 0xFFE9B93E),
          );
          c.restore();
        }
      case 'pig':
        // Большая лужа.
        c.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.24, h * 0.88),
            width: w * 0.36,
            height: h * 0.1,
          ),
          _p(0xFF9CC9E3),
        );
        c.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.2, h * 0.875),
            width: w * 0.12,
            height: h * 0.025,
          ),
          _p(0xFFCDE6F3),
        );
        for (final x in [0.78, 0.84, 0.9]) {
          c.drawOval(
            Rect.fromCenter(
              center: Offset(w * x, h * 0.9),
              width: w * 0.035,
              height: w * 0.045,
            ),
            _p(0xFFA9743A),
          );
        }
      case 'puppy':
        c.drawCircle(Offset(w * 0.8, h * 0.88), w * 0.05, _p(0xFFE8574B));
        // Косточка.
        final bone = _p(0xFFFFFBF0);
        final b = Offset(w * 0.22, h * 0.9);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: b, width: w * 0.1, height: w * 0.025),
            Radius.circular(w * 0.012),
          ),
          bone,
        );
        for (final dx in [-0.05, 0.05]) {
          for (final dy in [-0.012, 0.012]) {
            c.drawCircle(b.translate(w * dx, w * dy), w * 0.016, bone);
          }
        }
    }
  }

  void _berries(Canvas c, Offset at, double r, int color) {
    for (final d in const [
      Offset(0, 0),
      Offset(2.2, 0.4),
      Offset(1.1, -1.8),
      Offset(4.2, -0.6),
      Offset(3.2, -2.2),
    ]) {
      c.drawCircle(at + d * r, r, _p(color));
    }
  }

  void _carrot(Canvas c, Offset at, double s) {
    c.drawPath(
      Path()
        ..moveTo(at.dx - s * 0.4, at.dy - s)
        ..lineTo(at.dx + s * 0.4, at.dy - s)
        ..lineTo(at.dx, at.dy + s * 0.9)
        ..close(),
      _p(0xFFF28A2E),
    );
    final leaf = Paint()
      ..color = const Color(0xFF5FA34F)
      ..strokeWidth = s * 0.22
      ..strokeCap = StrokeCap.round;
    for (final dx in [-0.5, 0.0, 0.5]) {
      c.drawLine(at.translate(0, -s), at.translate(s * dx, -s * 1.8), leaf);
    }
  }

  // ── 4. Сам персонаж у дома ────────────────────────────────────────

  void _hero(Canvas c, double w, double h) {
    final s = w * 0.3;
    c.save();
    c.translate(w * 0.5 - s / 2, h * 0.9 - s);
    CharacterPainter(kind: character.kind, color: character.color)
        .paint(c, Size(s, s));
    c.restore();
  }

  // ── 5. Солнце, облака, птицы, цветы ───────────────────────────────

  void _sunAndBirds(Canvas c, double w, double h) {
    final sun = Offset(w * 0.84, h * 0.14);
    final ray = Paint()
      ..color = const Color(0xFFF7C948)
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      c.drawLine(
        sun + Offset(math.cos(a), math.sin(a)) * w * 0.085,
        sun + Offset(math.cos(a), math.sin(a)) * w * 0.115,
        ray,
      );
    }
    c.drawCircle(sun, w * 0.07, _p(0xFFFFD95A));

    for (final p in [Offset(w * 0.2, h * 0.12), Offset(w * 0.62, h * 0.08)]) {
      final cloud = _p(0xFFFFFFFF);
      c.drawCircle(p, w * 0.05, cloud);
      c.drawCircle(p.translate(w * 0.05, w * 0.012), w * 0.04, cloud);
      c.drawCircle(p.translate(-w * 0.05, w * 0.015), w * 0.035, cloud);
    }

    final bird = Paint()
      ..color = const Color(0xFF4B5563)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..strokeCap = StrokeCap.round;
    for (final p in [Offset(w * 0.3, h * 0.26), Offset(w * 0.72, h * 0.28)]) {
      c.drawPath(
        Path()
          ..moveTo(p.dx - w * 0.03, p.dy)
          ..quadraticBezierTo(p.dx - w * 0.015, p.dy - w * 0.02, p.dx, p.dy)
          ..quadraticBezierTo(
              p.dx + w * 0.015, p.dy - w * 0.02, p.dx + w * 0.03, p.dy),
        bird,
      );
    }

    // Цветочки на траве.
    final rnd = math.Random(character.id.hashCode);
    const colors = [0xFFFFFFFF, 0xFFFFD95A, 0xFFF08CA8, 0xFFB79BE8];
    for (var i = 0; i < 10; i++) {
      final p = Offset(
        w * (0.04 + rnd.nextDouble() * 0.92),
        h * (0.8 + rnd.nextDouble() * 0.17),
      );
      // Не рисуем на тропинке.
      if (p.dx > w * 0.4 && p.dx < w * 0.64) continue;
      c.drawCircle(p, w * 0.013, _p(colors[i % colors.length]));
      c.drawCircle(p, w * 0.005, _p(0xFFF2A93B));
    }
  }

  @override
  bool shouldRepaint(HomePainter old) =>
      old.progress != progress || old.character.id != character.id;
}
