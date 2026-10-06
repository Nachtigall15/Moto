import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/geschaeft.dart';
import '../../state/analyse.dart' show uhrzeitLabel, wochentagKurz;
import '../../state/app_state.dart';
import '../../state/stubenreinheit.dart';
import '../../state/verdauung.dart';
import '../common/ui.dart';

/// Stubenreinheit: was, wann, wo – und darüber die Übersicht, an der
/// sich das Training ausrichtet.
///
/// Oben stehen die vier häufigsten Einträge als Knopf. Wer mit dem
/// Welpen gerade von draußen reinkommt, hat eine Hand an der Leine;
/// ein Antippen muss reichen.
class StubenreinheitScreen extends StatefulWidget {
  const StubenreinheitScreen({super.key});

  @override
  State<StubenreinheitScreen> createState() => _StubenreinheitScreenState();
}

class _StubenreinheitScreenState extends State<StubenreinheitScreen> {
  Timer? _ticker;

  /// Gilt nur für den nächsten Schnelleintrag und springt danach
  /// zurück – sonst stünde es versehentlich an jedem Eintrag.
  bool _gemeldet = false;

  @override
  void initState() {
    super.initState();
    // „vor 40 min" und der nächste fällige Gang sollen mitlaufen.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _schnell(Geschaeftsart art, Ort ort) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final eintrag = Geschaeft(
      zeitpunkt: DateTime.now(),
      art: art,
      ort: ort,
      gemeldet: _gemeldet,
    );
    setState(() => _gemeldet = false);
    await state.saveGeschaeft(eintrag);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '${eintrag.label} um ${dfTime.format(eintrag.zeitpunkt)} Uhr '
          'eingetragen.',
        ),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () => state.deleteGeschaeft(eintrag.id),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final jetzt = DateTime.now();
    final bilanz = state.stubenbilanz(jetzt);
    final verdauung = state.verdauung(jetzt);
    final gang = naechsterGang(bilanz, verdauung);

    final byDay = <DateTime, List<Geschaeft>>{};
    for (final g in state.geschaefte) {
      byDay.putIfAbsent(startOfDay(g.zeitpunkt), () => []).add(g);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Eindeutige Kennung: Alle Reiter liegen gleichzeitig im
        // Baum, ohne sie stolpert die Übergangsanimation über
        // mehrere gleich benannte Knöpfe.
        heroTag: 'fab-stubenreinheit',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Eintrag'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionCard(
            title: 'Jetzt eintragen',
            icon: Icons.touch_app_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final ort in Ort.values) ...[
                  if (ort != Ort.values.first) const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final art in Geschaeftsart.values) ...[
                        if (art != Geschaeftsart.values.first)
                          const SizedBox(width: 10),
                        Expanded(
                          child: _OrtKnopf(
                            art: art,
                            ort: ort,
                            onPressed: () => _schnell(art, ort),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    avatar: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('hat sich gemeldet'),
                    selected: _gemeldet,
                    onSelected: (v) => setState(() => _gemeldet = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Heute(bilanz: bilanz, gang: gang, jetzt: jetzt),
          const SizedBox(height: 16),
          _NachDemFressen(verdauung: verdauung, jetzt: jetzt),
          const SizedBox(height: 16),
          _FesteZeiten(slots: state.zeitslots(jetzt), jetzt: jetzt),
          const SizedBox(height: 16),
          _Training(bilanz: bilanz, jetzt: jetzt),
          const SizedBox(height: 16),
          if (days.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.water_drop_outlined,
                text: 'Noch nichts eingetragen.\n'
                    'Oben antippen, was er gerade gemacht hat.',
              ),
            ),
          for (final day in days) ...[
            Builder(builder: (context) {
              final tag = stubenTag(byDay[day]!);
              return TagesKopf(
                tag: isSameDay(day, jetzt) ? 'Heute' : dfWeekday.format(day),
                summe: '${quoteLabel(tag.quote)} stubenrein',
                zusatz: '${tag.zusammenfassung} · ${tag.orte}',
              );
            }),
            Card(
              child: Column(
                children: [
                  for (final g
                      in byDay[day]!
                        ..sort((a, b) => b.zeitpunkt.compareTo(a.zeitpunkt)))
                    _GeschaeftTile(eintrag: g),
                ],
              ),
            ),
          ],
          const MehrLaden(bereich: Bereich.geschaefte),
        ],
      ),
    );
  }
}

