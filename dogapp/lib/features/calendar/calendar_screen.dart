import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/appointment.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Terminkalender als Agenda: was als Nächstes ansteht, steht oben.
/// Auf dem Handy ist das brauchbarer als ein Monatsraster, in dem man
/// erst auf einen Tag tippen muss, um überhaupt etwas zu sehen.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    final verpasst = state.verpassteTermine;
    final offen = state.offeneTermine;
    final faellig = state.faelligeImpfungen;
    final erledigt = state.erledigteTermine;

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAppointmentEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Termin'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (faellig.isNotEmpty) ...[
            Card(
              color: theme.colorScheme.secondary.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vaccines_outlined,
                            size: 18, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Impfungen im Blick',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final v in faellig)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          v.istAbgelaufen
                              ? '${v.bezeichnung}: seit '
                                  '${dfDate.format(v.gueltigBis!)} überfällig'
                              : '${v.bezeichnung}: fällig am '
                                  '${dfDate.format(v.gueltigBis!)} '
                                  '(in ${v.tageBisFaellig} Tagen)',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (verpasst.isNotEmpty) ...[
            _Group(
              titel: 'Vergangen, noch offen',
              icon: Icons.error_outline,
              termine: verpasst,
            ),
            const SizedBox(height: 16),
          ],
          if (offen.isEmpty && verpasst.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.event_available_outlined,
                text: 'Keine Termine eingetragen.\n'
                    'Tierarzt, Hundeschule, Wurmkur – alles, was einen\n'
                    'festen Zeitpunkt hat, gehört hierher.',
              ),
            )
          else if (offen.isNotEmpty)
            ..._offeneGruppen(context, offen),
          if (erledigt.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                shape: const Border(),
                leading: const Icon(Icons.check_circle_outline),
                title: Text('Erledigt (${erledigt.length})'),
                children: [
                  for (final a in erledigt.take(30))
                    _AppointmentTile(entry: a),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Anstehende Termine in „Heute / Diese Woche / Später" schneiden.
  List<Widget> _offeneGruppen(
    BuildContext context,
    List<Appointment> offen,
  ) {
    final heute = startOfDay(DateTime.now());
    final wocheEnde = heute.add(const Duration(days: 7));

    final heuteListe = <Appointment>[];
    final wocheListe = <Appointment>[];
    final spaeterListe = <Appointment>[];

    for (final a in offen) {
      final tag = startOfDay(a.zeitpunkt);
      if (tag == heute) {
        heuteListe.add(a);
      } else if (tag.isBefore(wocheEnde)) {
        wocheListe.add(a);
      } else {
        spaeterListe.add(a);
      }
    }

    return [
      if (heuteListe.isNotEmpty)
        _Group(
          titel: 'Heute',
          icon: Icons.today_outlined,
          termine: heuteListe,
        ),
      if (heuteListe.isNotEmpty) const SizedBox(height: 16),
      if (wocheListe.isNotEmpty)
        _Group(
          titel: 'Diese Woche',
          icon: Icons.date_range_outlined,
          termine: wocheListe,
        ),
      if (wocheListe.isNotEmpty) const SizedBox(height: 16),
      if (spaeterListe.isNotEmpty)
        _Group(
          titel: 'Später',
          icon: Icons.event_outlined,
          termine: spaeterListe,
        ),
    ];
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.titel,
    required this.icon,
    required this.termine,
  });

  final String titel;
  final IconData icon;
  final List<Appointment> termine;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: titel,
      icon: icon,
      child: Column(
        children: [for (final a in termine) _AppointmentTile(entry: a)],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.entry});

  final Appointment entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<AppState>();
    final ueberfaellig = !entry.erledigt && entry.istVergangen;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => openAppointmentEditor(context, entry: entry),
      leading: CircleAvatar(
        backgroundColor: (ueberfaellig
                ? theme.colorScheme.error
                : theme.colorScheme.primary)
            .withValues(alpha: 0.14),
        child: Icon(
          entry.kategorie.icon,
          size: 20,
          color: ueberfaellig
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
      ),
      title: Text(
        entry.titel.isEmpty ? entry.kategorie.label : entry.titel,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: entry.erledigt ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${dfDate.format(entry.zeitpunkt)} · ${entry.zeitLabel}'
        '${entry.ort.isEmpty ? '' : ' · ${entry.ort}'}'
        '${entry.notiz.isEmpty ? '' : '\n${entry.notiz}'}',
      ),
      isThreeLine: entry.notiz.isNotEmpty,
      trailing: Checkbox(
        value: entry.erledigt,
        onChanged: (v) =>
            state.saveAppointment(entry.copyWith(erledigt: v ?? false)),
      ),
    );
  }
}

