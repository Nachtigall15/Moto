import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/appointment.dart';
import '../../models/vaccination.dart';
import '../../state/app_state.dart';
import '../calendar/calendar_screen.dart';
import '../common/ui.dart';

/// Impfungen mit Status: was ist gültig, was läuft ab, was ist fällig.
class VaccinationScreen extends StatelessWidget {
  const VaccinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final aktuell = state.aktuelleImpfungen;
    final alle = state.vaccinations;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Eindeutige Kennung: Alle Reiter liegen gleichzeitig im
        // Baum, ohne sie stolpert die Übergangsanimation über
        // mehrere gleich benannte Knöpfe.
        heroTag: 'fab-impfung',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Impfung'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (alle.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.vaccines_outlined,
                text: 'Noch keine Impfung eingetragen.\n'
                    'Die Angaben stehen im Impfausweis –\n'
                    'Datum, Impfstoff und Chargennummer.',
              ),
            )
          else ...[
            SectionCard(
              title: 'Status',
              icon: Icons.verified_outlined,
              child: Column(
                children: [
                  for (final v in aktuell) _StatusZeile(impfung: v),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Verlauf',
              icon: Icons.history,
              trailing: Text(
                alle.length == 1 ? '1 Eintrag' : '${alle.length} Einträge',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (bezeichnung, eintraege) in state.impfungenNachArt)
                    _Impfgruppe(bezeichnung: bezeichnung, eintraege: eintraege),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Alle Auffrischungen einer Impfung untereinander.
///
/// Vorher stand alles in einer langen Liste durcheinander. Beim
/// Tierarzt lautet die Frage aber „wann war die letzte Tollwut?" –
/// dafür muss die Geschichte einer Impfung beieinanderstehen.
class _Impfgruppe extends StatelessWidget {
  const _Impfgruppe({required this.bezeichnung, required this.eintraege});

  final String bezeichnung;
  final List<Vaccination> eintraege;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bezeichnung,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (eintraege.length > 1)
                  Text(
                    '${eintraege.length}×',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          for (final v in eintraege)
            InkWell(
              onTap: () => _openEditor(context, entry: v),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        dfDate.format(v.datum),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _zusatz(v).isEmpty ? '–' : _zusatz(v),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _zusatz(Vaccination v) {
    final teile = <String>[
      if (v.gueltigBis != null) 'gültig bis ${dfDate.format(v.gueltigBis!)}',
      if (v.impfstoff.isNotEmpty) v.impfstoff,
      if (v.chargennummer.isNotEmpty) 'Charge ${v.chargennummer}',
      if (v.tierarzt.isNotEmpty) v.tierarzt,
    ];
    return teile.join(' · ');
  }
}

class _StatusZeile extends StatelessWidget {
  const _StatusZeile({required this.impfung});

  final Vaccination impfung;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tage = impfung.tageBisFaellig;

    final (Color farbe, IconData icon, String text) = switch (tage) {
      null => (
          theme.colorScheme.outline,
          Icons.help_outline,
          'kein Ablaufdatum hinterlegt',
        ),
      final t when t < 0 => (
          theme.colorScheme.error,
          Icons.error_outline,
          'seit ${dfDate.format(impfung.gueltigBis!)} überfällig',
        ),
      final t when t <= 56 => (
          theme.colorScheme.secondary,
          Icons.warning_amber_outlined,
          'fällig am ${dfDate.format(impfung.gueltigBis!)} (in $t Tagen)',
        ),
      _ => (
          theme.colorScheme.primary,
          Icons.check_circle_outline,
          'gültig bis ${dfDate.format(impfung.gueltigBis!)}',
        ),
    };

    final faellig = tage != null && tage <= 56;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: farbe),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  impfung.bezeichnung,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(color: farbe),
                ),
              ],
            ),
          ),
          if (faellig)
            TextButton(
              // Direkt aus der Warnung heraus einen Tierarzttermin
              // anlegen – das ist der Schritt, der sonst untergeht.
              onPressed: () => openAppointmentEditor(
                context,
                vorgabe: TerminArt.impfung,
                titelVorgabe: 'Impfung: ${impfung.bezeichnung}',
                zeitVorgabe: impfung.gueltigBis,
              ),
              child: const Text('Termin'),
            ),
        ],
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context, {Vaccination? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _VaccinationEditor(entry: entry),
  );
}

