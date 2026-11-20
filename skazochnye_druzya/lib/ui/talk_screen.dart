import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../characters.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../child_profile.dart';
import '../debug_log.dart';
import '../scenes.dart';
import '../session/conversation_controller.dart';
import 'character_view.dart';
import 'parent_gate.dart';
import 'scene_view.dart';

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
    _c.addListener(_syncWakelock);
    _c.start();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _c.removeListener(_syncWakelock);
    _setWakelock(false);
    _c.dispose();
    super.dispose();
  }

  bool _awake = false;

  /// Экран не гаснет, пока идёт разговор. На паузе, после прощания и
  /// при ошибке — гаснет как обычно, чтобы забытый телефон не разрядился.
  void _syncWakelock() {
    final s = _c.state;
    _setWakelock(widget.child.keepScreenOn &&
        s != TalkState.paused &&
        s != TalkState.finished &&
        s != TalkState.error);
  }

  void _setWakelock(bool on) {
    if (on == _awake) return;
    _awake = on;
    // Разрешений не нужно: это флаг окна «не выключать экран».
    (on ? WakelockPlus.enable() : WakelockPlus.disable())
        .catchError((Object _) {});
  }

  Future<void> _pickFriend() async {
    final friends =
        characters.where((c) => c.id != widget.character.id).toList();
    final f = await showModalBottomSheet<CharacterProfile>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final f in friends)
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.of(context).pop(f),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Color.lerp(f.color, Colors.white, 0.75),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 88,
                          child: CharacterView(character: f),
                        ),
                        Text(
                          f.name.split(' ').first,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (f != null) _c.callFriend(f);
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
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final s = _c.state;
        final scene = _c.scene;
        final friend = _c.friend;
        final listening =
            s == TalkState.listening || s == TalkState.childSpeaking;
        // Фон — цвет того, кто сейчас говорит.
        final bg = Color.lerp(_c.speaker.color, Colors.white, 0.8)!;
        final hero = GestureDetector(
          onTap: _c.interrupt,
          child: CharacterView(
            character: _c.speaker,
            mouth: _c.mouth,
            listening: listening,
            thinking: s == TalkState.thinking,
          ),
        );
        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.home_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // «Где ты живёшь» — маленькая, наверху: персонаж
                    // рассказывает о доме, картина рисуется по его словам.
                    IconButton.filledTonal(
                      iconSize: 24,
                      tooltip: 'Где ты живёшь',
                      onPressed: _c.canStartGame ? _c.showHome : null,
                      icon: const Icon(Icons.cottage_rounded),
                    ),
                    const Spacer(),
                    // Журнал для взрослого — тоже долгим нажатием.
                    ParentGate(
                      icon: Icons.receipt_long_outlined,
                      onUnlocked: () => _showLog(context),
                    ),
                  ],
                ),
                if (friend != null)
                  // Звонок: друг крупно, тот, кто позвонил, — в уголке.
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: hero),
                        Positioned(
                          left: 12,
                          bottom: 0,
                          width: 110,
                          height: 110,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                  widget.character.color, Colors.white, 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: CharacterView(character: widget.character),
                          ),
                        ),
                        const Positioned(
                          right: 20,
                          top: 8,
                          child: Icon(Icons.phone_in_talk_rounded,
                              size: 44, color: Colors.green),
                        ),
                      ],
                    ),
                  )
                else if (scene is HideScene)
                  // В прятках персонаж сидит за кустом — отдельно его нет.
                  Expanded(
                    child: SceneView(
                      scene: scene,
                      character: widget.character,
                      progress: _c.speechProgress,
                      onHideTap: _c.tapHidePlace,
                    ),
                  )
                else if (scene != null) ...[
                  Expanded(
                    flex: 3,
                    child: SceneView(
                      scene: scene,
                      character: widget.character,
                      progress: _c.speechProgress,
                      onHideTap: _c.tapHidePlace,
                    ),
                  ),
                  SizedBox(height: 150, child: hero),
                ] else
                  Expanded(child: hero),
                _StatusHint(state: s, error: _c.errorText),
                const SizedBox(height: 16),
                _Controls(
                  controller: _c,
                  onRetry: _retry,
                  onCall: _pickFriend,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
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
              subtitle: const Text(
                  'Время московское. Строки [Расход] — оценка по прайсу '
                  'Яндекса, точные суммы в биллинге.'),
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
  const _Controls({
    required this.controller,
    required this.onRetry,
    required this.onCall,
  });

  final ConversationController controller;
  final VoidCallback onRetry;
  final VoidCallback onCall;

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
    final inCall = controller.friend != null;
    // Значки без слов: малыш не читает. По краям — кнопки взрослого,
    // в середине — занятия.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        IconButton.filledTonal(
          iconSize: 34,
          onPressed: paused ? controller.resume : controller.pause,
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        ),
        if (inCall)
          IconButton.filled(
            iconSize: 44,
            tooltip: 'Положить трубку',
            style: IconButton.styleFrom(backgroundColor: Colors.red),
            onPressed: controller.endCall,
            icon: const Icon(Icons.call_end_rounded),
          )
        else ...[
          IconButton.filled(
            iconSize: 40,
            tooltip: 'Угадай, кто я',
            onPressed:
                controller.canStartGame ? controller.startGuessGame : null,
            icon: const Icon(Icons.pets_rounded),
          ),
          IconButton.filled(
            iconSize: 40,
            tooltip: 'Позвонить другу',
            onPressed: controller.canCall ? onCall : null,
            icon: const Icon(Icons.call_rounded),
          ),
        ],
        IconButton.filledTonal(
          iconSize: 34,
          onPressed: controller.finish,
          icon: const Icon(Icons.stop_rounded),
        ),
      ],
    );
  }
}
