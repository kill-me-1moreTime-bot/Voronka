import 'package:flutter/material.dart';

import '../child_memory.dart';
import '../child_profile.dart';
import '../config.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key, required this.initial});

  final ChildProfile initial;

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  late ChildProfile _p = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late final _notes = TextEditingController(text: widget.initial.notes);
  VoiceModel _model = AppConfig.model;
  final _url = TextEditingController();
  final _key = TextEditingController();
  final _folder = TextEditingController();
  String _scheme = AppConfig.authScheme;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    AppConfig.stored().then((v) {
      if (!mounted) return;
      setState(() {
        _url.text = v['url']!;
        _key.text = v['key']!;
        _folder.text = v['folder']!;
        if (AppConfig.schemes.contains(v['scheme'])) _scheme = v['scheme']!;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _url.dispose();
    _key.dispose();
    _folder.dispose();
    super.dispose();
  }

  String? get _urlError {
    final u = _url.text.trim();
    if (u.isEmpty || u.startsWith('wss://')) return null;
    return 'Адрес должен начинаться с wss://';
  }

  Future<void> _save() async {
    if (_urlError != null) return;
    var notes = _notes.text.trim();
    if (notes.length > ChildProfile.maxNotes) {
      notes = notes.substring(0, ChildProfile.maxNotes);
    }
    final p = _p.copyWith(name: _name.text.trim(), notes: notes);
    await p.save();
    // Новая модель — новая попытка: может, она умеет запоминать.
    if (_model != AppConfig.model) await ChildMemory.setToolsBroken(false);
    await AppConfig.save(
      url: _url.text,
      key: _key.text,
      scheme: _scheme,
      folder: _folder.text,
      voiceModel: _model,
    );
    if (mounted) Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Для родителей'),
        // Сохранить можно и сверху: внизу кнопку бывает не видно
        // за панелью Android, а до неё ещё листать.
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Сохранить'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // SafeArea снизу: экран рисуется до края, и без неё кнопку
      // «Сохранить» закрывает панель «Назад».
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Как зовут ребёнка (необязательно)',
                helperText:
                    'Хранится только на этом телефоне и уходит в промпт.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              maxLength: ChildProfile.maxNotes,
              decoration: const InputDecoration(
                labelText: 'О ребёнке (необязательно)',
                hintText: 'Любит динозавров и машинки. Кота зовут Барсик. '
                    'Ходит в садик, лучший друг — Миша.',
                helperText: 'Персонаж будет говорить о знакомом. '
                    'Хранится только на этом телефоне.',
                helperMaxLines: 2,
                alignLabelWithHint: true,
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
            const SizedBox(height: 24),
            Text('Скорость речи персонажа', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in ChildProfile.speechRates.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _p.speechRate == e.key,
                    onSelected: (_) =>
                        setState(() => _p = _p.copyWith(speechRate: e.key)),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            const _MemorySection(),
            const SizedBox(height: 32),
            Text('Подключение к Yandex AI Studio', style: t.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Нужны два значения из Yandex Cloud: идентификатор каталога '
              '(b1g…) и API-ключ сервисного аккаунта с ролью ai.models.user. '
              'Хранятся только на этом телефоне.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _folder,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Идентификатор каталога',
                hintText: 'b1g…',
                // Не запрещаем, только подсказываем: формат может смениться.
                helperText: _folder.text.trim().isEmpty ||
                        AppConfig.looksLikeFolder(_folder.text)
                    ? null
                    : 'Не похоже на каталог: обычно b1g и ещё 17 букв и цифр. '
                        'Его видно в адресе страницы AI Studio после folders/.',
                helperMaxLines: 3,
                helperStyle:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API-ключ',
                suffixIcon: IconButton(
                  tooltip: _showKey ? 'Скрыть' : 'Показать',
                  icon: Icon(_showKey
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Модель:', style: t.bodyMedium),
                for (final m in VoiceModel.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _model == m,
                    onSelected: (_) => setState(() => _model = m),
                  ),
              ],
            ),
            Text(
              _model == VoiceModel.live
                  ? 'Живые голоса: быстрее и естественнее.'
                  : 'Прежняя модель: если с новой что-то не работает.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Дополнительно', style: t.bodyMedium),
              initiallyExpanded: _url.text.isNotEmpty || _scheme != 'Api-Key',
              children: [
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Адрес (wss://…), необязательно',
                    helperText: _folder.text.trim().isEmpty
                        ? 'Пусто — адрес соберётся из каталога.'
                        : 'Пусто — ${AppConfig.defaultUrlFor(_folder.text.trim(), _model)}',
                    helperMaxLines: 4,
                    errorText: _urlError,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Авторизация:', style: t.bodyMedium),
                    for (final sc in AppConfig.schemes)
                      ChoiceChip(
                        label: Text(sc),
                        selected: _scheme == sc,
                        onSelected: (_) => setState(() => _scheme = sc),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}

/// «Что запомнил персонаж»: выключатель, список с удалением, «Стереть всё».
/// Меняется сразу, без кнопки «Сохранить».
class _MemorySection extends StatefulWidget {
  const _MemorySection();

  @override
  State<_MemorySection> createState() => _MemorySectionState();
}

class _MemorySectionState extends State<_MemorySection> {
  Future<void> _forgetAll() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Стереть всё, что запомнил персонаж?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Стереть'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ChildMemory.forgetAll();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final facts = ChildMemory.facts.reversed.toList(); // новые сверху
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Персонаж запоминает о малыше', style: t.titleMedium),
          subtitle: const Text(
            'Любимое, имена питомцев и друзей, увлечения. Хранится только '
            'на этом телефоне, в разговоре уходит Яндексу вместе с промптом. '
            'Адрес, садик, телефон и здоровье не запоминаются.',
          ),
          value: ChildMemory.enabled,
          onChanged: (on) async {
            await ChildMemory.setEnabled(on);
            if (on) await ChildMemory.setToolsBroken(false);
            setState(() {});
          },
        ),
        if (ChildMemory.enabled && ChildMemory.toolsBroken)
          Text(
            'Выбранная модель не умеет запоминать, память выключилась сама. '
            'Выключите и включите переключатель, чтобы попробовать снова.',
            style: t.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        if (facts.isEmpty)
          Text('Пока ничего не запомнил.', style: t.bodyMedium)
        else ...[
          Text('Что запомнил персонаж', style: t.titleSmall),
          for (final f in facts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f),
              trailing: IconButton(
                tooltip: 'Забыть',
                icon: const Icon(Icons.close_rounded),
                onPressed: () async {
                  await ChildMemory.forget(f);
                  setState(() {});
                },
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _forgetAll,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Стереть всё'),
            ),
          ),
        ],
      ],
    );
  }
}
