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
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
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