class _VaccinationEditor extends StatefulWidget {
  const _VaccinationEditor({this.entry});

  final Vaccination? entry;

  @override
  State<_VaccinationEditor> createState() => _VaccinationEditorState();
}

class _VaccinationEditorState extends State<_VaccinationEditor> {
  late final TextEditingController _bezeichnung =
      TextEditingController(text: widget.entry?.bezeichnung ?? '');
  late final TextEditingController _impfstoff =
      TextEditingController(text: widget.entry?.impfstoff ?? '');
  late final TextEditingController _charge =
      TextEditingController(text: widget.entry?.chargennummer ?? '');
  late final TextEditingController _tierarzt = TextEditingController(
    text: widget.entry?.tierarzt ?? '',
  );
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');

  late DateTime _datum = widget.entry?.datum ?? DateTime.now();
  late DateTime? _gueltigBis = widget.entry?.gueltigBis;

  @override
  void initState() {
    super.initState();
    // Beim neuen Eintrag steht die Praxis aus dem Ausweis schon drin.
    if (widget.entry == null) {
      final profil = context.read<AppState>().profile;
      final praxis = profil.tierarztPraxis.isNotEmpty
          ? profil.tierarztPraxis
          : profil.tierarztName;
      _tierarzt.text = praxis;
    }
  }

  @override
  void dispose() {
    _bezeichnung.dispose();
    _impfstoff.dispose();
    _charge.dispose();
    _tierarzt.dispose();
    _notiz.dispose();
    super.dispose();
  }

  /// Bezeichnung wählen und daraus gleich das übliche Ablaufdatum
  /// vorschlagen – änderbar, denn maßgeblich ist der Impfausweis.
  void _waehleStandard(String bezeichnung, int monate) {
    setState(() {
      _bezeichnung.text = bezeichnung;
      _gueltigBis = DateTime(
        _datum.year + (monate ~/ 12),
        _datum.month + (monate % 12),
        _datum.day,
      );
    });
  }

  Future<void> _save() async {
    final base = widget.entry ??
        Vaccination(bezeichnung: _bezeichnung.text.trim(), datum: _datum);

    await context.read<AppState>().saveVaccination(
          base.copyWith(
            bezeichnung: _bezeichnung.text.trim(),
            datum: _datum,
            gueltigBis: _gueltigBis,
            clearGueltigBis: _gueltigBis == null,
            impfstoff: _impfstoff.text.trim(),
            chargennummer: _charge.text.trim(),
            tierarzt: _tierarzt.text.trim(),
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
              widget.entry == null ? 'Neue Impfung' : 'Impfung bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final standard in Vaccination.standards)
                  ActionChip(
                    label: Text(standard.$1),
                    onPressed: () => _waehleStandard(standard.$1, standard.$2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bezeichnung,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Bezeichnung'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickDate(context, _datum);
                if (picked != null) setState(() => _datum = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Geimpft am: ${dfDate.format(_datum)}'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await pickDate(context, _gueltigBis);
                      if (picked != null) {
                        setState(() => _gueltigBis = picked);
                      }
                    },
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: Text(
                      _gueltigBis == null
                          ? 'Gültig bis: offen'
                          : 'Gültig bis: ${dfDate.format(_gueltigBis!)}',
                    ),
                  ),
                ),
                if (_gueltigBis != null)
                  IconButton(
                    tooltip: 'Datum entfernen',
                    onPressed: () => setState(() => _gueltigBis = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _impfstoff,
              decoration: const InputDecoration(
                labelText: 'Impfstoff (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _charge,
              decoration: const InputDecoration(
                labelText: 'Chargennummer (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tierarzt,
              decoration: const InputDecoration(
                labelText: 'Tierarzt / Praxis',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
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
                      .deleteVaccination(widget.entry!.id);
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
