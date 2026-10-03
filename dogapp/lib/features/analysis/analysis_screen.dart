import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../state/analyse.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Auswertung von Fütterung und Schlaf.
///
/// Zwei Fragen stehen im Mittelpunkt: Wann bekommt er sein Futter, und
/// wann schläft er – jeweils nach Wochentagen getrennt, weil der
/// Wochenrhythmus eines Haushalts genau daran hängt.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  Zeitraum _zeitraum = Zeitraum.monat;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    final futter = werteFutterAus(state.feedings, zeitraum: _zeitraum);
    final schlaf = werteSchlafAus(state.sleeps, zeitraum: _zeitraum);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final z in Zeitraum.values)
                ChoiceChip(
                  label: Text(z.label),
                  selected: _zeitraum == z,
                  onSelected: (_) => setState(() => _zeitraum = z),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _FutterKarte(analyse: futter),
          const SizedBox(height: 16),
          _SchlafKarte(analyse: schlaf),
          const SizedBox(height: 20),
          Text(
            'Gerechnet wird mit den geladenen Einträgen. Für einen '
            'längeren Rückblick unten Ältere nachladen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const MehrLaden(bereich: Bereich.fuetterung),
          const MehrLaden(bereich: Bereich.schlaf),
        ],
      ),
    );
  }
}

// --- Fütterung --------------------------------------------------------

class _FutterKarte extends StatelessWidget {
  const _FutterKarte({required this.analyse});

  final FutterAnalyse analyse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Fütterung – wann',
      icon: Icons.restaurant_outlined,
      child: analyse.leer
          ? const EmptyHint(
              icon: Icons.ramen_dining_outlined,
              text: 'In diesem Zeitraum ist keine Mahlzeit erfasst.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Mahlzeiten je Tag',
                        value: nfAmount.format(analyse.mahlzeitenProTag),
                        hint: '${analyse.anzahl} an '
                            '${analyse.erfassteTage} Tagen',
                        icon: Icons.restaurant_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Menge je Tag',
                        value: analyse.mengeProTag.isEmpty
                            ? '–'
                            : futterSummeLabel(analyse.mengeProTag),
                        icon: Icons.scale_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Uhrzeiten nach Wochentag',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ein Punkt je Mahlzeit. Leckerli zählen nicht mit.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                for (final tag in analyse.wochentage)
                  _ZeitenZeile(tag: tag),
                const _StundenLeiste(),
                if (analyse.typischeZeiten.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Typische Zeiten',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final f in analyse.typischeZeiten.take(5))
                        _Marke(
                          text: '${uhrzeitLabel(f.mittel)} · ${f.anzahl}×',
                          hinweis: f.anzahl == 1
                              ? null
                              : 'Spanne ${f.label}',
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Dieselben Zahlen noch einmal zum Nachlesen: Ein
                // Punktbild beantwortet „wann", eine Zahl „wie viel".
                for (final tag in analyse.wochentage)
                  if (tag.anzahl > 0)
                    _TabellenZeile(
                      links: tag.lang,
                      rechts: '${nfAmount.format(tag.mahlzeitenProTag)} '
                          'Mahlzeiten'
                          '${tag.mengeProTag.isEmpty ? '' : ' · '
                              '${futterSummeLabel(tag.mengeProTag)}'}',
                      hinweis: 'an ${tag.erfassteTage} '
                          '${tag.erfassteTage == 1 ? 'Tag' : 'Tagen'} erfasst',
                    ),
              ],
            ),
    );
  }
}

/// Ein Wochentag als Zeitstrahl von 0 bis 24 Uhr.
class _ZeitenZeile extends StatelessWidget {
  const _ZeitenZeile({required this.tag});

