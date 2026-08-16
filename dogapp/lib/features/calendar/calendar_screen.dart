import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/appointment.dart';
import '../../models/medication.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Wie weit die geplanten Medikamentengaben in die Zukunft
/// mitgeschrieben werden. Weiter voraus wäre die Liste nur noch eine
/// endlose Wiederholung derselben Zeilen.
const int _gabenVorschauTage = 7;

/// Terminkalender als Agenda: was als Nächstes ansteht, steht oben.
/// Auf dem Handy ist das brauchbarer als ein Monatsraster, in dem man
/// erst auf einen Tag tippen muss, um überhaupt etwas zu sehen.
///
/// Termine und Medikamentengaben stehen gemeinsam in der Tagesliste,
/// nach Uhrzeit sortiert – der Tag hat schließlich nur einen Ablauf.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    final verpasst = state.verpassteTermine;
    final faellig = state.faelligeImpfungen;
    final erledigt = state.erledigteTermine;
    final gruppen = _baueGruppen(state);
    final leer = gruppen.every((g) => g.eintraege.isEmpty) && verpasst.isEmpty;

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
            SectionCard(
              title: 'Vergangen, noch offen',
              icon: Icons.error_outline,
              child: Column(
                children: [
                  for (final a in verpasst) _AppointmentTile(entry: a),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (leer)
            const Card(
              child: EmptyHint(
                icon: Icons.event_available_outlined,
                text: 'Nichts eingetragen.\n'
                    'Tierarzt, Hundeschule, Wurmkur – alles, was einen\n'
                    'festen Zeitpunkt hat, gehört hierher.\n'
                    'Medikamentengaben erscheinen hier automatisch.',
              ),
            )
          else
            for (final gruppe in gruppen)
              if (gruppe.eintraege.isNotEmpty) ...[
                SectionCard(
                  title: gruppe.titel,
                  icon: gruppe.icon,
                  child: Column(
                    children: [
                      for (final eintrag in gruppe.eintraege)
                        switch (eintrag) {
                          _TerminEintrag(:final termin) =>
                            _AppointmentTile(entry: termin),
                          _GabeEintrag(:final gabe) => _DoseTile(dose: gabe),
                        },
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
          const MehrLaden(bereich: Bereich.termine),
          const SizedBox(height: 16),
          if (erledigt.isNotEmpty) ...[
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

  /// Termine und Gaben zu „Heute / Diese Woche / Später" bündeln.
  ///
  /// Gaben gibt es nur für den Vorschauzeitraum; Termine dagegen
  /// vollständig, damit der Tierarzttermin in drei Monaten nicht
  /// unter den Tisch fällt.
  List<_Gruppe> _baueGruppen(AppState state) {
    final heute = startOfDay(DateTime.now());
    final wocheEnde = heute.add(const Duration(days: 7));

    final eintraege = <_Eintrag>[
      for (final a in state.offeneTermine) _TerminEintrag(a),
      for (var offset = 0; offset < _gabenVorschauTage; offset++)
        for (final d in state.dosesOn(heute.add(Duration(days: offset))))
          _GabeEintrag(d),
    ]..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));

    final gruppen = [
      _Gruppe('Heute', Icons.today_outlined),
      _Gruppe('Diese Woche', Icons.date_range_outlined),
      _Gruppe('Später', Icons.event_outlined),
    ];

    for (final eintrag in eintraege) {
      final tag = startOfDay(eintrag.zeitpunkt);
      if (tag == heute) {
        gruppen[0].eintraege.add(eintrag);
      } else if (tag.isBefore(wocheEnde)) {
        gruppen[1].eintraege.add(eintrag);
      } else {
        gruppen[2].eintraege.add(eintrag);
      }
    }
    return gruppen;
  }
}

class _Gruppe {
  _Gruppe(this.titel, this.icon);

  final String titel;
  final IconData icon;
  final List<_Eintrag> eintraege = [];
}

sealed class _Eintrag {
  DateTime get zeitpunkt;
}

class _TerminEintrag extends _Eintrag {
  _TerminEintrag(this.termin);

  final Appointment termin;

  @override
  DateTime get zeitpunkt => termin.zeitpunkt;
}

class _GabeEintrag extends _Eintrag {
  _GabeEintrag(this.gabe);

  final MedicationDose gabe;

  @override
  DateTime get zeitpunkt => gabe.zeitpunkt;
}

/// Eine geplante oder erledigte Medikamentengabe im Kalender.
class _DoseTile extends StatelessWidget {
  const _DoseTile({required this.dose});

  final MedicationDose dose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.read<AppState>();
    final heute = startOfDay(DateTime.now());
    final zukunft = dose.tag.isAfter(heute);
    final ueberfaellig =
        !dose.gegeben && dose.zeitpunkt.isBefore(DateTime.now());

    final farbe = dose.gegeben
        ? theme.colorScheme.primary
        : (ueberfaellig
            ? theme.colorScheme.secondary
            : theme.colorScheme.onSurfaceVariant);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: farbe.withValues(alpha: 0.14),
        child: Icon(Icons.medication_outlined, size: 20, color: farbe),
      ),
      title: Text(
        dose.medikament.dosis.isEmpty
            ? dose.medikament.name
            : '${dose.medikament.name} · ${dose.medikament.dosis}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: dose.gegeben ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(_untertitel()),
      trailing: zukunft
          // Eine Gabe von morgen abzuhaken, ergibt keinen Sinn – der
          // Haken soll dokumentieren, was passiert ist.
          ? Icon(Icons.schedule, color: theme.colorScheme.outline)
          : Checkbox(
              value: dose.gegeben,
              onChanged: (_) => state.toggleGabe(
                dose.medikament.id,
                dose.tag,
                dose.minute,
              ),
            ),
    );
  }

  String _untertitel() {
    final teile = <String>['${dose.zeitLabel} Uhr'];
    if (dose.nachgetragen) teile.add('nachgetragen');
    if (dose.gegeben) {
      teile.add('gegeben ${dfTime.format(dose.log!.gegebenUm)} Uhr');
    }
    return teile.join(' · ');
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
