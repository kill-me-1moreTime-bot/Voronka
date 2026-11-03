import 'package:flutter/material.dart';

import '../child_profile.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key, required this.initial});

  final ChildProfile initial;

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  late ChildProfile _p = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = _p.copyWith(name: _name.text.trim());
    await p.save();
    if (mounted) Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Для родителей')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Как зовут ребёнка (необязательно)',
              helperText: 'Хранится только на этом телефоне и уходит в промпт.',
            ),
          ),
          const SizedBox(height: 24),
          Text('Возраст', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final age in [3, 4, 5])
                ChoiceChip(
                  label: Text('$age года'.replaceFirst('5 года', '5 лет')),
                  selected: _p.ageYears == age,
                  onSelected: (_) =>
                      setState(() => _p = _p.copyWith(ageYears: age)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Длительность разговора', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in [5, 10, 15, 20])
                ChoiceChip(
                  label: Text('$m мин'),
                  selected: _p.sessionMinutes == m,
                  onSelected: (_) =>
                      setState(() => _p = _p.copyWith(sessionMinutes: m)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ВОЗ советует детям 3–5 лет не больше часа экрана в день, '
            'вместе со взрослым. Персонаж сам попрощается по таймеру.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    );
  }
}
