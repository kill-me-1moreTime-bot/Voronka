import 'package:flutter/material.dart';

/// Кнопка настроек для взрослых: открывается только долгим нажатием
/// (3 секунды), чтобы малыш не попал туда случайно.
class ParentGate extends StatefulWidget {
  const ParentGate({
    super.key,
    required this.onUnlocked,
    this.icon = Icons.settings_outlined,
  });

  final VoidCallback onUnlocked;
  final IconData icon;

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate>
    with SingleTickerProviderStateMixin {
  bool _unlocked = false;

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _unlocked = true;
        _hold.reset();
        widget.onUnlocked();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _unlocked = false;
        _hold.forward();
      },
      onTapUp: (_) => _hold.reverse(),
      onTapCancel: () => _hold.reverse(),
      onTap: () {
        if (_unlocked) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Для взрослых: удерживайте 3 секунды')),
        );
      },
      child: SizedBox(
        width: 56,
        height: 56,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: _hold.value, strokeWidth: 3),
              Icon(widget.icon),
            ],
          ),
        ),
      ),
    );
  }
}
