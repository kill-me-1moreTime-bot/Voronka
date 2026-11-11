import 'package:flutter/material.dart';

import '../characters.dart';
import '../child_profile.dart';
import '../config.dart';
import 'character_view.dart';
import 'parent_gate.dart';
import 'parent_settings_screen.dart';
import 'talk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ChildProfile _child = const ChildProfile();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Настройки подключения читаются здесь же, чтобы плашка
    // «не заданы» не мелькала, пока они грузятся.
    Future.wait([ChildProfile.load(), AppConfig.load()]).then((r) {
      if (!mounted) return;
      setState(() {
        _child = r[0] as ChildProfile;
        _loaded = true;
      });
    });
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<ChildProfile>(
      MaterialPageRoute(builder: (_) => ParentSettingsScreen(initial: _child)),
    );
    if (updated != null) setState(() => _child = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('С кем поговорим?',
                        style: theme.textTheme.headlineMedium),
                  ),
                  ParentGate(onUnlocked: _openSettings, deviceAuth: true),
                ],
              ),
            ),
            if (_loaded && !AppConfig.isConfigured)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Не заданы адрес и ключ Yandex AI Studio. '
                        'Нажмите значок настроек справа вверху (вход по '
                        'отпечатку пальца) и заполните раздел «Подключение».'),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final c in characters)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _CharacterCard(
                        character: c,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TalkScreen(character: c, child: _child),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, required this.onTap});

  final CharacterProfile character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.lerp(character.color, Colors.white, 0.75),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: SizedBox(
          height: 180,
          child: Row(
            children: [
              SizedBox(
                width: 170,
                child: CharacterView(character: character),
              ),
              Expanded(
                child: Text(
                  character.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
