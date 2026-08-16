import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/sleep_entry.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Läuft gerade eine Schlafphase, soll die Dauer mitlaufen statt
    // beim Öffnen einzufrieren.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.now();
    final running = state.laufenderSchlaf;
    final heute = state.sleepsOn(today);

    final byDay = <DateTime, List<SleepEntry>>{};
    for (final s in state.sleeps) {
      byDay.putIfAbsent(startOfDay(s.start), () => []).add(s);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            running == null ? state.startSleep() : state.stopSleep(),
        backgroundColor:
            running == null ? null : Theme.of(context).colorScheme.secondary,
        icon: Icon(running == null ? Icons.bedtime : Icons.stop),
        label: Text(running == null ? 'Schläft jetzt' : 'Aufgewacht'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (running != null) ...[
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.bedtime),
                title: Text(
                  'Schläft seit ${dfTime.format(running.start)} Uhr',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('bisher ${running.dauerLabel}'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'Heute',
            icon: Icons.today_outlined,
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Schlafphasen',
                    value: '${heute.length}',
                    icon: Icons.bedtime_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Gesamt',
                    value: heute.isEmpty
                        ? '–'
                        : formatDuration(state.sleepTotalOn(today)),
                    icon: Icons.timelapse_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (days.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.bedtime_outlined,
                text: 'Noch keine Schlafzeiten erfasst.\n'
                    'Mit „Schläft jetzt" startest du eine Phase –\n'
                    'oder trägst sie über das Stift-Symbol nachträglich ein.',
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
                  for (final entry
                      in byDay[day]!
                        ..sort((a, b) => b.start.compareTo(a.start)))
                    ListTile(
                      onTap: () => _openEditor(context, entry: entry),
                      leading: Icon(
                        entry.laeuft
                            ? Icons.hourglass_bottom
                            : Icons.bedtime_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        entry.laeuft
                            ? 'seit ${dfTime.format(entry.start)} Uhr'
                            : '${dfTime.format(entry.start)} – '
                                '${dfTime.format(entry.ende!)} Uhr',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: entry.notiz.isEmpty && entry.ort.isEmpty
                          ? null
                          : Text([entry.ort, entry.notiz]
                              .where((s) => s.isNotEmpty)
                              .join(' · ')),
                      trailing: Text(
                        entry.dauerLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Schlafphase nachtragen'),
          ),
          const MehrLaden(bereich: Bereich.schlaf),
        ],
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context, {SleepEntry? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SleepEditor(entry: entry),
  );
}

class _SleepEditor extends StatefulWidget {
  const _SleepEditor({this.entry});

  final SleepEntry? entry;

  @override
  State<_SleepEditor> createState() => _SleepEditorState();
}

class _SleepEditorState extends State<_SleepEditor> {
  late final TextEditingController _ort =
      TextEditingController(text: widget.entry?.ort ?? '');
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');

  late DateTime _start =
      widget.entry?.start ?? DateTime.now().subtract(const Duration(hours: 1));
  late DateTime? _ende = widget.entry?.ende ?? DateTime.now();

  @override
  void dispose() {
    _ort.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final base = widget.entry ?? SleepEntry(start: _start);
    await state.saveSleep(
      base.copyWith(
        start: _start,
        ende: _ende,
        clearEnde: _ende == null,
        ort: _ort.text.trim(),
        notiz: _notiz.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ungueltig = _ende != null && !_ende!.isAfter(_start);

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
              widget.entry == null ? 'Schlaf nachtragen' : 'Schlaf bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickDateTime(context, _start);
                if (picked != null) setState(() => _start = picked);
              },
              icon: const Icon(Icons.bedtime_outlined),
              label: Text('Von: ${dfDateTime.format(_start)} Uhr'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked =
                    await pickDateTime(context, _ende ?? DateTime.now());
                if (picked != null) setState(() => _ende = picked);
              },
              icon: const Icon(Icons.wb_sunny_outlined),
              label: Text(
                _ende == null
                    ? 'Bis: läuft noch'
                    : 'Bis: ${dfDateTime.format(_ende!)} Uhr',
              ),
            ),
            if (_ende != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _ende = null),
                  child: const Text('Ende offen lassen (schläft noch)'),
                ),
              ),
            if (ungueltig)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Das Ende muss nach dem Beginn liegen.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              _ende == null
                  ? 'Dauer läuft'
                  : 'Dauer: ${formatDuration(_ende!.difference(_start))}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ort,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ort (optional)',
                hintText: 'z. B. Box, Sofa, Garten',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: 'z. B. unruhig geschlafen',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: ungueltig ? null : _save,
              child: const Text('Speichern'),
            ),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await context.read<AppState>().deleteSleep(widget.entry!.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
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
