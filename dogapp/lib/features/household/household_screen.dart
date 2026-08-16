import 'package:flutter/material.dart';

import '../../data/haushalt.dart';

/// Erste Einrichtung auf einem Gerät: Haushalts-Code eingeben.
///
/// Wer denselben Code eintippt, sieht dieselben Daten. Das ersetzt
/// bewusst die Benutzerkonten – für zwei, drei Personen, die sich
/// ohnehin persönlich kennen, ist ein abgesprochenes Wort der
/// kürzeste Weg.
class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({
    super.key,
    required this.onSubmit,
    required this.onSkip,
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback onSkip;

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final TextEditingController _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalisiert = Haushalt.normalisiere(_code.text);
    final gueltig = Haushalt.istGueltig(_code.text);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.pets,
                      size: 34,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Willkommen',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gib das gemeinsame Codewort ein. Alle Geräte mit '
                    'demselben Codewort sehen denselben Stand – '
                    'Fütterung, Schlaf, Termine, alles.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _code,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (gueltig) widget.onSubmit(_code.text);
                    },
                    decoration: InputDecoration(
                      labelText: 'Codewort',
                      hintText: 'z. B. bheki-zuhause',
                      helperText: normalisiert.isEmpty
                          ? 'Mindestens ${Haushalt.minLaenge} Zeichen'
                          : 'Wird gespeichert als: $normalisiert',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        gueltig ? () => widget.onSubmit(_code.text) : null,
                    child: const Text('Loslegen'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onSkip,
                    child: const Text('Erst mal nur auf diesem Gerät'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Wähle etwas, das nicht zu erraten ist. Wer Link und '
                    'Codewort kennt, kann die Einträge sehen und ändern.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
