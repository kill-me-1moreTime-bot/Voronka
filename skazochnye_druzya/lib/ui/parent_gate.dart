import 'package:flutter/material.dart';

import '../device_auth.dart';

/// Кнопка для взрослых.
///
/// С `deviceAuth: true` открывается блокировкой телефона: отпечаток
/// пальца, лицо или PIN. Малыш её не пройдёт. Если блокировки на
/// телефоне нет — долгим нажатием 3 секунды, как без `deviceAuth`.
class ParentGate extends StatefulWidget {
  const ParentGate({
    super.key,
    required this.onUnlocked,
    this.icon = Icons.settings_outlined,
    this.deviceAuth = false,
  });

  final VoidCallback onUnlocked;
  final IconData icon;
  final bool deviceAuth;

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate>
    with SingleTickerProviderStateMixin {
  bool _unlocked = false;

  /// true — вход отпечатком, удержание выключено.
  bool _useDevice = false;
  bool _busy = false;

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
  void initState() {
    super.initState();
    if (widget.deviceAuth) {
      DeviceAuth.instance.supported().then((ok) {
        if (mounted && ok) setState(() => _useDevice = true);
      });
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _unlockWithDevice() async {
    if (_busy) return;
    _busy = true;
    final r = await DeviceAuth.instance.unlock();
    _busy = false;
    if (!mounted) return;
    switch (r) {
      case AuthOutcome.ok:
        widget.onUnlocked();
      case AuthOutcome.cancelled:
        break;
      case AuthOutcome.unavailable:
        setState(() => _useDevice = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Блокировка экрана на телефоне не настроена. '
              'Для взрослых: удерживайте 3 секунды'),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useDevice) {
      return Tooltip(
        message: 'Для взрослых',
        child: InkResponse(
          onTap: _unlockWithDevice,
          radius: 28,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(widget.icon),
          ),
        ),
      );
    }
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
