import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/training.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Training in drei Reitern: was heute dran ist, der Übungskatalog mit
/// Trainingsstand, und die Pläne, die bestimmen was „heute dran" ist.
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Training'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Heute'),
              Tab(text: 'Übungen'),
              Tab(text: 'Pläne'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HeuteTab(),
            _UebungenTab(),
            _PlaeneTab(),
          ],
        ),
      ),
    );
  }
}

// --- Heute ------------------------------------------------------------

class _HeuteTab extends StatelessWidget {
  const _HeuteTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final heute = DateTime.now();
    final uebungen = state.heutigeUebungen;
    final erledigt = uebungen.where((e) => state.istGeuebt(e.id, heute)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SectionCard(
          title: 'Trainingsstand',
          icon: Icons.insights_outlined,
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Heute geübt',
                  value: uebungen.isEmpty
                      ? '${state.geuebtHeute()}'
                      : '$erledigt/${uebungen.length}',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Letzte 7 Tage',
                  value: '${state.trainingstageZuletzt()} Tage',
                  hint: 'mit Training',
                  icon: Icons.calendar_month_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.exercises.isEmpty)
          Card(
            child: Column(
              children: [
                const EmptyHint(
                  icon: Icons.school_outlined,
                  text: 'Noch keine Übungen angelegt.\n'
                      'Der Startkatalog bringt die Grundlagen mit –\n'
                      'ändern und ergänzen kannst du danach alles.',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton.icon(
                    onPressed: () => state.seedExercises(),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Startkatalog laden'),
                  ),
                ),
              ],
            ),
          )
        else if (uebungen.isEmpty)
          const Card(
            child: EmptyHint(
              icon: Icons.playlist_add_check_outlined,
              text: 'Für heute steht nichts fest.\n'
                  'Setz eine Übung auf „In Arbeit" oder leg unter\n'
                  '„Pläne" einen Trainingsplan an.',
            ),
          )
        else
          SectionCard(
            title: 'Heute dran',
            icon: Icons.checklist_outlined,
            child: Column(
              children: [
                for (final u in uebungen)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.istGeuebt(u.id, heute),
                    onChanged: (_) => state.toggleUebung(u.id, heute),
                    title: Text(
                      u.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: u.beschreibung.isEmpty
                        ? null
                        : Text(u.beschreibung),
                    isThreeLine: u.beschreibung.length > 60,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// --- Übungskatalog ----------------------------------------------------

class _UebungenTab extends StatelessWidget {
  const _UebungenTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExerciseEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Übung'),
      ),
      body: state.exercises.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Card(
                  child: Column(
                    children: [
                      const EmptyHint(
                        icon: Icons.school_outlined,
                        text: 'Noch keine Übungen angelegt.',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: FilledButton.icon(
                          onPressed: () => state.seedExercises(),
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Startkatalog laden'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final gruppe in TrainingGruppe.values)
                  if (state.exercisesInGruppe(gruppe).isNotEmpty) ...[
                    SectionCard(
                      title: gruppe.label,
                      icon: Icons.folder_outlined,
                      child: Column(
                        children: [
                          for (final u in state.exercisesInGruppe(gruppe))
                            _ExerciseTile(uebung: u),
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

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.uebung});

  final TrainingExercise uebung;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = switch (uebung.stand) {
      Trainingsstand.offen => theme.colorScheme.outline,
      Trainingsstand.inArbeit => theme.colorScheme.secondary,
      Trainingsstand.sitzt => theme.colorScheme.primary,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _openExerciseEditor(context, entry: uebung),
      leading: Icon(
        switch (uebung.stand) {
          Trainingsstand.offen => Icons.radio_button_unchecked,
          Trainingsstand.inArbeit => Icons.timelapse,
          Trainingsstand.sitzt => Icons.check_circle,
        },
        color: farbe,
      ),
      title: Text(
        uebung.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        uebung.beschreibung.isEmpty
            ? uebung.stand.label
            : '${uebung.stand.label} · ${uebung.beschreibung}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

Future<void> _openExerciseEditor(
  BuildContext context, {
  TrainingExercise? entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExerciseEditor(entry: entry),
  );
}

class _ExerciseEditor extends StatefulWidget {
  const _ExerciseEditor({this.entry});

  final TrainingExercise? entry;

  @override
  State<_ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<_ExerciseEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.entry?.name ?? '');
  late final TextEditingController _beschreibung =
      TextEditingController(text: widget.entry?.beschreibung ?? '');
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');

  late TrainingGruppe _gruppe =
      widget.entry?.gruppe ?? TrainingGruppe.grundlagen;
  late Trainingsstand _stand = widget.entry?.stand ?? Trainingsstand.offen;

  @override
  void dispose() {
    _name.dispose();
    _beschreibung.dispose();
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = widget.entry ?? TrainingExercise(name: _name.text.trim());
    await context.read<AppState>().saveExercise(
          base.copyWith(
            name: _name.text.trim(),
            gruppe: _gruppe,
            stand: _stand,
            beschreibung: _beschreibung.text.trim(),
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
              widget.entry == null ? 'Neue Übung' : 'Übung bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.entry == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in TrainingGruppe.values)
                  ChoiceChip(
                    label: Text(g.label),
                    selected: _gruppe == g,
                    onSelected: (_) => setState(() => _gruppe = g),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<Trainingsstand>(
              segments: [
                for (final s in Trainingsstand.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_stand},
              onSelectionChanged: (s) => setState(() => _stand = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _beschreibung,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Worauf es ankommt',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Eigene Notiz (optional)',
                hintText: 'z. B. klappt drinnen, draußen noch nicht',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Speichern')),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await context
                      .read<AppState>()
                      .deleteExercise(widget.entry!.id);
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

// --- Pläne ------------------------------------------------------------

class _PlaeneTab extends StatelessWidget {
  const _PlaeneTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.exercises.isEmpty
            ? null
            : () => _openPlanEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Plan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (state.plans.isEmpty)
            Card(
              child: EmptyHint(
                icon: Icons.playlist_add_outlined,
                text: state.exercises.isEmpty
                    ? 'Erst Übungen anlegen, dann lassen sie sich zu\n'
                        'einem Plan zusammenstellen.'
                    : 'Noch kein Plan.\n'
                        'Ein Plan bestimmt, was im Reiter „Heute"\n'
                        'zum Abhaken steht.',
              ),
            )
          else
            for (final plan in state.plans) ...[
              _PlanCard(plan: plan),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final TrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final heute = DateTime.now();
    final uebungen = plan.uebungIds
        .map(state.exerciseById)
        .whereType<TrainingExercise>()
        .toList();
    final erledigt =
        uebungen.where((u) => state.istGeuebt(u.id, heute)).length;

    return SectionCard(
      title: plan.titel,
      icon: plan.aktiv ? Icons.play_circle_outline : Icons.pause_circle_outline,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$erledigt/${uebungen.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          IconButton(
            tooltip: 'Bearbeiten',
            onPressed: () => _openPlanEditor(context, entry: plan),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.beschreibung.isNotEmpty) ...[
            Text(plan.beschreibung),
            const SizedBox(height: 8),
          ],
          if (uebungen.isEmpty)
            const EmptyHint(text: 'Keine Übungen im Plan.')
          else
            for (final u in uebungen)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: state.istGeuebt(u.id, heute),
                onChanged: (_) => state.toggleUebung(u.id, heute),
                title: Text(u.name),
              ),
        ],
      ),
    );
  }
}

Future<void> _openPlanEditor(BuildContext context, {TrainingPlan? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlanEditor(entry: entry),
  );
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({this.entry});

  final TrainingPlan? entry;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late final TextEditingController _titel =
      TextEditingController(text: widget.entry?.titel ?? '');
  late final TextEditingController _beschreibung =
      TextEditingController(text: widget.entry?.beschreibung ?? '');

  late final Set<String> _ausgewaehlt = {
    ...(widget.entry?.uebungIds ?? const <String>[]),
  };
  late bool _aktiv = widget.entry?.aktiv ?? true;

  @override
  void dispose() {
    _titel.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = widget.entry ?? TrainingPlan(titel: _titel.text.trim());
    await context.read<AppState>().savePlan(
          base.copyWith(
            titel: _titel.text.trim(),
            beschreibung: _beschreibung.text.trim(),
            uebungIds: _ausgewaehlt.toList(),
            aktiv: _aktiv,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

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
              widget.entry == null ? 'Neuer Plan' : 'Plan bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titel,
              autofocus: widget.entry == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'z. B. Woche 1 – Grundsignale',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _beschreibung,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Beschreibung (optional)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktiv'),
              subtitle:
                  const Text('Aktive Pläne füllen den Reiter „Heute".'),
              value: _aktiv,
              onChanged: (v) => setState(() => _aktiv = v),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Übungen im Plan',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final gruppe in TrainingGruppe.values)
              if (state.exercisesInGruppe(gruppe).isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Text(
                    gruppe.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                for (final u in state.exercisesInGruppe(gruppe))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _ausgewaehlt.contains(u.id),
                    onChanged: (v) => setState(() {
                      if (v ?? false) {
                        _ausgewaehlt.add(u.id);
                      } else {
                        _ausgewaehlt.remove(u.id);
                      }
                    }),
                    title: Text(u.name),
                  ),
              ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Speichern')),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await context.read<AppState>().deletePlan(widget.entry!.id);
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
