import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// Karte mit Überschrift – das Grundelement aller Screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Hinweis für leere Listen – besser als eine blanke Fläche.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          if (icon != null)
            Icon(icon, size: 32, color: theme.colorScheme.outline),
          if (icon != null) const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Kompakte Kennzahl (Wert groß, Beschriftung klein darunter).
///
/// Mit [onTap] wird sie zum Sprungbrett in den zugehörigen Bereich –
/// eine Zahl auf der Startseite lädt zum Antippen ein, und ohne
/// Reaktion wirkt sie kaputt.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  static const _rundung = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    final inhalt = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Kleiner Wink, dass hier mehr dahintersteckt.
              if (onTap != null)
                Icon(Icons.chevron_right,
                    size: 16, color: theme.colorScheme.outline),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );

    final schmuck = BoxDecoration(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(_rundung),
      border: Border.all(color: accent.withValues(alpha: 0.25)),
    );
    const abstand = EdgeInsets.symmetric(horizontal: 14, vertical: 12);

    if (onTap == null) {
      return Container(padding: abstand, decoration: schmuck, child: inhalt);
    }

    // Der Hintergrund liegt in einem Ink, sonst versteckte er die
    // Welle des Fingertipps unter sich.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_rundung),
        child: Ink(
          padding: abstand,
          decoration: schmuck,
          child: inhalt,
        ),
      ),
    );
  }
}

/// Überschrift einer Tagesgruppe: links der Tag, rechts die Summe
/// dieses Tages.
///
/// Die Kennzahlen oben auf den Bildschirmen gelten immer nur für heute.
/// Erst die Tagessumme in der Überschrift macht vergangene Tage
/// vergleichbar, ohne dass man die einzelnen Einträge zusammenrechnet.
class TagesKopf extends StatelessWidget {
  const TagesKopf({
    super.key,
    required this.tag,
    required this.summe,
    this.zusatz,
  });

  /// Beschriftung des Tages, z. B. „Heute" oder „Montag, 4. August".
  final String tag;

  /// Tagessumme, z. B. „7 h 20 min" oder „450 g · 2 Stück". Leer, wenn
  /// es nichts zu summieren gibt.
  final String summe;

  /// Kleine Ergänzung unter dem Tag, z. B. „3 Phasen".
  final String? zusatz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (zusatz != null && zusatz!.isNotEmpty)
                  Text(
                    zusatz!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          if (summe.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                summe,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fuß einer wachsenden Liste: sagt, wie viel geladen ist, und lädt
/// auf Knopfdruck den nächsten Schwung älterer Einträge dazu.
///
/// Die App zeigt aus Geschwindigkeitsgründen nur einen Ausschnitt der
/// jüngsten Vergangenheit. Ohne diesen Fuß wäre nicht erkennbar, dass
/// es überhaupt noch mehr gibt – und genau das lässt einen glauben,
/// alte Einträge seien verloren.
class MehrLaden extends StatefulWidget {
  const MehrLaden({super.key, required this.bereich});

  final Bereich bereich;

  @override
  State<MehrLaden> createState() => _MehrLadenState();
}

class _MehrLadenState extends State<MehrLaden> {
  bool _laeuft = false;

  Future<void> _laden() async {
    setState(() => _laeuft = true);
    await context.read<AppState>().mehrLaden(widget.bereich);
    if (mounted) setState(() => _laeuft = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final anzahl = state.anzahlVon(widget.bereich);

    // Am Rand kann es noch Älteres geben; sonst ist alles da.
    final gibtVielleichtMehr = state.amRand(widget.bereich);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
      child: Column(
        children: [
          Text(
            gibtVielleichtMehr
                ? '$anzahl Einträge geladen. Ältere sind gespeichert, '
                    'aber noch nicht geladen.'
                : 'Alle $anzahl Einträge geladen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (gibtVielleichtMehr) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _laeuft ? null : _laden,
              icon: _laeuft
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.history),
              label: Text(_laeuft ? 'Lädt …' : 'Ältere laden'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nach links wischen legt einen Löschknopf frei.
///
/// Bewusst zweistufig: Ein Wisch allein löscht nichts. Erst der Knopf
/// löst aus, und danach bleibt der Eintrag über „Rückgängig" noch eine
/// Weile erreichbar. Versehentliches Wischen in einer Liste passiert
/// oft genug, um es nicht mit Datenverlust zu bestrafen.
class SwipeZumLoeschen extends StatefulWidget {
  const SwipeZumLoeschen({
    super.key,
    required this.child,
    required this.onLoeschen,
  });

  final Widget child;
  final VoidCallback onLoeschen;

  @override
  State<SwipeZumLoeschen> createState() => _SwipeZumLoeschenState();
}

class _SwipeZumLoeschenState extends State<SwipeZumLoeschen> {
  /// Breite des freigelegten Knopfes.
  static const double _breite = 132;

  double _versatz = 0;
  bool _ziehend = false;

  bool get _offen => _versatz < -1;

  void _schliessen() => setState(() => _versatz = 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Ohne den Beschnitt schöbe sich der Zeileninhalt beim Wischen über
    // den Kartenrand hinaus statt darunter zu verschwinden.
    return ClipRect(
      child: Stack(
        children: [
          // Der Knopf entsteht erst beim Wischen – sonst läge er
          // unsichtbar unter jeder Zeile und würde Berührungen fangen.
          if (_offen)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: _breite,
                    child: Material(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _schliessen();
                          widget.onLoeschen();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: theme.colorScheme.onError),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Löschen',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: theme.colorScheme.onError),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Die Verschiebung liegt über der Wischfläche, nicht darunter:
          // Sonst bliebe die Fläche an ihrem Platz liegen und finge die
          // Berührungen des freigelegten Knopfes ab.
          AnimatedContainer(
            duration:
                _ziehend ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_versatz, 0, 0),
            child: GestureDetector(
              // Die ganze Zeile ist Wischfläche, nicht nur der Text.
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => setState(() => _ziehend = true),
              onHorizontalDragUpdate: (d) => setState(
                () => _versatz = (_versatz + d.delta.dx).clamp(-_breite, 0.0),
              ),
              onHorizontalDragEnd: (_) => setState(() {
                _ziehend = false;
                _versatz = _versatz < -_breite / 2 ? -_breite : 0;
              }),
              // Ist der Knopf offen, schließt eine Berührung der Zeile ihn
              // wieder, statt den Eintrag zu öffnen.
              onTap: _offen ? _schliessen : null,
              child: AbsorbPointer(absorbing: _offen, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Datum + Uhrzeit in einem Rutsch abfragen. Gibt null zurück, wenn
/// der Nutzer abbricht.
Future<DateTime?> pickDateTime(
  BuildContext context,
  DateTime initial,
) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2015),
    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
  );
  if (date == null || !context.mounted) return null;

  final time = await pickTime(context, TimeOfDay.fromDateTime(initial));
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Uhrzeit-Auswahl, immer im 24-Stunden-Format.
///
/// Ohne die Überschreibung richtet sich der Dialog nach der
/// Systemeinstellung des Geräts und zeigt auf manchen Handys AM/PM –
/// in einem Haushalt, in dem mehrere Personen dieselben Zeiten
/// eintragen, ist das eine Fehlerquelle.
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}

/// Reines Datum (ohne Uhrzeit) – für Geburtstag, Chip-Datum usw.
Future<DateTime?> pickDate(BuildContext context, DateTime? initial) {
  return showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(1990),
    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
  );
}
