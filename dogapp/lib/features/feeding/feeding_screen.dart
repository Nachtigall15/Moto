import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/feeding_entry.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

class FeedingScreen extends StatelessWidget {
  const FeedingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final totals = state.totalsOn(today);
    final heute = state.feedingsOn(today);

    // Nach Tagen gruppieren, damit die Liste eine erkennbare Struktur
    // hat statt einer endlosen Reihe von Einträgen.
    final byDay = <DateTime, List<FeedingEntry>>{};
    for (final f in state.feedings) {
      byDay.putIfAbsent(startOfDay(f.zeitpunkt), () => []).add(f);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Fütterung'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionCard(
            title: 'Heute',
            icon: Icons.today_outlined,
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Mahlzeiten',
                    value: '${heute.length}',
                    icon: Icons.restaurant_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Menge',
                    value: totals.isEmpty
                        ? '–'
                        : totals.entries
                            .map((e) =>
                                '${nfAmount.format(e.value)} ${e.key.label}')
                            .join(' · '),
                    icon: Icons.scale_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (days.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.ramen_dining_outlined,
                text: 'Noch nichts eingetragen.\n'
                    'Mit „+ Fütterung" die erste Mahlzeit erfassen.',
              ),
            ),
          for (final day in days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                isSameDay(day, today) ? 'Heute' : dfWeekday.format(day),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (final entry in byDay[day]!
                    ..sort((a, b) => b.zeitpunkt.compareTo(a.zeitpunkt)))
                    _FeedingTile(entry: entry),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedingTile extends StatelessWidget {
  const _FeedingTile({required this.entry});

  final FeedingEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => _openEditor(context, entry: entry),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
        child: Icon(
          _iconFor(entry.mahlzeit),
          size: 20,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(
        entry.futter.isEmpty ? entry.mahlzeit.label : entry.futter,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${dfTime.format(entry.zeitpunkt)} Uhr · ${entry.mahlzeit.label}'
        '${entry.notiz.isEmpty ? '' : ' · ${entry.notiz}'}',
      ),
      trailing: Text(
        entry.mengeLabel,
        style: theme.textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  static IconData _iconFor(Mahlzeit m) => switch (m) {
        Mahlzeit.fruehstueck => Icons.wb_twilight,
        Mahlzeit.hauptmahlzeit => Icons.restaurant,
        Mahlzeit.abendessen => Icons.nights_stay_outlined,
        Mahlzeit.snack => Icons.cookie_outlined,
        Mahlzeit.leckerli => Icons.pets,
      };
}

Future<void> _openEditor(BuildContext context, {FeedingEntry? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FeedingEditor(entry: entry),
  );
}

class _FeedingEditor extends StatefulWidget {
  const _FeedingEditor({this.entry});

  final FeedingEntry? entry;

  @override
  State<_FeedingEditor> createState() => _FeedingEditorState();
}

class _FeedingEditorState extends State<_FeedingEditor> {
  late final TextEditingController _futter =
      TextEditingController(text: widget.entry?.futter ?? '');
  late final TextEditingController _menge = TextEditingController(
    text: widget.entry == null ? '' : nfAmount.format(widget.entry!.menge),
  );
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');
  final FocusNode _futterFocus = FocusNode();

  late DateTime _zeitpunkt = widget.entry?.zeitpunkt ?? DateTime.now();
  late Einheit _einheit = widget.entry?.einheit ?? Einheit.gramm;
  late Mahlzeit _mahlzeit = widget.entry?.mahlzeit ?? _vorschlagMahlzeit();

  static Mahlzeit _vorschlagMahlzeit() {
    final h = DateTime.now().hour;
    if (h < 11) return Mahlzeit.fruehstueck;
    if (h < 16) return Mahlzeit.hauptmahlzeit;
    return Mahlzeit.abendessen;
  }

  @override
  void dispose() {
    _futter.dispose();
    _menge.dispose();
    _notiz.dispose();
    _futterFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final menge =
        double.tryParse(_menge.text.trim().replaceAll(',', '.')) ?? 0;

    final entry = (widget.entry ??
            FeedingEntry(
              zeitpunkt: _zeitpunkt,
              futter: '',
              menge: 0,
            ))
        .copyWith(
      zeitpunkt: _zeitpunkt,
      futter: _futter.text.trim(),
      menge: menge,
      einheit: _einheit,
      mahlzeit: _mahlzeit,
      notiz: _notiz.text.trim(),
    );

    await state.saveFeeding(entry);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final state = context.read<AppState>();
    await state.deleteFeeding(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vorschlaege = context.read<AppState>().bekannteFuttersorten;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry == null ? 'Neue Fütterung' : 'Fütterung bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final m in Mahlzeit.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _mahlzeit == m,
                    onSelected: (_) => setState(() => _mahlzeit = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Autocomplete spart Tipparbeit: die immer gleichen
            // Futtersorten müssen nur einmal geschrieben werden.
            RawAutocomplete<String>(
              textEditingController: _futter,
              focusNode: _futterFocus,
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return vorschlaege.take(6);
                return vorschlaege
                    .where((s) => s.toLowerCase().contains(q))
                    .take(6);
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
                  TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Was',
                  hintText: 'z. B. Trockenfutter, Hühnchen mit Reis',
                ),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(
                            title: Text(o),
                            onTap: () => onSelected(o),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _menge,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Wie viel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SegmentedButton<Einheit>(
                    segments: [
                      for (final e in Einheit.values)
                        ButtonSegment(value: e, label: Text(e.label)),
                    ],
                    selected: {_einheit},
                    onSelectionChanged: (s) =>
                        setState(() => _einheit = s.first),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickDateTime(context, _zeitpunkt);
                if (picked != null) setState(() => _zeitpunkt = picked);
              },
              icon: const Icon(Icons.schedule),
              label: Text('${dfDateTime.format(_zeitpunkt)} Uhr'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: 'z. B. hat nicht aufgegessen',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Speichern')),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Löschen'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