Future<void> openAppointmentEditor(
  BuildContext context, {
  Appointment? entry,
  TerminArt? vorgabe,
  String? titelVorgabe,
  DateTime? zeitVorgabe,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AppointmentEditor(
      entry: entry,
      vorgabe: vorgabe,
      titelVorgabe: titelVorgabe,
      zeitVorgabe: zeitVorgabe,
    ),
  );
}

class _AppointmentEditor extends StatefulWidget {
  const _AppointmentEditor({
    this.entry,
    this.vorgabe,
    this.titelVorgabe,
    this.zeitVorgabe,
  });

  final Appointment? entry;
  final TerminArt? vorgabe;
  final String? titelVorgabe;
  final DateTime? zeitVorgabe;

  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  late final TextEditingController _titel = TextEditingController(
    text: widget.entry?.titel ?? widget.titelVorgabe ?? '',
  );
  late final TextEditingController _ort =
      TextEditingController(text: widget.entry?.ort ?? '');
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');

  late DateTime _zeitpunkt = widget.entry?.zeitpunkt ??
      widget.zeitVorgabe ??
      _naechsteVolleStunde();
  late TerminArt _kategorie =
      widget.entry?.kategorie ?? widget.vorgabe ?? TerminArt.tierarzt;
  late int? _dauer = widget.entry?.dauerMinuten;

  static DateTime _naechsteVolleStunde() {
    final jetzt = DateTime.now();
    return DateTime(jetzt.year, jetzt.month, jetzt.day, jetzt.hour + 1);
  }

  @override
  void dispose() {
    _titel.dispose();
    _ort.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = widget.entry ??
        Appointment(zeitpunkt: _zeitpunkt, titel: _titel.text.trim());

    await context.read<AppState>().saveAppointment(
          base.copyWith(
            zeitpunkt: _zeitpunkt,
            titel: _titel.text.trim(),
            kategorie: _kategorie,
            dauerMinuten: _dauer,
            clearDauer: _dauer == null,
            ort: _ort.text.trim(),
            notiz: _notiz.text.trim(),
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
              widget.entry == null ? 'Neuer Termin' : 'Termin bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final k in TerminArt.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 16),
                    label: Text(k.label),
                    selected: _kategorie == k,
                    onSelected: (_) => setState(() => _kategorie = k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titel,
              autofocus: widget.entry == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'z. B. Jahresimpfung, Welpenstunde',
              ),
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
            Wrap(
              spacing: 8,
              children: [
                for (final option in <(String, int?)>[
                  ('ohne Dauer', null),
                  ('30 min', 30),
                  ('45 min', 45),
                  ('1 h', 60),
                  ('1,5 h', 90),
                ])
                  ChoiceChip(
                    label: Text(option.$1),
                    selected: _dauer == option.$2,
                    onSelected: (_) => setState(() => _dauer = option.$2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ort,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ort (optional)',
                hintText: 'z. B. Praxis Dr. Müller',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: 'z. B. nüchtern bleiben, Impfpass mitnehmen',
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
                      .deleteAppointment(widget.entry!.id);
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
