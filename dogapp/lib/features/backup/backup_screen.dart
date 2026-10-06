import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dateien.dart';
import '../../data/sicherung.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Sicherung herunterladen und einspielen.
///
/// Der Grund für diesen Bildschirm: Ohne Export existieren die Daten
/// genau einmal, nämlich bei Google. Ein Hundeleben dauert länger als
/// so manches Rechenzentrumsversprechen.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _meldung;
  bool _fehler = false;

  void _sag(String text, {bool fehler = false}) {
    if (!mounted) return;
    setState(() {
      _meldung = text;
      _fehler = fehler;
    });
  }

  Future<void> _exportieren() async {
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _meldung = null;
    });

    try {
      final daten = await state.sicherungErstellen();
      final name = sicherungsDateiname(state.profile.name, DateTime.now());
      await speichereDatei(name, daten, 'application/json');
      _sag(
        '$name wurde heruntergeladen (${_groesse(daten.length)}). '
        'Leg die Datei irgendwohin, wo sie nicht verlorengeht.',
      );
    } catch (e) {
      _sag('Der Export hat nicht geklappt: $e', fehler: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importieren() async {
    final state = context.read<AppState>();

    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sicherung einspielen?'),
        content: const Text(
          'Die Einträge aus der Datei werden hinzugefügt. Einträge mit '
          'derselben Kennung werden dabei durch die Fassung aus der '
          'Datei ersetzt.\n\n'
          'Was nur hier steht und nicht in der Datei, bleibt erhalten – '
          'ein Import kann also nichts wegwerfen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Datei wählen'),
          ),
        ],
      ),
    );
    if (!(bestaetigt ?? false)) return;

    setState(() {
      _busy = true;
      _meldung = null;
    });

    try {
      final daten = await waehleDatei('.json,application/json');
      if (daten == null) {
        _sag('Keine Datei gewählt.');
        return;
      }
      final bericht = await state.sicherungEinspielen(daten);
      _sag('Eingespielt: ${bericht.zusammenfassung}.');
    } on SicherungsFehler catch (e) {
      _sag(e.nachricht, fehler: true);
    } catch (e) {
      _sag('Das Einspielen hat nicht geklappt: $e', fehler: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _groesse(int bytes) {
    if (bytes < 1024) return '$bytes Byte';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} kB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sicherung')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionCard(
            title: 'Sicherung herunterladen',
            icon: Icons.download_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Lädt den kompletten Bestand als eine Datei herunter – '
                  'alle Einträge, der Heimtierausweis und sämtliche Fotos. '
                  'Die Datei ist lesbarer Text; man kommt auch ohne diese '
                  'App an den Inhalt.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Gesichert wird immer alles, unabhängig davon, wie viel '
                  'gerade geladen ist.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _exportieren,
                  icon: const Icon(Icons.download),
                  label: const Text('Herunterladen'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Sicherung einspielen',
            icon: Icons.upload_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Liest eine zuvor heruntergeladene Datei wieder ein – '
                  'etwa auf einem neuen Gerät oder nachdem etwas '
                  'schiefgegangen ist.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _importieren,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Datei einspielen'),
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_meldung != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_fehler
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_fehler
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _fehler ? Icons.error_outline : Icons.check_circle_outline,
                    size: 18,
                    color: _fehler
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_meldung!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            state.isShared
                ? 'Die Daten liegen zusätzlich in der Cloud. Eine eigene '
                    'Sicherung ist trotzdem sinnvoll: Sie gehört dir und '
                    'überlebt auch ein gelöschtes Konto.'
                : 'Die Daten liegen nur in diesem Browser. Ohne Sicherung '
                    'sind sie weg, sobald jemand die Website-Daten löscht.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
