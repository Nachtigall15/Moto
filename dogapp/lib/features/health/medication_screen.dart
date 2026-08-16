import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/medication.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Medikamentengabe: oben der Plan für den gewählten Tag zum Abhaken,
/// darunter die hinterlegten Medikamente.
///
/// Der Tag lässt sich zurückblättern, weil das Abhaken im Alltag
/// regelmäßig hinterherhinkt – wer abends merkt, dass die Mittagsgabe
/// nicht quittiert ist, muss sie nachtragen können, ohne dass die
/// Uhrzeit verfälscht wird.
class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  late DateTime _tag = startOfDay(DateTime.now());

  bool get _istHeute => isSameDay(_tag, DateTime.now());

  void _blaettern(int tage) => setState(
        () => _tag = _tag.add(Duration(days: tage)),
      );

  String get _tagLabel {
    final heute = startOfDay(DateTime.now());
    final abstand = _tag.difference(heute).inDays;
    return switch (abstand) {
      0 => 'Heute',
      -1 => 'Gestern',
      1 => 'Morgen',
      _ => dfWeekday.format(_tag),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final doses = state.dosesOn(_tag);
    final alle = state.medications;
    final zukunft = _tag.isAfter(startOfDay(DateTime.now()));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Eindeutige Kennung: Alle Reiter liegen gleichzeitig im
        // Baum, ohne sie stolpert die Übergangsanimation über
        // mehrere gleich benannte Knöpfe.
        heroTag: 'fab-medikament',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Medikament'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          SectionCard(
            title: 'Zu geben',
            icon: Icons.medication_outlined,
            trailing: _istHeute
                ? null
                : TextButton(
                    onPressed: () =>
                        setState(() => _tag = startOfDay(DateTime.now())),
                    child: const Text('Heute'),
                  ),
            child: Column(
              children: [
                _TagWechsler(
                  label: _tagLabel,
                  datum: dfDate.format(_tag),
                  onZurueck: () => _blaettern(-1),
                  onVor: () => _blaettern(1),
                ),
                const SizedBox(height: 8),
                if (doses.isEmpty)
                  EmptyHint(
                    text: alle.isEmpty
                        ? 'Noch keine Medikamente hinterlegt.'
                        : 'Für diesen Tag ist nichts eingetragen.',
                  )
                else
                  for (final dose in doses)
                    _DoseRow(dose: dose, zukunft: zukunft),
                if (alle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: zukunft
                        ? null
                        : () => _openNachtragen(context, _tag),
                    icon: const Icon(Icons.more_time),
                    label: const Text('Gabe nachtragen'),
                  ),
                ],
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
          const MehrLaden(bereich: Bereich.gaben),
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

class _TagWechsler extends StatelessWidget {
  const _TagWechsler({
    required this.label,
    required this.datum,
    required this.onZurueck,
    required this.onVor,
  });

  final String label;
  final String datum;
  final VoidCallback onZurueck;
  final VoidCallback onVor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'Tag zurück',
          onPressed: onZurueck,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                datum,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Tag vor',
          onPressed: onVor,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.zukunft});

  final MedicationDose dose;
  final bool zukunft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<AppState>();

    final zusatz = <String>[
      if (dose.medikament.dosis.isNotEmpty) dose.medikament.dosis,
      if (dose.nachgetragen) 'nachgetragen',
      if (dose.gegeben) 'gegeben ${dfTime.format(dose.log!.gegebenUm)} Uhr',
    ];

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: dose.gegeben,
      onChanged: zukunft
          ? null
          : (_) => state.toggleGabe(
                dose.medikament.id,
                dose.tag,
                dose.minute,
              ),
      secondary: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dose.zeitLabel,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'Uhr',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      title: Text(
        dose.medikament.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: zusatz.isEmpty ? null : Text(zusatz.join(' · ')),
    );
  }
}

/// Gabe zu einer freien Uhrzeit eintragen – für Extra-Gaben und für
/// Medikamente, die gar keine feste Zeit haben.
Future<void> _openNachtragen(BuildContext context, DateTime tag) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NachtragenSheet(tag: tag),
  );
}

class _NachtragenSheet extends StatefulWidget {
  const _NachtragenSheet({required this.tag});

  final DateTime tag;

  @override
  State<_NachtragenSheet> createState() => _NachtragenSheetState();
}

class _NachtragenSheetState extends State<_NachtragenSheet> {
  String? _medikamentId;
  late TimeOfDay _zeit = TimeOfDay.fromDateTime(DateTime.now());

  @override
  void initState() {
    super.initState();
    final meds = context.read<AppState>().medications;
    if (meds.length == 1) _medikamentId = meds.first.id;
  }

  Future<void> _save() async {
    final id = _medikamentId;
    if (id == null) return;
    await context.read<AppState>().toggleGabe(
          id,
          widget.tag,
          _zeit.hour * 60 + _zeit.minute,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final meds = state.medications;
    final schonEingetragen = _medikamentId != null &&
        state.istGegeben(
          _medikamentId!,
          widget.tag,
          _zeit.hour * 60 + _zeit.minute,
        );

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
              'Gabe nachtragen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              dfWeekday.format(widget.tag),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in meds)
                  ChoiceChip(
                    label: Text(m.name),
                    selected: _medikamentId == m.id,
                    onSelected: (_) => setState(() => _medikamentId = m.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final gewaehlt = await pickTime(context, _zeit);
                if (gewaehlt != null) setState(() => _zeit = gewaehlt);
              },
              icon: const Icon(Icons.schedule),
              label: Text(
                'Uhrzeit: '
                '${_zeit.hour.toString().padLeft(2, '0')}:'
                '${_zeit.minute.toString().padLeft(2, '0')} Uhr',
              ),
            ),
            if (schonEingetragen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Für diese Uhrzeit ist bereits eine Gabe eingetragen.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed:
                  _medikamentId == null || schonEingetragen ? null : _save,
              child: const Text('Als gegeben eintragen'),
            ),
          ],
        ),
      ),
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
    final gewaehlt = await pickTime(
      context,
      const TimeOfDay(hour: 8, minute: 0),
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
                    label: Text('${Medication.zeitLabel(minute)} Uhr'),
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
