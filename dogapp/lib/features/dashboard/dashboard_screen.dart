import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/feeding_entry.dart';
import '../../state/app_state.dart';
import '../common/dog_photo.dart';
import '../common/ui.dart';

/// Startseite: der Blick, den jemand braucht, der gerade zur Tür
/// reinkommt – hat er schon gefressen, schläft er, wann war das
/// letzte Wiegen.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  /// Sprung in einen der Haupt-Tabs (Index wie in der Navigationsleiste).
  final ValueChanged<int> onOpenTab;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(profil.name.isEmpty ? 'Übersicht' : profil.name),
        actions: [
          IconButton(
            tooltip: 'Heimtierausweis',
            onPressed: () => onOpenTab(4),
            icon: const Icon(Icons.badge_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Greeting(state: state),
          const SizedBox(height: 16),
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
                                    '${nfAmount.format(e.value)} ${e.key.label}')
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
                        color: schlaf != null ? theme.colorScheme.secondary : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onOpenTab(1),
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
                        icon: Icon(
                          schlaf == null ? Icons.bedtime : Icons.stop,
                        ),
                        label: Text(
                          schlaf == null ? 'Schläft' : 'Wach',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Zuletzt gefüttert',
            icon: Icons.restaurant_outlined,
            trailing: TextButton(
              onPressed: () => onOpenTab(1),
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
              onPressed: () => onOpenTab(3),
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
    final shared = state.isShared;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
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
                  ? 'Daten werden mit allen Geräten geteilt.'
                  : 'Daten liegen nur auf diesem Gerät. Sobald die '
                      'Cloud-Anbindung eingerichtet ist, sehen alle '
                      'denselben Stand.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
