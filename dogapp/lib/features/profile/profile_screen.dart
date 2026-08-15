import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/dog_profile.dart';
import '../../state/app_state.dart';
import '../common/ui.dart';

/// Heimtierausweis: Stammdaten, Kennzeichnung (Chip), Halter und
/// Tierarzt inklusive Erreichbarkeit.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heimtierausweis'),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (p.isEmpty)
            Card(
              child: Column(
                children: [
                  const EmptyHint(
                    icon: Icons.badge_outlined,
                    text: 'Noch keine Daten hinterlegt.',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FilledButton.icon(
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Angaben eintragen'),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SectionCard(
              title: 'Zum Hund',
              icon: Icons.pets,
              child: _Facts(rows: [
                ('Name', p.name),
                ('Rasse', p.rasse),
                ('Geschlecht',
                    '${p.geschlecht.label}${p.kastriert ? ', kastriert' : ''}'),
                (
                  'Geburtsdatum',
                  p.geburtsdatum == null
                      ? ''
                      : '${dfDate.format(p.geburtsdatum!)} '
                          '(${formatAge(p.geburtsdatum!)})'
                ),
                ('Fellfarbe', p.fellfarbe),
                ('Besondere Kennzeichen', p.besondereKennzeichen),
                (
                  'Zielgewicht',
                  p.zielgewichtKg == null
                      ? ''
                      : '${nfWeight.format(p.zielgewichtKg!)} kg'
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Kennzeichnung',
              icon: Icons.memory_outlined,
              child: _Facts(rows: [
                ('Chipnummer', p.chipNummer),
                (
                  'Implantiert am',
                  p.chipDatum == null ? '' : dfDate.format(p.chipDatum!)
                ),
                ('Sitz des Chips', p.chipStelle),
                ('Tätowierung', p.taetowierung),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Ausweis',
              icon: Icons.badge_outlined,
              child: _Facts(rows: [
                ('Passnummer', p.passNummer),
                ('Ausgestellt von', p.passAusstellendeStelle),
                (
                  'Ausgestellt am',
                  p.passAusstellungsdatum == null
                      ? ''
                      : dfDate.format(p.passAusstellungsdatum!)
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Halter',
              icon: Icons.person_outline,
              child: _Facts(rows: [
                ('Name', p.halterName),
                ('Anschrift', p.halterAnschrift),
                ('Telefon', p.halterTelefon),
              ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Tierarzt',
              icon: Icons.local_hospital_outlined,
              child: _Facts(rows: [
                ('Praxis', p.tierarztPraxis),
                ('Ansprechpartner', p.tierarztName),
                ('Anschrift', p.tierarztAnschrift),
                ('Telefon', p.tierarztTelefon),
                ('Notfallnummer', p.tierarztNotfallTelefon),
                ('E-Mail', p.tierarztEmail),
                ('Sprechzeiten', p.tierarztSprechzeiten),
              ]),
            ),
            if (p.notizen.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: 'Notizen',
                icon: Icons.sticky_note_2_outlined,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(p.notizen),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Zeigt nur die Zeilen, die auch ausgefüllt sind – ein Ausweis voller
/// Bindestriche liest sich schlecht.
class _Facts extends StatelessWidget {
  const _Facts({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = rows.where((r) => r.$2.trim().isNotEmpty).toList();

    if (visible.isEmpty) {
      return const EmptyHint(text: 'Keine Angaben.');
    }

    return Column(
      children: [
        for (final row in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    row.$1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _openEditor(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const _ProfileEditor()),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor();

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final Map<String, TextEditingController> _c = {};

  late DogProfile _p;

  @override
  void initState() {
    super.initState();
    _p = context.read<AppState>().profile;
  }

  TextEditingController _ctrl(String key, String initial) =>
      _c.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final zielRaw = _ctrl('ziel', '').text.trim().replaceAll(',', '.');
    final ziel = zielRaw.isEmpty ? null : double.tryParse(zielRaw);

    final updated = _p.copyWith(
      name: _ctrl('name', '').text.trim(),
      rasse: _ctrl('rasse', '').text.trim(),
      fellfarbe: _ctrl('fellfarbe', '').text.trim(),
      besondereKennzeichen: _ctrl('kennzeichen', '').text.trim(),
      zielgewichtKg: ziel,
      clearZielgewicht: ziel == null,
      chipNummer: _ctrl('chip', '').text.trim(),
      chipStelle: _ctrl('chipStelle', '').text.trim(),
      taetowierung: _ctrl('tattoo', '').text.trim(),
      passNummer: _ctrl('pass', '').text.trim(),
      passAusstellendeStelle: _ctrl('passStelle', '').text.trim(),
      halterName: _ctrl('halterName', '').text.trim(),
      halterAnschrift: _ctrl('halterAnschrift', '').text.trim(),
      halterTelefon: _ctrl('halterTelefon', '').text.trim(),
      tierarztPraxis: _ctrl('taPraxis', '').text.trim(),
      tierarztName: _ctrl('taName', '').text.trim(),
      tierarztAnschrift: _ctrl('taAnschrift', '').text.trim(),
      tierarztTelefon: _ctrl('taTelefon', '').text.trim(),
      tierarztNotfallTelefon: _ctrl('taNotfall', '').text.trim(),
      tierarztEmail: _ctrl('taMail', '').text.trim(),
      tierarztSprechzeiten: _ctrl('taZeiten', '').text.trim(),
      notizen: _ctrl('notizen', '').text.trim(),
    );

    await context.read<AppState>().saveProfile(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Angaben bearbeiten'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionCard(
            title: 'Zum Hund',
            icon: Icons.pets,
            child: Column(
              children: [
                _field('name', 'Name', _p.name),
                _field('rasse', 'Rasse', _p.rasse),
                const SizedBox(height: 12),
                SegmentedButton<Geschlecht>(
                  segments: [
                    for (final g in Geschlecht.values)
                      ButtonSegment(value: g, label: Text(g.label)),
                  ],
                  selected: {_p.geschlecht},
                  onSelectionChanged: (s) =>
                      setState(() => _p = _p.copyWith(geschlecht: s.first)),
                  showSelectedIcon: false,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kastriert / sterilisiert'),
                  value: _p.kastriert,
                  onChanged: (v) =>
                      setState(() => _p = _p.copyWith(kastriert: v)),
                ),
                _dateField(
                  label: 'Geburtsdatum',
                  value: _p.geburtsdatum,
                  onPick: (d) => setState(
                    () => _p = _p.copyWith(
                      geburtsdatum: d,
                      clearGeburtsdatum: d == null,
                    ),
                  ),
                ),
                _field('fellfarbe', 'Fellfarbe', _p.fellfarbe),
                _field(
                  'kennzeichen',
                  'Besondere Kennzeichen',
                  _p.besondereKennzeichen,
                ),
                _field(
                  'ziel',
                  'Zielgewicht in kg (optional)',
                  _p.zielgewichtKg == null
                      ? ''
                      : nfWeight.format(_p.zielgewichtKg!),
                  keyboard:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Kennzeichnung',
            icon: Icons.memory_outlined,
            child: Column(
              children: [
                _field(
                  'chip',
                  'Chipnummer (15-stellig)',
                  _p.chipNummer,
                  keyboard: TextInputType.number,
                ),
                _dateField(
                  label: 'Implantiert am',
                  value: _p.chipDatum,
                  onPick: (d) => setState(
                    () => _p = _p.copyWith(
                      chipDatum: d,
                      clearChipDatum: d == null,
                    ),
                  ),
                ),
                _field('chipStelle', 'Sitz des Chips', _p.chipStelle),
                _field('tattoo', 'Tätowierung', _p.taetowierung),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Ausweis',
            icon: Icons.badge_outlined,
            child: Column(
              children: [
                _field('pass', 'Passnummer', _p.passNummer),
                _field(
                  'passStelle',
                  'Ausgestellt von',
                  _p.passAusstellendeStelle,
                ),
                _dateField(
                  label: 'Ausgestellt am',
                  value: _p.passAusstellungsdatum,
                  onPick: (d) => setState(
                    () => _p = _p.copyWith(
                      passAusstellungsdatum: d,
                      clearPassAusstellungsdatum: d == null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Halter',
            icon: Icons.person_outline,
            child: Column(
              children: [
                _field('halterName', 'Name', _p.halterName),
                _field(
                  'halterAnschrift',
                  'Anschrift',
                  _p.halterAnschrift,
                  lines: 2,
                ),
                _field(
                  'halterTelefon',
                  'Telefon',
                  _p.halterTelefon,
                  keyboard: TextInputType.phone,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Tierarzt',
            icon: Icons.local_hospital_outlined,
            child: Column(
              children: [
                _field('taPraxis', 'Praxis', _p.tierarztPraxis),
                _field('taName', 'Ansprechpartner', _p.tierarztName),
                _field(
                  'taAnschrift',
                  'Anschrift',
                  _p.tierarztAnschrift,
                  lines: 2,
                ),
                _field(
                  'taTelefon',
                  'Telefon',
                  _p.tierarztTelefon,
                  keyboard: TextInputType.phone,
                ),
                _field(
                  'taNotfall',
                  'Notfallnummer',
                  _p.tierarztNotfallTelefon,
                  keyboard: TextInputType.phone,
                ),
                _field(
                  'taMail',
                  'E-Mail',
                  _p.tierarztEmail,
                  keyboard: TextInputType.emailAddress,
                ),
                _field(
                  'taZeiten',
                  'Sprechzeiten',
                  _p.tierarztSprechzeiten,
                  lines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Notizen',
            icon: Icons.sticky_note_2_outlined,
            child: _field(
              'notizen',
              'Allergien, Auffälligkeiten, Versicherung …',
              _p.notizen,
              lines: 4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    String initial, {
    int lines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: _ctrl(key, initial),
        maxLines: lines,
        keyboardType: keyboard,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickDate(context, value);
                if (picked != null) onPick(picked);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                value == null ? label : '$label: ${dfDate.format(value)}',
              ),
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Datum entfernen',
              onPressed: () => onPick(null),
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    );
  }
}
