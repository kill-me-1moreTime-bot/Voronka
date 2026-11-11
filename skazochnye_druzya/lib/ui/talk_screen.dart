import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../characters.dart';
import '../child_profile.dart';
import '../debug_log.dart';
import '../session/conversation_controller.dart';
import 'character_view.dart';
import 'parent_gate.dart';

class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key, required this.character, required this.child});

  final CharacterProfile character;
  final ChildProfile child;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  late final ConversationController _c = ConversationController(
    character: widget.character,
    child: widget.child,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _c.start();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _c.dispose();
    super.dispose();
  }

  /// Новая попытка — новый экран с тем же персонажем: так разговор
  /// начинается с чистого состояния.
  void _retry() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          TalkScreen(character: widget.character, child: widget.child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color.lerp(widget.character.color, Colors.white, 0.8)!;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final s = _c.state;
            return Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.home_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    // Журнал для взрослого — тоже долгим нажатием.
                    ParentGate(
                      icon: Icons.receipt_long_outlined,
                      onUnlocked: () => _showLog(context),
                    ),
                  ],
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _c.interrupt,
                    child: CharacterView(
                      character: widget.character,
                      mouth: _c.mouth,
                      listening: s == TalkState.listening ||
                          s == TalkState.childSpeaking,
                      thinking: s == TalkState.thinking,
                    ),
                  ),
                ),
                _StatusHint(state: s, error: _c.errorText),
                const SizedBox(height: 16),
                _Controls(controller: _c, onRetry: _retry),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _showLog(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _LogSheet(),
  );
}

/// Технический журнал: события сервера, ошибки, срабатывания фильтра.
class _LogSheet extends StatelessWidget {
  const _LogSheet();

  @override
  Widget build(BuildContext context) {
    final text = DebugLog.lines.join('\n');
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            ListTile(
              title: const Text('Журнал подключения'),
              subtitle: const Text('Время московское'),
              trailing: TextButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Копировать'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Журнал скопирован')),
                  );
                },
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  text.isEmpty ? 'Пока пусто' : text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Подсказка без слов — малыш не читает.
class _StatusHint extends StatelessWidget {
  const _StatusHint({required this.state, this.error});

  final TalkState state;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (state) {
      TalkState.connecting => (Icons.wifi_rounded, 'Подключаемся…'),
      TalkState.listening => (Icons.hearing_rounded, 'Слушаю'),
      TalkState.childSpeaking => (Icons.graphic_eq_rounded, 'Слушаю'),
      TalkState.thinking => (Icons.more_horiz_rounded, 'Думаю'),
      TalkState.speaking => (Icons.record_voice_over_rounded, ''),
      TalkState.paused => (Icons.pause_circle_rounded, 'Пауза'),
      TalkState.finished => (Icons.brush_rounded, 'Пока-пока! Пора рисовать'),
      TalkState.error => (Icons.error_outline_rounded, error ?? 'Ошибка'),
    };
    final pulse =
        state == TalkState.listening || state == TalkState.childSpeaking;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          AnimatedScale(
            scale: state == TalkState.childSpeaking ? 1.3 : 1,
            duration: const Duration(milliseconds: 200),
            child: Icon(icon,
                size: 56,
                color: pulse
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black45),
          ),
          if (label.isNotEmpty)
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// Кнопки для взрослого: пауза/продолжить и завершить.
class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.onRetry});

  final ConversationController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final home = FilledButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.home_rounded),
      label: const Text('Домой'),
    );
    if (s == TalkState.error) {
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Ещё раз'),
          ),
          home,
        ],
      );
    }
    if (s == TalkState.finished) return home;
    final paused = s == TalkState.paused;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          iconSize: 40,
          onPressed: paused ? controller.resume : controller.pause,
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        ),
        const SizedBox(width: 24),
        // «Угадай, кто я» — большая лапка, без слов: малыш не читает.
        IconButton.filled(
          iconSize: 48,
          tooltip: 'Угадай, кто я',
          onPressed: controller.canStartGame ? controller.startGuessGame : null,
          icon: const Icon(Icons.pets_rounded),
        ),
        const SizedBox(width: 24),
        IconButton.filledTonal(
          iconSize: 40,
          onPressed: controller.finish,
          icon: const Icon(Icons.stop_rounded),
        ),
      ],
    );
  }
}