  final FutterWochentag tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              tag.kurz,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const punkt = 9.0;
                final breite = constraints.maxWidth - punkt;
                return SizedBox(
                  height: 22,
                  child: Stack(
                    children: [
                      // Zurückhaltende Spur, damit auch ein leerer Tag
                      // als Tag zu erkennen ist.
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                      for (final minute in tag.zeiten)
                        Positioned(
                          left: breite * (minute / 1440),
                          top: (22 - punkt) / 2,
                          child: Tooltip(
                            message: '${tag.lang}, ${uhrzeitLabel(minute)} Uhr',
                            child: Container(
                              width: punkt,
                              height: punkt,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                // Ring in Kartenfarbe: Zwei Mahlzeiten
                                // kurz nacheinander bleiben so als zwei
                                // Punkte erkennbar.
                                border: Border.all(
                                  color: theme.cardColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- Schlaf -----------------------------------------------------------

class _SchlafKarte extends StatelessWidget {
  const _SchlafKarte({required this.analyse});

  final SchlafAnalyse analyse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verteilung = analyse.klassenVerteilung;
    final groesste =
        verteilung.isEmpty ? 0 : verteilung.reduce((a, b) => a > b ? a : b);

    return SectionCard(
      title: 'Schlaf – wann und wie lang',
      icon: Icons.bedtime_outlined,
      child: analyse.leer
          ? const EmptyHint(
              icon: Icons.bedtime_outlined,
              text: 'In diesem Zeitraum ist keine Schlafphase erfasst.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Schlaf je Tag',
                        value: formatDuration(analyse.proTag),
                        hint: 'an ${analyse.erfassteTage} Tagen',
                        icon: Icons.timelapse_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Zyklus im Schnitt',
                        value: formatDuration(analyse.zyklusSchnitt),
                        hint: '${nfAmount.format(analyse.zyklenProTag)} '
                            'je Tag · längster '
                            '${formatDuration(analyse.laengsterZyklus)}',
                        icon: Icons.bedtime_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Schlafzeiten nach Wochentag',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Je dunkler, desto mehr Schlaf in dieser Stunde.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                for (final tag in analyse.wochentage)
                  _StundenZeile(tag: tag, spitze: analyse.stundenSpitze),
                const _StundenLeiste(),
                const SizedBox(height: 10),
                const _RasterLegende(),
                const SizedBox(height: 16),
                Text(
                  'Zyklen nach Dauer',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Eine Schlafphase von Anfang bis Ende, auch über '
                  'Mitternacht hinweg.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < zyklusklassen.length; i++)
                  _Balken(
                    label: zyklusklassen[i].label,
                    anzahl: verteilung[i],
                    groesste: groesste,
                  ),
                const SizedBox(height: 16),
                for (final tag in analyse.wochentage)
                  if (tag.gesamt > Duration.zero)
                    _TabellenZeile(
                      links: tag.lang,
                      rechts: '${formatDuration(tag.proTag)} je Tag'
                          '${tag.zyklen.isEmpty ? '' : ' · '
                              '${nfAmount.format(tag.zyklenProTag)} Zyklen'}',
                      hinweis: tag.zyklen.isEmpty
                          ? 'an ${tag.erfassteTage} '
                              '${tag.erfassteTage == 1 ? 'Tag' : 'Tagen'} erfasst'
                          : 'Zyklus im Schnitt '
                              '${formatDuration(tag.zyklusSchnitt)}',
                    ),
              ],
            ),
    );
  }
}

/// Ein Wochentag als 24 Stundenfelder, eingefärbt nach Schlafanteil.
class _StundenZeile extends StatelessWidget {
  const _StundenZeile({required this.tag, required this.spitze});

  final SchlafWochentag tag;
  final double spitze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leer = theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              tag.kurz,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (var stunde = 0; stunde < 24; stunde++) ...[
            if (stunde > 0) const SizedBox(width: 2),
            Expanded(
              child: Tooltip(
                message: '${tag.lang}, '
                    '${stunde.toString().padLeft(2, '0')}:00 – '
                    '${(stunde + 1).toString().padLeft(2, '0')}:00 Uhr\n'
                    '${tag.minutenJeStunde[stunde].round()} min Schlaf',
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: spitze <= 0
                        ? leer
                        : Color.lerp(
                            leer,
                            theme.colorScheme.primary,
                            tag.minutenJeStunde[stunde] / spitze,
                          ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Farbskala zum Raster – ohne sie ist „dunkler" nur eine Behauptung.
class _RasterLegende extends StatelessWidget {
  const _RasterLegende();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leer = theme.colorScheme.surfaceContainerHighest;

    return Row(
      children: [
        const SizedBox(width: 26),
        Text(
          'wenig',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 18,
            height: 10,
            decoration: BoxDecoration(
              color: Color.lerp(leer, theme.colorScheme.primary, i / 4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Text(
          'viel',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// --- Gemeinsame Kleinteile --------------------------------------------

/// Stundenbeschriftung unter einem Raster. Nur alle sechs Stunden –
/// 24 Zahlen wären eine Wand.
class _StundenLeiste extends StatelessWidget {
  const _StundenLeiste();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stil = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.outline, fontSize: 10);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Expanded(child: Text('0', style: stil)),
          Expanded(
            child: Text('6', style: stil, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('12', style: stil, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('18', style: stil, textAlign: TextAlign.center),
          ),
          Text('24 Uhr', style: stil),
        ],
      ),
    );
  }
}

/// Ein Balken der Zyklusverteilung.
class _Balken extends StatelessWidget {
  const _Balken({
    required this.label,
    required this.anzahl,
    required this.groesste,
  });

  final String label;
  final int anzahl;
  final int groesste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anteil = groesste == 0 ? 0.0 : anzahl / groesste;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  width: anteil == 0 ? 2 : constraints.maxWidth * anteil,
                  decoration: BoxDecoration(
                    color: anteil == 0
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$anzahl',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zeile der Zahlentabelle unter einem Raster.
class _TabellenZeile extends StatelessWidget {
  const _TabellenZeile({
    required this.links,
    required this.rechts,
    this.hinweis,
  });

  final String links;
  final String rechts;
  final String? hinweis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(links, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rechts,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (hinweis != null)
                  Text(
                    hinweis!,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kleine Marke für eine typische Zeit.
class _Marke extends StatelessWidget {
  const _Marke({required this.text, this.hinweis});

  final String text;
  final String? hinweis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: hinweis ?? text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
