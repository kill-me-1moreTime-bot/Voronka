import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../characters.dart';
import 'character_painter.dart';

/// Живой персонаж: моргает, «дышит», открывает рот по громкости,
/// смотрит вверх, когда слушает, и в сторону, когда думает.
class CharacterView extends StatefulWidget {
  const CharacterView({
    super.key,
    required this.character,
    this.mouth = 0,
    this.listening = false,
    this.thinking = false,
  });

  final CharacterProfile character;
  final double mouth;
  final bool listening;
  final bool thinking;

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  Timer? _blinkTimer;
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 2000 + _rnd.nextInt(3000)),
        () async {
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breath.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _blink]),
      builder: (context, _) {
        final scale = 1 + 0.015 * _breath.value + 0.03 * widget.mouth;
        return Transform.scale(
          scale: scale,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.listening ? 1 : 0),
            duration: const Duration(milliseconds: 300),
            builder: (context, up, _) => TweenAnimationBuilder<double>(
              tween: Tween(end: widget.thinking ? 1 : 0),
              duration: const Duration(milliseconds: 400),
              builder: (context, side, _) => CustomPaint(
                painter: CharacterPainter(
                  kind: widget.character.kind,
                  color: widget.character.color,
                  mouth: widget.mouth,
                  blink: _blink.value,
                  lookUp: up,
                  lookSide: side,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}