IconData iconFuer(Geschaeftsart art) => switch (art) {
      Geschaeftsart.pipi => Icons.water_drop_outlined,
      Geschaeftsart.kaki => Icons.grain,
    };

/// Farbe je Ort. Drinnen deutlich, aber kein Alarm – ein Missgeschick
/// gehört zum Lernen dazu.
Color ortFarbe(ThemeData theme, Ort ort) => switch (ort) {
      Ort.draussen => theme.colorScheme.primary,
      Ort.terrasse => theme.colorScheme.tertiary,
      Ort.drinnen => theme.colorScheme.error,
    };

IconData ortIcon(Ort ort) => switch (ort) {
      Ort.draussen => Icons.park_outlined,
      Ort.terrasse => Icons.deck_outlined,
      Ort.drinnen => Icons.home_outlined,
    };

/// Draußen ist das Ziel und bekommt den vollen Knopf; Terrasse und
/// drinnen stehen als Umriss in ihrer Farbe darunter.
class _OrtKnopf extends StatelessWidget {
  const _OrtKnopf({
    required this.art,
    required this.ort,
    required this.onPressed,
  });

  final Geschaeftsart art;
  final Ort ort;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Text('${art.label} ${ort.label}');
    final icon = Icon(iconFuer(art));
    if (ort == Ort.draussen) {
      return FilledButton.icon(onPressed: onPressed, icon: icon, label: text);
    }
    final farbe = ortFarbe(Theme.of(context), ort);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: text,
      style: OutlinedButton.styleFrom(
        foregroundColor: farbe,
        side: BorderSide(color: farbe.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// Der Stand von heute: wie viel ging nicht in die Wohnung, wann war er zuletzt,
/// wann muss er wieder raus.
class _Heute extends StatelessWidget {
  const _Heute({required this.bilanz, required this.gang, required this.jetzt});

  final Stubenbilanz bilanz;
  final ({DateTime zeit, String grund})? gang;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heute = bilanz.tage.first.$2;
    final pipi = bilanz.letztesPipi;
    final naechster = gang?.zeit;
    final ueberfaellig = naechster != null && !naechster.isAfter(jetzt);

    return SectionCard(
      title: 'Heute',
      icon: Icons.today_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatTile(
              label: 'Stubenrein',
              value: heute.gesamt == 0
                  ? '–'
                  : '${heute.stubenrein} von ${heute.gesamt}',
              hint: heute.gesamt == 0 ? 'noch nichts' : heute.orte,
              icon: Icons.park_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatTile(
              label: 'Letztes Pipi',
              value: pipi == null
                  ? '–'
                  : 'vor ${formatDuration(jetzt.difference(pipi.zeitpunkt))}',
              hint: pipi == null
                  ? null
                  : '${dfTime.format(pipi.zeitpunkt)} Uhr · ${pipi.ort.label}',
              icon: Icons.water_drop_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatTile(
              label: 'Wieder raus',
              value: naechster == null
                  ? '–'
                  : (ueberfaellig ? 'jetzt' : '~${dfTime.format(naechster)}'),
              hint: gang?.grund ?? 'Rhythmus noch unklar',
              icon: Icons.schedule,
              color: ueberfaellig ? theme.colorScheme.secondary : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wie lange nach dem Fressen er raus muss – und wann es nach der
/// letzten Mahlzeit so weit ist.
class _NachDemFressen extends StatelessWidget {
  const _NachDemFressen({required this.verdauung, required this.jetzt});

  final Verdauung verdauung;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kakki = verdauung.kakki;
    final pipi = verdauung.pipi;
    final erwartung = verdauung.erwartung;

    if (!kakki.aussagekraeftig && !pipi.aussagekraeftig) {
      return const SectionCard(
        title: 'Nach dem Fressen',
        icon: Icons.restaurant_outlined,
        child: EmptyHint(
          text: 'Noch zu wenig Daten. Es braucht mindestens drei Mahlzeiten '
              'mit einem Geschäft danach – Fütterungen unter „Fütterung" '
              'eintragen, Geschäfte hier.',
        ),
      );
    }

    final faellig = erwartung != null && !erwartung.ab.isAfter(jetzt);

    return SectionCard(
      title: 'Nach dem Fressen',
      icon: Icons.restaurant_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (erwartung != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (faellig
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    faellig ? Icons.directions_walk : Icons.alarm,
                    color: faellig
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${erwartung.mahlzeit.mahlzeit.label} um '
                      '${dfTime.format(erwartung.mahlzeit.zeitpunkt)} Uhr – '
                      '${faellig ? 'jetzt raus' : 'ab ${dfTime.format(erwartung.ab)} Uhr raus'}. '
                      'Kakki meist bis ${dfTime.format(erwartung.bis)} Uhr.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in [kakki, pipi]) ...[
                if (n != kakki) const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: '${n.art.label} nach',
                    value: n.typisch == null
                        ? '–'
                        : '~${formatDuration(n.typisch!)}',
                    hint: !n.aussagekraeftig
                        ? 'noch zu wenig Daten'
                        : 'meist ${formatDuration(n.frueh!)} bis '
                            '${formatDuration(n.spaet!)} · '
                            '${n.abstaende.length} von ${n.mahlzeiten} '
                            'Mahlzeiten',
                    icon: iconFuer(n.art),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Gerechnet aus den letzten $verdauungTage Tagen: jeweils das '
            'erste Geschäft nach einer Mahlzeit, höchstens '
            '${formatDuration(nachFutterFenster)} danach und vor der '
            'nächsten. Es zählen nur Tage, an denen auch Geschäfte '
            'eingetragen sind; Leckerli zählen nicht als Mahlzeit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Uhrzeiten, zu denen er regelmäßig raus muss – die Grundlage für
/// einen festen Tagesplan.
class _FesteZeiten extends StatelessWidget {
  const _FesteZeiten({required this.slots, required this.jetzt});

  final List<Zeitslot> slots;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minuteJetzt = jetzt.hour * 60 + jetzt.minute;
    // Das nächste Fenster, das noch nicht vorbei ist.
    final naechster = slots.where((s) => s.bis >= minuteJetzt).firstOrNull;

    return SectionCard(
      title: 'Feste Zeiten',
      icon: Icons.event_repeat_outlined,
      child: slots.isEmpty
          ? const EmptyHint(
              text: 'Noch keine festen Zeiten erkennbar. Dafür braucht es '
                  'Einträge von mindestens drei Tagen – eine Zeit gilt als '
                  'fest, wenn er an der Hälfte der Tage um diese Uhrzeit '
                  'raus musste.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final slot in slots)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: (slot == naechster
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary)
                          .withValues(alpha: 0.14),
                      child: Text(
                        uhrzeitLabel(slot.typisch).substring(0, 2),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: slot == naechster
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      '${slot.label} Uhr',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${slot.arten} · an ${slot.tage} von '
                      '${slot.erfassteTage} Tagen'
                      '${slot == naechster ? ' · als Nächstes' : ''}',
                    ),
                    trailing: Text(
                      quoteLabel(slot.anteil),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Ein Fenster gilt als fest, wenn er an mindestens der '
                  'Hälfte der erfassten Tage darin raus musste (letzte '
                  '$verdauungTage Tage). Kurz vor Beginn rausgehen.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Die Trainingsübersicht: Wird es besser, wie lange ging es gut, und
/// wann passiert es noch?
class _Training extends StatelessWidget {
  const _Training({required this.bilanz, required this.jetzt});

  final Stubenbilanz bilanz;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final woche = bilanz.woche;
    final vorwoche = bilanz.vorwoche;
    final ohne = bilanz.tageOhneMissgeschick(jetzt);
    final gedaempft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    String? trend;
    if (woche.quote != null && vorwoche.quote != null) {
      final diff = ((woche.quote! - vorwoche.quote!) * 100).round();
      trend = diff == 0
          ? 'wie Vorwoche'
          : '${diff > 0 ? '+' : '−'}${diff.abs()} Punkte zur Vorwoche';
    }

    return SectionCard(
      title: 'Training · letzte 7 Tage',
      icon: Icons.insights_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatTile(
                  label: 'Stubenrein',
                  value: quoteLabel(woche.quote),
                  hint: trend ??
                      (woche.gesamt == 0
                          ? 'noch keine Einträge'
                          : '${woche.stubenrein} von ${woche.gesamt}'),
                  icon: Icons.park_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Ohne Missgeschick',
                  value: ohne == null
                      ? (woche.gesamt == 0 ? '–' : 'bisher immer')
                      : (ohne == 0
                          ? 'heute nicht'
                          : (ohne == 1 ? '1 Tag' : '$ohne Tage')),
                  hint: bilanz.letztesMissgeschick == null
                      ? null
                      : 'zuletzt ${dfShortDay.format(bilanz.letztesMissgeschick!.zeitpunkt)}'
                          ' ${dfTime.format(bilanz.letztesMissgeschick!.zeitpunkt)}',
                  icon: Icons.emoji_events_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Gemeldet',
                  value: woche.gesamt == 0
                      ? '–'
                      : '${woche.gemeldet} von ${woche.gesamt}',
                  hint: 'von selbst angezeigt',
                  icon: Icons.campaign_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Wochenbalken(tage: bilanz.tage.reversed.toList()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final ort in Ort.values)
                _Legende(farbe: ortFarbe(theme, ort), text: ort.label),
            ],
          ),
          if (woche.terrasse > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${woche.terrasse} von ${woche.stubenrein} Geschäften ohne '
              'Missgeschick waren auf der Terrasse – '
              '${quoteLabel(woche.draussen / woche.stubenrein)} richtig draußen.',
              style: gedaempft,
            ),
          ],
          if (bilanz.missgeschickStunden.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Drinnen passiert es meist gegen '
              '${bilanz.missgeschickStunden.take(3).map((s) => '${s.$1} Uhr (${s.$2}×)').join(', ')}'
              ' – kurz vorher rausgehen.',
              style: gedaempft,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sieben Tage nebeneinander, je ein Balken aus draußen (unten),
/// Terrasse und drinnen (oben). Die Höhe folgt der Zahl der Geschäfte, darunter
/// steht die Quote – so sieht man Fortschritt und Datenlage zugleich.
class _Wochenbalken extends StatelessWidget {
  const _Wochenbalken({required this.tage});

  /// Ältester Tag zuerst.
  final List<(DateTime, StubenTag)> tage;

  static const _hoehe = 72.0;

  static int _anzahl(StubenTag t, Ort ort) => switch (ort) {
        Ort.draussen => t.draussen,
        Ort.terrasse => t.terrasse,
        Ort.drinnen => t.drinnen,
      };

  /// Nur das oberste Stück bekommt runde Ecken.
  static Ort? _obersterOrt(StubenTag t) {
    for (final ort in Ort.values.reversed) {
      if (_anzahl(t, ort) > 0) return ort;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maximum =
        tage.fold<int>(1, (m, t) => t.$2.gesamt > m ? t.$2.gesamt : m);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (tag, zahlen) in tage)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    zahlen.gesamt == 0 ? '' : quoteLabel(zahlen.quote),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: _hoehe,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Von oben nach unten: drinnen, Terrasse, draußen.
                        for (final ort in Ort.values.reversed)
                          if (_anzahl(zahlen, ort) > 0)
                            Container(
                              height: _hoehe * _anzahl(zahlen, ort) / maximum,
                              decoration: BoxDecoration(
                                color: ortFarbe(theme, ort),
                                borderRadius: BorderRadius.vertical(
                                  top: _obersterOrt(zahlen) == ort
                                      ? const Radius.circular(4)
                                      : Radius.zero,
                                ),
                              ),
                            ),
                        if (zahlen.gesamt == 0)
                          Container(
                            height: 2,
                            color: theme.colorScheme.outlineVariant,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wochentagKurz[tag.weekday - 1],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende({required this.farbe, required this.text});

  final Color farbe;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: farbe,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _GeschaeftTile extends StatelessWidget {
  const _GeschaeftTile({required this.eintrag});

  final Geschaeft eintrag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = ortFarbe(theme, eintrag.ort);

    return ListTile(
      onTap: () => _openEditor(context, eintrag: eintrag),
      leading: CircleAvatar(
        backgroundColor: farbe.withValues(alpha: 0.14),
        child: Icon(iconFuer(eintrag.art), size: 20, color: farbe),
      ),
      title: Text(
        eintrag.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text([
        '${dfTime.format(eintrag.zeitpunkt)} Uhr',
        if (eintrag.gemeldet) 'hat sich gemeldet',
        if (eintrag.notiz.isNotEmpty) eintrag.notiz,
      ].join(' · ')),
      trailing: Icon(ortIcon(eintrag.ort), color: farbe),
    );
  }
}

Future<void> _openEditor(BuildContext context, {Geschaeft? eintrag}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _GeschaeftEditor(eintrag: eintrag),
  );
}

class _GeschaeftEditor extends StatefulWidget {
  const _GeschaeftEditor({this.eintrag});

  final Geschaeft? eintrag;

  @override
  State<_GeschaeftEditor> createState() => _GeschaeftEditorState();
}

class _GeschaeftEditorState extends State<_GeschaeftEditor> {
  late final TextEditingController _notiz =
      TextEditingController(text: widget.eintrag?.notiz ?? '');

  /// Beim Anlegen dürfen beide Arten gewählt sein – oft kommt beides
  /// im selben Gang. Gespeichert werden trotzdem zwei Einträge, damit
  /// der Pipi-Rhythmus stimmt.
  late Set<Geschaeftsart> _arten = {
    widget.eintrag?.art ?? Geschaeftsart.pipi,
  };
  late Ort _ort = widget.eintrag?.ort ?? Ort.draussen;
  late bool _gemeldet = widget.eintrag?.gemeldet ?? false;
  late DateTime _zeitpunkt = widget.eintrag?.zeitpunkt ?? DateTime.now();

  bool get _neu => widget.eintrag == null;

  @override
  void dispose() {
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final notiz = _notiz.text.trim();

    if (_neu) {
      for (final art in Geschaeftsart.values.where(_arten.contains)) {
        await state.saveGeschaeft(Geschaeft(
          zeitpunkt: _zeitpunkt,
          art: art,
          ort: _ort,
          gemeldet: _gemeldet,
          notiz: notiz,
        ));
      }
    } else {
      await state.saveGeschaeft(widget.eintrag!.copyWith(
        zeitpunkt: _zeitpunkt,
        art: _arten.first,
        ort: _ort,
        gemeldet: _gemeldet,
        notiz: notiz,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final state = context.read<AppState>();
    await state.deleteGeschaeft(widget.eintrag!.id);
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
              _neu ? 'Neuer Eintrag' : 'Eintrag bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<Geschaeftsart>(
              segments: [
                for (final a in Geschaeftsart.values)
                  ButtonSegment(
                    value: a,
                    label: Text(a.label),
                    icon: Icon(iconFuer(a)),
                  ),
              ],
              selected: _arten,
              multiSelectionEnabled: _neu,
              onSelectionChanged: (s) => setState(() => _arten = s),
            ),
            const SizedBox(height: 12),
            SegmentedButton<Ort>(
              segments: [
                for (final o in Ort.values)
                  ButtonSegment(
                    value: o,
                    label: Text(o.titel),
                    icon: Icon(ortIcon(o)),
                  ),
              ],
              selected: {_ort},
              onSelectionChanged: (s) => setState(() => _ort = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hat sich gemeldet'),
              subtitle: const Text('an der Tür gewartet, gefiept …'),
              value: _gemeldet,
              onChanged: (v) => setState(() => _gemeldet = v),
            ),
            const SizedBox(height: 4),
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
                hintText: 'z. B. direkt nach dem Spielen',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Speichern')),
            if (!_neu) ...[
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
