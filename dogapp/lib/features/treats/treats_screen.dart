import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/treat.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Leckerli-Übersicht: was darf er, und was mag er.
///
/// Die „Darf er nicht"-Gruppe steht bewusst mit in der Liste – sie ist
/// der eigentliche Grund, warum so eine Übersicht nützlich ist, wenn
/// mehrere Personen mit dem Hund arbeiten.
class TreatsScreen extends StatelessWidget {
  const TreatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alle = state.treats;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Eindeutige Kennung: Alle Reiter liegen gleichzeitig im
        // Baum, ohne sie stolpert die Übergangsanimation über
        // mehrere gleich benannte Knöpfe.
        heroTag: 'fab-leckerli',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Leckerli'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (alle.isEmpty)
            Card(
              child: Column(
                children: [
                  const EmptyHint(
                    icon: Icons.cookie_outlined,
                    text: 'Noch keine Leckerli-Liste.\n'
                        'Die Startliste bringt gängige Snacks mit –\n'
                        'inklusive der Sachen, die er nicht bekommen darf.',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FilledButton.icon(
                      onPressed: () => context.read<AppState>().seedTreats(),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Startliste laden'),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final erlaubnis in Erlaubnis.values)
              if (alle.any((t) => t.erlaubt == erlaubnis)) ...[
                SectionCard(
                  title: erlaubnis.label,
                  icon: switch (erlaubnis) {
                    Erlaubnis.ja => Icons.check_circle_outline,
                    Erlaubnis.inMassen => Icons.warning_amber_outlined,
                    Erlaubnis.nein => Icons.block,
                  },
                  child: Column(
                    children: [
                      for (final t
                          in alle.where((t) => t.erlaubt == erlaubnis))
                        _TreatTile(treat: t),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
        ],
      ),
    );
  }
}

class _TreatTile extends StatelessWidget {
  const _TreatTile({required this.treat});

  final Treat treat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verboten = treat.erlaubt == Erlaubnis.nein;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _openEditor(context, entry: treat),
      title: Text(
        treat.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: treat.notiz.isEmpty ? null : Text(treat.notiz),
      trailing: verboten
          ? Icon(Icons.block, color: theme.colorScheme.error)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 3; i++)
                  Icon(
                    i <= treat.beliebtheit
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
              ],
            ),
    );
  }
}

Future<void> _openEditor(BuildContext context, {Treat? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TreatEditor(entry: entry),
  );
}

class _TreatEditor extends StatefulWidget {
  const _TreatEditor({this.entry});

  final Treat? entry;

  @override
  State<_TreatEditor> createState() => _TreatEditorState();
}

class _TreatEditorState extends State<_TreatEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.entry?.name ?? '');
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');

  late Erlaubnis _erlaubt = widget.entry?.erlaubt ?? Erlaubnis.ja;
  late int _beliebtheit = widget.entry?.beliebtheit ?? 2;

  @override
  void dispose() {
    _name.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = widget.entry ?? Treat(name: _name.text.trim());
    await context.read<AppState>().saveTreat(
          base.copyWith(
            name: _name.text.trim(),
            erlaubt: _erlaubt,
            beliebtheit: _beliebtheit,
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
              widget.entry == null ? 'Neues Leckerli' : 'Leckerli bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.entry == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Was'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<Erlaubnis>(
              segments: [
                for (final e in Erlaubnis.values)
                  ButtonSegment(value: e, label: Text(e.label)),
              ],
              selected: {_erlaubt},
              onSelectionChanged: (s) => setState(() => _erlaubt = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            if (_erlaubt != Erlaubnis.nein) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mag er',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 1; i <= 3; i++)
                    IconButton(
                      onPressed: () => setState(() => _beliebtheit = i),
                      icon: Icon(
                        i <= _beliebtheit
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  TextButton(
                    onPressed: () => setState(() => _beliebtheit = 0),
                    child: const Text('mag er nicht'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: 'z. B. nur kleine Stücke, nicht vor dem Training',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Speichern')),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await context.read<AppState>().deleteTreat(widget.entry!.id);
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
