import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../models/feeding_entry.dart';
import '../../state/app_state.dart';
import '../../state/bootstrap.dart';
import '../common/dog_photo.dart';
import '../common/ui.dart';

/// Startseite: der Blick, den jemand braucht, der gerade zur Tür
/// reinkommt – hat er gefressen, schläft er, sind Medikamente fällig,
/// steht ein Termin an.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpen});

  /// Sprung in einen Haupt-Tab, optional direkt auf einen Unter-Reiter.
  final void Function(int index, {int? unterreiter}) onOpen;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final today = DateTime.now();

    final profil = state.profile;
    final heuteFutter = state.feedingsOn(today);
    final letzteFuetterung =
        state.feedings.isEmpty ? null : state.feedings.first;
    final schlaf = state.laufenderSchlaf;
    final gewicht = state.letztesGewicht;
    final totals = state.totalsOn(today);
    final offeneGaben = state.offeneGabenHeute();
    final naechsterTermin = state.naechsterTermin;
    final verpasst = state.verpassteTermine;
    final faelligeImpfungen = state.faelligeImpfungen;

    return Scaffold(
      appBar: AppBar(
        title: Text(profil.name.isEmpty ? 'Übersicht' : profil.name),
        actions: [
          IconButton(
            tooltip: 'Heimtierausweis',
            onPressed: () => openProfile(context),
            icon: const Icon(Icons.badge_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Greeting(state: state),
          const SizedBox(height: 16),
          if (offeneGaben > 0 ||
              verpasst.isNotEmpty ||
              faelligeImpfungen.isNotEmpty) ...[
            _Hinweise(
              offeneGaben: offeneGaben,
              verpasste: verpasst.length,
              impfungen: faelligeImpfungen.length,
              onOpen: onOpen,
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'Heute',
            icon: Icons.today_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Mahlzeiten',
                        value: '${heuteFutter.length}',
                        hint: totals.isEmpty
                            ? 'noch nichts'
                            : totals.entries
                                .map((e) =>
                                    '${nfAmount.format(e.value)} '
                                    '${e.key.label}')
                                .join(' · '),
                        icon: Icons.restaurant_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Schlaf',
                        value: schlaf != null
                            ? 'läuft'
                            : (state.sleepsOn(today).isEmpty
                                ? '–'
                                : formatDuration(state.sleepTotalOn(today))),
                        hint: schlaf != null
                            ? 'seit ${dfTime.format(schlaf.start)} Uhr'
                            : null,
                        icon: Icons.bedtime_outlined,
                        color:
                            schlaf != null ? theme.colorScheme.secondary : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onOpen(Tabs.alltag, unterreiter: 0),
                        icon: const Icon(Icons.add),
                        label: const Text('Fütterung'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => schlaf == null
                            ? state.startSleep()
                            : state.stopSleep(),
                        icon: Icon(schlaf == null ? Icons.bedtime : Icons.stop),
                        label: Text(schlaf == null ? 'Schläft' : 'Wach'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Nächster Termin',
            icon: Icons.event_outlined,
            trailing: TextButton(
              onPressed: () => onOpen(Tabs.kalender),
              child: const Text('Kalender'),
            ),
            child: naechsterTermin == null
                ? const EmptyHint(text: 'Kein Termin eingetragen.')
                : Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.14),
                        child: Icon(
                          naechsterTermin.kategorie.icon,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              naechsterTermin.titel.isEmpty
                                  ? naechsterTermin.kategorie.label
                                  : naechsterTermin.titel,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${dfWeekday.format(naechsterTermin.zeitpunkt)}'
                              ' · ${naechsterTermin.zeitLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Zuletzt gefüttert',
            icon: Icons.restaurant_outlined,
            trailing: TextButton(
              onPressed: () => onOpen(Tabs.alltag, unterreiter: 0),
              child: const Text('Alle'),
            ),
            child: letzteFuetterung == null
                ? const EmptyHint(text: 'Noch nichts eingetragen.')
                : _LastFeeding(entry: letzteFuetterung),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Gewicht',
            icon: Icons.monitor_weight_outlined,
            trailing: TextButton(
              onPressed: () => onOpen(Tabs.gesundheit, unterreiter: 0),
              child: const Text('Verlauf'),
            ),
            child: gewicht == null
                ? const EmptyHint(text: 'Noch keine Messung.')
                : Row(
                    children: [
                      if (gewicht.hatFoto)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: DogPhoto(fotoRef: gewicht.fotoRef!, size: 64),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gewicht.gewichtLabel,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'gemessen am '
                              '${dfDateTime.format(gewicht.zeitpunkt)} Uhr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SyncHint(state: state),
        ],
      ),
    );
  }
}

/// Die Zeile, die man morgens wirklich lesen muss: offene
/// Medikamentengaben, verpasste Termine, fällige Impfungen.
class _Hinweise extends StatelessWidget {
  const _Hinweise({
    required this.offeneGaben,
    required this.verpasste,
    required this.impfungen,
    required this.onOpen,
  });

  final int offeneGaben;
  final int verpasste;
  final int impfungen;
  final void Function(int index, {int? unterreiter}) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondary.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          children: [
            if (offeneGaben > 0)
              _Zeile(
                icon: Icons.medication_outlined,
                text: offeneGaben == 1
                    ? 'Eine Medikamentengabe steht heute noch aus.'
                    : '$offeneGaben Medikamentengaben stehen heute noch aus.',
                aktion: 'Ansehen',
                onTap: () => onOpen(Tabs.gesundheit, unterreiter: 1),
              ),
            if (verpasste > 0)
              _Zeile(
                icon: Icons.event_busy_outlined,
                text: verpasste == 1
                    ? 'Ein Termin ist vorbei und noch nicht abgehakt.'
                    : '$verpasste Termine sind vorbei und noch offen.',
                aktion: 'Kalender',
                onTap: () => onOpen(Tabs.kalender),
              ),
            if (impfungen > 0)
              _Zeile(
                icon: Icons.vaccines_outlined,
                text: impfungen == 1
                    ? 'Eine Impfung wird fällig.'
                    : '$impfungen Impfungen werden fällig.',
                aktion: 'Ansehen',
                onTap: () => onOpen(Tabs.gesundheit, unterreiter: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.icon,
    required this.text,
    required this.aktion,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final String aktion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
        TextButton(onPressed: onTap, child: Text(aktion)),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = state.profile;
    final stunde = DateTime.now().hour;
    final gruss = stunde < 11
        ? 'Guten Morgen'
        : (stunde < 18 ? 'Hallo' : 'Guten Abend');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.pets, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name.isEmpty ? gruss : '$gruss, ${p.name}!',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.geburtsdatum == null
                        ? dfWeekday.format(DateTime.now())
                        : '${formatAge(p.geburtsdatum!)} alt · '
                            '${dfWeekday.format(DateTime.now())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _LastFeeding extends StatelessWidget {
  const _LastFeeding({required this.entry});

  final FeedingEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vergangen = DateTime.now().difference(entry.zeitpunkt);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.futter.isEmpty ? entry.mahlzeit.label : entry.futter,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${dfDateTime.format(entry.zeitpunkt)} Uhr · '
                'vor ${formatDuration(vergangen)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          entry.mengeLabel,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Macht sichtbar, wo die Daten gerade liegen. Solange die App nur
/// lokal speichert, ist das eine wichtige Information – sonst wundert
/// sich die zweite Person, warum ihre Einträge fehlen.
class _SyncHint extends StatelessWidget {
  const _SyncHint({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bootstrap = context.read<BootstrapController>();
    final shared = state.isShared;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            shared ? Icons.cloud_done_outlined : Icons.phone_iphone,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              shared
                  ? '${state.backendLabel} – alle Geräte mit diesem '
                      'Codewort sehen denselben Stand.'
                  : 'Daten liegen nur auf diesem Gerät. Sobald die '
                      'Cloud-Anbindung eingerichtet ist, sehen alle '
                      'denselben Stand.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (shared)
            TextButton(
              onPressed: () => _haushaltWechseln(context, bootstrap),
              child: const Text('Wechseln'),
            ),
        ],
      ),
    );
  }

  /// Beim Wechsel gehen keine Daten verloren – sie bleiben unter dem
  /// alten Codewort liegen. Trotzdem nachfragen, weil die Oberfläche
  /// danach leer aussieht und das ohne Vorwarnung erschreckt.
  Future<void> _haushaltWechseln(
    BuildContext context,
    BootstrapController bootstrap,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Codewort wechseln?'),
        content: const Text(
          'Dieses Gerät wird von den bisherigen Daten getrennt und '
          'fragt neu nach einem Codewort. Die Einträge selbst bleiben '
          'erhalten – mit demselben Codewort sind sie wieder da.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Wechseln'),
          ),
        ],
      ),
    );
    if (ok ?? false) await bootstrap.wechsleHaushalt();
  }
}
