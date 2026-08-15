import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/medication.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Medikamentengabe: oben der Plan für heute zum Abhaken, darunter die
/// hinterlegten Medikamente.
class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final heute = DateTime.now();
    final heutige = state.medicationsOn(heute);
    final alle = state.medications;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Medikament'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SectionCard(
            title: 'Heute zu geben',
            icon: Icons.medication_outlined,
            child: heutige.isEmpty
                ? const EmptyHint(
                    text: 'Für heute ist nichts eingetragen.',
                  )
                : Column(
                    children: [
                      for (final m in heutige) _TagesPlan(medikament: m),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          if (alle.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.medication_liquid_outlined,
                text: 'Noch keine Medikamente hinterlegt.\n'
                    'Auch Wurmkur und Zeckenmittel lassen sich hier\n'
                    'mit Zeitraum eintragen.',
              ),
            )
          else
            SectionCard(
              title: 'Hinterlegt',
              icon: Icons.list_alt_outlined,
              child: Column(
                children: [
                  for (final m in alle)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => _openEditor(context, entry: m),
                      leading: Icon(
                        m.aktiv
                            ? Icons.medication_outlined
                            : Icons.pause_circle_outline,
                        color: m.aktiv
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      title: Text(
                        m.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_beschreibung(m)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _beschreibung(Medication m) {
    final teile = <String>[
      if (m.dosis.isNotEmpty) m.dosis,
      m.zeitenLabel,
      if (m.von != null || m.bis != null)
        '${m.von == null ? '' : 'ab ${dfDate.format(m.von!)}'}'
                '${m.von != null && m.bis != null ? ' ' : ''}'
                '${m.bis == null ? '' : 'bis ${dfDate.format(m.bis!)}'}'
            .trim(),
      if (!m.aktiv) 'pausiert',
    ];
    return teile.join(' · ');
  }
}

/// Eine Zeile pro Medikament mit einem Haken je Gabezeit.
class _TagesPlan extends StatelessWidget {
  const _TagesPlan({required this.medikament});

  final Medication medikament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final heute = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medikament.dosis.isEmpty
                ? medikament.name
                : '${medikament.name} · ${medikament.dosis}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          if (medikament.zeiten.isEmpty)
            Text(
              'ohne feste Uhrzeit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final minute in medikament.zeiten)
                  _GabeChip(
                    medikament: medikament,
                    minute: minute,
                    gegeben: state.istGegeben(medikament.id, heute, minute),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GabeChip extends StatelessWidget {
  const _GabeChip({
    required this.medikament,
    required this.minute,
    required this.gegeben,
  });

  final Medication medikament;
  final int minute;
  final bool gegeben;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final log = state.gabe(medikament.id, DateTime.now(), minute);

    return FilterChip(
      avatar: Icon(
        gegeben ? Icons.check_circle : Icons.schedule,
        size: 18,
      ),
      label: Text(
        gegeben && log != null
            ? '${Medication.zeitLabel(minute)} ✓ '
                '${dfTime.format(log.gegebenUm)}'
            : Medication.zeitLabel(minute),
      ),
      selected: gegeben,
      onSelected: (_) =>
          state.toggleGabe(medikament.id, DateTime.now(), minute),
    );
  }
}

Future<void> _openEditor(BuildContext context, {Medication? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MedicationEditor(entry: entry),
  );
}

class _MedicationEditor extends StatefulWidget {
  const _MedicationEditor({this.entry});

  final Medication? entry;

  @override
  State<_MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends State<_MedicationEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.entry?.name ?? '');
  late final TextEditingController _dosis =
      TextEditingController(text: widget.entry?.dosis ?? '');
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');

  late List<int> _zeiten = [...(widget.entry?.zeiten ?? const <int>[])];
  late DateTime? _von = widget.entry?.von;
  late DateTime? _bis = widget.entry?.bis;
  late bool _aktiv = widget.entry?.aktiv ?? true;

  @override
  void dispose() {
    _name.dispose();
    _dosis.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _addZeit() async {
    final gewaehlt = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (gewaehlt == null) return;
    final minute = gewaehlt.hour * 60 + gewaehlt.minute;
    if (_zeiten.contains(minute)) return;
    setState(() => _zeiten = [..._zeiten, minute]..sort());
  }

  Future<void> _save() async {
    final base = widget.entry ?? Medication(name: _name.text.trim());
    await context.read<AppState>().saveMedication(
          base.copyWith(
            name: _name.text.trim(),
            dosis: _dosis.text.trim(),
            zeiten: _zeiten,
            von: _von,
            clearVon: _von == null,
            bis: _bis,
            clearBis: _bis == null,
            notiz: _notiz.text.trim(),
            aktiv: _aktiv,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
              widget.entry == null
                  ? 'Neues Medikament'
                  : 'Medikament bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.entry == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Wurmkur, Metacam',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosis,
              decoration: const InputDecoration(
                labelText: 'Dosis (optional)',
                hintText: 'z. B. 1 Tablette, 0,4 ml',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gabezeiten',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final minute in _zeiten)
                  InputChip(
                    label: Text(Medication.zeitLabel(minute)),
                    onDeleted: () =>
                        setState(() => _zeiten.remove(minute)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Zeit'),
                  onPressed: _addZeit,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _dateRow(
              label: 'Ab',
              value: _von,
              onPick: (d) => setState(() => _von = d),
            ),
            _dateRow(
              label: 'Bis',
              value: _bis,
              onPick: (d) => setState(() => _bis = d),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktiv'),
              subtitle: const Text('Pausierte Medikamente stehen nicht im '
                  'Tagesplan.'),
              value: _aktiv,
              onChanged: (v) => setState(() => _aktiv = v),
            ),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: 'z. B. mit dem Futter geben',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Speichern')),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await context
                      .read<AppState>()
                      .deleteMedication(widget.entry!.id);
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

  Widget _dateRow({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickDate(context, value);
                if (picked != null) onPick(picked);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                value == null
                    ? '$label: offen'
                    : '$label: ${dfDate.format(value)}',
              ),
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Datum entfernen',
              onPressed: () => onPick(null),
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}
