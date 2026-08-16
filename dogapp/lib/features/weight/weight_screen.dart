import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/photo.dart';
import '../../models/weight_entry.dart';
import '../../state/app_state.dart';
import '../common/dog_photo.dart';
import '../common/ui.dart';

/// Welche Reihe das Diagramm zeigt. Gewicht und Größe in ein Diagramm
/// zu zwingen, hieße zwei völlig verschiedene Wertebereiche auf eine
/// Achse zu legen – der Verlauf sähe dann dramatischer oder flacher
/// aus, als er ist.
enum _Reihe {
  gewicht('Gewicht', 'kg'),
  groesse('Größe', 'cm');

  const _Reihe(this.label, this.einheit);

  final String label;
  final String einheit;
}

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  _Reihe _reihe = _Reihe.gewicht;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.weights;
    final letztes = state.letztesGewicht;
    final letzteGroesse = state.letzteGroesse;
    final diff = state.gewichtsDifferenz;
    final groessenDiff = state.groessenDifferenz;
    final fotos = state.fotoVerlauf;

    final reihenDaten = _reihe == _Reihe.gewicht
        ? entries
        : state.groessenMessungen;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Eindeutige Kennung: Alle Reiter liegen gleichzeitig im
        // Baum, ohne sie stolpert die Übergangsanimation über
        // mehrere gleich benannte Knöpfe.
        heroTag: 'fab-messung',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Messung'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionCard(
            title: 'Aktueller Stand',
            icon: Icons.straighten_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Gewicht',
                        value: letztes?.gewichtLabel ?? '–',
                        hint: letztes == null
                            ? null
                            : dfDate.format(letztes.zeitpunkt),
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Größe',
                        value: letzteGroesse?.groesseLabel ?? '–',
                        hint: letzteGroesse == null
                            ? 'noch nicht gemessen'
                            : dfDate.format(letzteGroesse.zeitpunkt),
                        icon: Icons.height,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Zugenommen',
                        value: _differenzLabel(diff, 'kg'),
                        hint: 'seit der Messung davor',
                        icon: _trendIcon(diff),
                        color: _trendFarbe(context, diff),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Gewachsen',
                        value: _differenzLabel(groessenDiff, 'cm'),
                        hint: 'seit der Messung davor',
                        icon: _trendIcon(groessenDiff),
                        color: _trendFarbe(context, groessenDiff),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Verlauf',
            icon: Icons.show_chart,
            child: Column(
              children: [
                SegmentedButton<_Reihe>(
                  segments: [
                    for (final r in _Reihe.values)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {_reihe},
                  onSelectionChanged: (s) =>
                      setState(() => _reihe = s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 16),
                if (reihenDaten.length < 2)
                  EmptyHint(
                    text: _reihe == _Reihe.gewicht
                        ? 'Ab der zweiten Messung entsteht hier eine Kurve.'
                        : 'Trag bei einer Messung die Widerristhöhe mit '
                            'ein –\nab dem zweiten Wert entsteht die Kurve.',
                  )
                else
                  SizedBox(
                    height: 190,
                    child: _VerlaufChart(
                      entries: reihenDaten,
                      reihe: _reihe,
                      ziel: _reihe == _Reihe.gewicht
                          ? state.profile.zielgewichtKg
                          : state.profile.zielgroesseCm,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (fotos.length >= 2) ...[
            SectionCard(
              title: 'Fotoverlauf',
              icon: Icons.photo_library_outlined,
              child: SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _FotoKachel(entry: fotos[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (entries.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.monitor_weight_outlined,
                text: 'Noch keine Messung.\n'
                    'Gewicht, Größe und ein Foto zusammen erfassen –\n'
                    'so entsteht ein Entwicklungsverlauf.',
              ),
            )
          else ...[
            Card(
              child: Column(
                children: [
                  for (final e in entries) _WeightTile(entry: e),
                ],
              ),
            ),
            const MehrLaden(bereich: Bereich.gewicht),
          ],
        ],
      ),
    );
  }

  static String _differenzLabel(double? wert, String einheit) {
    if (wert == null) return '–';
    final vorzeichen = wert >= 0 ? '+' : '−';
    return '$vorzeichen${nfWeight.format(wert.abs())} $einheit';
  }

  static IconData _trendIcon(double? wert) {
    if (wert == null) return Icons.remove;
    return wert >= 0 ? Icons.trending_up : Icons.trending_down;
  }

  static Color? _trendFarbe(BuildContext context, double? wert) {
    if (wert == null || wert.abs() < 0.05) return null;
    return Theme.of(context).colorScheme.secondary;
  }
}

/// Ein Foto im Verlaufsstreifen, mit Datum und Alter darunter.
class _FotoKachel extends StatelessWidget {
  const _FotoKachel({required this.entry});

  final WeightEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final geburtstag = context.read<AppState>().profile.geburtsdatum;

    return GestureDetector(
      onTap: () => showPhotoDialog(
        context,
        entry.fotoRef!,
        '${entry.gewichtLabel}'
        '${entry.groesseLabel == null ? '' : ' · ${entry.groesseLabel}'}'
        ' · ${dfDate.format(entry.zeitpunkt)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DogPhoto(fotoRef: entry.fotoRef!, size: 96),
          const SizedBox(height: 4),
          Text(
            dfShortDay.format(entry.zeitpunkt),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            geburtstag == null
                ? entry.gewichtLabel
                : formatAge(geburtstag, now: entry.zeitpunkt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightTile extends StatelessWidget {
  const _WeightTile({required this.entry});

  final WeightEntry entry;

  @override
  Widget build(BuildContext context) {
    final untertitel = <String>[
      '${dfDateTime.format(entry.zeitpunkt)} Uhr',
      if (entry.groesseLabel != null) entry.groesseLabel!,
    ].join(' · ');

    return ListTile(
      onTap: () => _openEditor(context, entry: entry),
      leading: entry.hatFoto
          ? GestureDetector(
              onTap: () => showPhotoDialog(
                context,
                entry.fotoRef!,
                '${entry.gewichtLabel} · ${dfDate.format(entry.zeitpunkt)}',
              ),
              child: DogPhoto(fotoRef: entry.fotoRef!),
            )
          : Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
      title: Text(
        entry.gewichtLabel,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        entry.notiz.isEmpty ? untertitel : '$untertitel\n${entry.notiz}',
      ),
      isThreeLine: entry.notiz.isNotEmpty,
    );
  }
}

/// Verlauf über die Zeit. X ist der Tag als Zahl, damit ungleichmäßige
/// Abstände zwischen zwei Messungen auch im Diagramm ungleichmäßig
/// aussehen.
class _VerlaufChart extends StatelessWidget {
  const _VerlaufChart({
    required this.entries,
    required this.reihe,
    this.ziel,
  });

  final List<WeightEntry> entries;
  final _Reihe reihe;
  final double? ziel;

  double _wert(WeightEntry e) =>
      reihe == _Reihe.gewicht ? e.gewichtKg : e.groesseCm!;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final sorted = [...entries]
      ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
    final first = startOfDay(sorted.first.zeitpunkt);

    double toX(DateTime d) => d.difference(first).inMinutes / (60 * 24);

    final spots = [
      for (final e in sorted) FlSpot(toX(e.zeitpunkt), _wert(e)),
    ];

    final values = [
      ...sorted.map(_wert),
      if (ziel != null) ziel!,
    ];
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(0.2, 5.0);
    minY -= pad;
    maxY += pad;

    final maxX = spots.last.x == 0 ? 1.0 : spots.last.x;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                nfAmount.format(value),
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: maxX <= 0 ? 1 : maxX / 2,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  dfShortDay
                      .format(first.add(Duration(days: value.round()))),
                  style:
                      TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2.5,
            color: scheme.primary,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.14),
            ),
          ),
        ],
        extraLinesData: ziel == null
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: ziel!,
                    color: scheme.secondary,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (_) => 'Ziel',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${nfWeight.format(s.y)} ${reihe.einheit}\n'
                    '${dfDate.format(first.add(Duration(days: s.x.round())))}',
                    TextStyle(color: scheme.onSurface, fontSize: 11),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context, {WeightEntry? entry}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WeightEditor(entry: entry),
  );
}

class _WeightEditor extends StatefulWidget {
  const _WeightEditor({this.entry});

  final WeightEntry? entry;

  @override
  State<_WeightEditor> createState() => _WeightEditorState();
}

class _WeightEditorState extends State<_WeightEditor> {
  late final TextEditingController _gewicht = TextEditingController(
    text: widget.entry == null ? '' : nfWeight.format(widget.entry!.gewichtKg),
  );
  late final TextEditingController _groesse = TextEditingController(
    text: widget.entry?.groesseCm == null
        ? ''
        : nfAmount.format(widget.entry!.groesseCm),
  );
  late final TextEditingController _notiz =
      TextEditingController(text: widget.entry?.notiz ?? '');

  late DateTime _zeitpunkt = widget.entry?.zeitpunkt ?? DateTime.now();

  /// Neu aufgenommenes Foto, das noch nicht gespeichert ist.
  Uint8List? _neuesFoto;
  late String? _fotoRef = widget.entry?.fotoRef;
  bool _busy = false;

  @override
  void dispose() {
    _gewicht.dispose();
    _groesse.dispose();
    _notiz.dispose();
    super.dispose();
  }

  static double? _zahl(String text) {
    final bereinigt = text.trim().replaceAll(',', '.');
    if (bereinigt.isEmpty) return null;
    return double.tryParse(bereinigt);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 92);
    if (file == null) return;

    setState(() => _busy = true);
    final raw = await file.readAsBytes();
    final shrunk = shrinkPhoto(raw);
    if (!mounted) return;
    setState(() {
      _neuesFoto = shrunk ?? raw;
      _busy = false;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final state = context.read<AppState>();
    final gewicht = _zahl(_gewicht.text) ?? 0;
    final groesse = _zahl(_groesse.text);

    final base = widget.entry ??
        WeightEntry(zeitpunkt: _zeitpunkt, gewichtKg: gewicht);

    var ref = _fotoRef;
    if (_neuesFoto != null) {
      // Foto unter der Eintrags-ID ablegen – ein Bild pro Messung,
      // ein Ersetzen überschreibt sauber das alte.
      ref = await state.storePhoto(base.id, _neuesFoto!);
      DogPhoto.evict(ref);
    }

    // Beim Entfernen soll das Bild auch aus dem Speicher verschwinden,
    // sonst bleibt es als Leiche zurück.
    final alt = widget.entry?.fotoRef;
    if (alt != null && ref == null) {
      DogPhoto.evict(alt);
      await state.removePhoto(alt);
    }

    await state.saveWeight(
      base.copyWith(
        zeitpunkt: _zeitpunkt,
        gewichtKg: gewicht,
        groesseCm: groesse,
        clearGroesse: groesse == null,
        fotoRef: ref,
        clearFoto: ref == null,
        notiz: _notiz.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final gewichtOk = (_zahl(_gewicht.text) ?? 0) > 0;

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
              widget.entry == null ? 'Neue Messung' : 'Messung bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gewicht,
                    autofocus: widget.entry == null,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Gewicht',
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _groesse,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Größe',
                      suffixText: 'cm',
                      helperText: 'optional',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Größe = Widerristhöhe: vom Boden bis zum höchsten Punkt '
              'der Schulterblätter, im Stehen.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickDateTime(context, _zeitpunkt);
                if (picked != null) setState(() => _zeitpunkt = picked);
              },
              icon: const Icon(Icons.schedule),
              label: Text('${dfDateTime.format(_zeitpunkt)} Uhr'),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_neuesFoto != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _neuesFoto!,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_fotoRef != null)
                  DogPhoto(fotoRef: _fotoRef!, size: 84)
                else
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.pets,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Foto aufnehmen'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Aus Galerie'),
                      ),
                      if (_neuesFoto != null || _fotoRef != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _neuesFoto = null;
                            _fotoRef = null;
                          }),
                          child: const Text('Foto entfernen'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notiz,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                hintText: 'z. B. nach dem Spaziergang gewogen',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || !gewichtOk ? null : _save,
              child: Text(_busy ? 'Einen Moment …' : 'Speichern'),
            ),
            if (widget.entry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final entry = widget.entry!;
                  if (entry.hatFoto) DogPhoto.evict(entry.fotoRef!);
                  await context.read<AppState>().deleteWeight(entry);
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
