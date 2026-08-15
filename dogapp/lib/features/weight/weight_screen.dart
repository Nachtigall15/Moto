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

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.weights;
    final letztes = state.letztesGewicht;
    final diff = state.gewichtsDifferenz;

    return Scaffold(
      appBar: AppBar(title: const Text('Gewicht & Fotos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Wiegen'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionCard(
            title: 'Aktueller Stand',
            icon: Icons.monitor_weight_outlined,
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Letztes Gewicht',
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
                    label: 'Veränderung',
                    value: diff == null
                        ? '–'
                        : '${diff >= 0 ? '+' : '−'}'
                            '${nfWeight.format(diff.abs())} kg',
                    hint: diff == null ? 'zum Vorwert' : 'zum Vorwert',
                    icon: diff == null
                        ? Icons.remove
                        : (diff >= 0
                            ? Icons.trending_up
                            : Icons.trending_down),
                    color: diff == null || diff.abs() < 0.05
                        ? null
                        : Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (entries.length >= 2)
            SectionCard(
              title: 'Verlauf',
              icon: Icons.show_chart,
              child: SizedBox(
                height: 190,
                child: _WeightChart(
                  entries: entries,
                  zielgewicht: state.profile.zielgewichtKg,
                ),
              ),
            ),
          if (entries.length >= 2) const SizedBox(height: 16),
          if (entries.isEmpty)
            const Card(
              child: EmptyHint(
                icon: Icons.monitor_weight_outlined,
                text: 'Noch keine Messung.\n'
                    'Beim Wiegen gleich ein Foto mitspeichern –\n'
                    'so entsteht ein Entwicklungsverlauf.',
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final e in entries) _WeightTile(entry: e),
                ],
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
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
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
        '${dfDateTime.format(entry.zeitpunkt)} Uhr'
        '${entry.notiz.isEmpty ? '' : '\n${entry.notiz}'}',
      ),
      isThreeLine: entry.notiz.isNotEmpty,
    );
  }
}

/// Gewichtsverlauf über die Zeit. X ist der Tag als Zahl, damit
/// ungleichmäßige Abstände zwischen zwei Messungen auch im Diagramm
/// ungleichmäßig aussehen.
class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries, this.zielgewicht});

  final List<WeightEntry> entries;
  final double? zielgewicht;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final sorted = [...entries]
      ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
    final first = startOfDay(sorted.first.zeitpunkt);

    double toX(DateTime d) =>
        d.difference(first).inMinutes / (60 * 24); // Tage, mit Bruchteil

    final spots = [
      for (final e in sorted) FlSpot(toX(e.zeitpunkt), e.gewichtKg),
    ];

    final values = [
      ...sorted.map((e) => e.gewichtKg),
      if (zielgewicht != null) zielgewicht!,
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
        extraLinesData: zielgewicht == null
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: zielgewicht!,
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
                    '${nfWeight.format(s.y)} kg\n'
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
    _notiz.dispose();
    super.dispose();
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
    final gewicht =
        double.tryParse(_gewicht.text.trim().replaceAll(',', '.')) ?? 0;

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
        fotoRef: ref,
        clearFoto: ref == null,
        notiz: _notiz.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final gewichtOk =
        (double.tryParse(_gewicht.text.trim().replaceAll(',', '.')) ?? 0) > 0;

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
            TextField(
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
