import 'package:flutter/material.dart';

/// Anmeldung mit E-Mail und Passwort.
///
/// Die Konten legt der Halter in der Firebase-Konsole an – es gibt
/// bewusst keine Registrierung in der App. Sonst könnte sich jede
/// beliebige Person ein Konto anlegen und damit an die Daten kommen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSubmit,
    required this.onReset,
    this.fehler,
    this.hinweis,
    this.busy = false,
  });

  final Future<void> Function(String email, String passwort) onSubmit;
  final Future<void> Function(String email) onReset;

  /// Fehlermeldung der letzten Anmeldung, bereits in verständlichem
  /// Deutsch.
  final String? fehler;

  /// Bestätigung, etwa nach dem Versand einer Passwort-Mail.
  final String? hinweis;

  final bool busy;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _passwort = TextEditingController();
  bool _passwortSichtbar = false;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _passwort.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _passwort.dispose();
    super.dispose();
  }

  bool get _ausgefuellt =>
      _email.text.trim().contains('@') && _passwort.text.length >= 6;

  void _anmelden() {
    if (!_ausgefuellt || widget.busy) return;
    widget.onSubmit(_email.text.trim(), _passwort.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    'Anmelden',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alle angemeldeten Personen sehen denselben Stand – '
                    'Fütterung, Schlaf, Termine, alles.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-Mail',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwort,
                    obscureText: !_passwortSichtbar,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _anmelden(),
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _passwortSichtbar
                            ? 'Passwort verbergen'
                            : 'Passwort anzeigen',
                        onPressed: () => setState(
                          () => _passwortSichtbar = !_passwortSichtbar,
                        ),
                        icon: Icon(
                          _passwortSichtbar
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (widget.fehler != null) ...[
                    const SizedBox(height: 12),
                    _Meldung(
                      text: widget.fehler!,
                      farbe: theme.colorScheme.error,
                      icon: Icons.error_outline,
                    ),
                  ],
                  if (widget.hinweis != null) ...[
                    const SizedBox(height: 12),
                    _Meldung(
                      text: widget.hinweis!,
                      farbe: theme.colorScheme.primary,
                      icon: Icons.mark_email_read_outlined,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed:
                        _ausgefuellt && !widget.busy ? _anmelden : null,
                    child: Text(
                      widget.busy ? 'Einen Moment …' : 'Anmelden',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    // Ohne E-Mail-Adresse lässt sich keine Mail
                    // verschicken – deshalb erst dann anbietbar.
                    onPressed: _email.text.trim().contains('@') &&
                            !widget.busy
                        ? () => widget.onReset(_email.text.trim())
                        : null,
                    child: const Text('Passwort vergessen'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Neue Zugänge legt der Halter in der '
                    'Firebase-Konsole an.',
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

class _Meldung extends StatelessWidget {
  const _Meldung({
    required this.text,
    required this.farbe,
    required this.icon,
  });

  final String text;
  final Color farbe;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: farbe.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: farbe),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
