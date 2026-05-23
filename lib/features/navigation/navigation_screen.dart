import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../models/poi.dart';
import '../../models/route_options.dart';
import '../../services/geocoding_service.dart';
import 'navigation_controller.dart';
import 'widgets/elevation_chart.dart';
import 'widgets/route_map.dart';

typedef _PlaceSearch = Future<List<GeocodeResult>> Function(String query);

class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NavigationController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moto · Tourenplanung'),
      ),
      body: Column(
        children: [
          _ControlsPanel(controller: c),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RouteMap(
                  route: c.route,
                  start: c.start?.position,
                  destination: c.destination?.position,
                  cursorMeters: c.cursorMeters,
                  speedCameras: c.speedCameras,
                  pois: c.pois,
                  traffic: c.trafficIncidents,
                  pauseStop: c.pauseStop?.position,
                  currentLocation: c.currentLocation,
                ),
                if (c.loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black38,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          if (c.route != null)
            Material(
              elevation: 8,
              child: ElevationChart(
                route: c.route!,
                cursorMeters: c.cursorMeters,
                onCursorChanged: c.setCursorMeters,
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final maxHeight =
        MediaQuery.of(context).size.height * (c.route != null ? 0.32 : 0.55);
    return Material(
      elevation: 4,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start/Ziel als Buttons, die ein Such-Sheet öffnen.
              // Vorteil: nur EIN TextField ist je sichtbar (im Sheet)
              // → kein Fokus-Sprung zwischen gestapelten Eingabefeldern.
              _LocationButton(
                label: 'Start',
                icon: Icons.trip_origin,
                selection: c.start?.label,
                placeholder: 'Start wählen',
                onPick: () => _openLocationSheet(
                  context: context,
                  title: 'Start wählen',
                  onSearch: c.searchPlaces,
                  onPicked: c.setStart,
                  currentLocation: c.currentLocation != null
                      ? c.useCurrentLocationAsStart
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              _LocationButton(
                label: 'Ziel',
                icon: Icons.flag_outlined,
                selection: c.destination?.label,
                placeholder: 'Ziel wählen',
                onPick: () => _openLocationSheet(
                  context: context,
                  title: 'Ziel wählen',
                  onSearch: c.searchPlaces,
                  onPicked: c.setDestination,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.turn_sharp_right, size: 18),
                  const SizedBox(width: 8),
                  const Text('Kurvigkeit'),
                  Expanded(
                    child: Slider(
                      value: c.options.curviness,
                      label: _curvinessLabel(c.options.curviness),
                      divisions: 10,
                      onChanged: c.updateCurviness,
                    ),
                  ),
                  Text(_curvinessLabel(c.options.curviness)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Autobahn meiden'),
                      value: c.options.avoidMotorways,
                      onChanged: c.setAvoidMotorways,
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Blitzer anzeigen'),
                subtitle: const Text(
                  'Nur Planung – Live-Warnung während der Fahrt ist in DE '
                  'unzulässig (§ 23 StVO).',
                  style: TextStyle(fontSize: 11),
                ),
                value: c.showSpeedCameras,
                onChanged: (v) => c.setShowSpeedCameras(v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Verkehr & Unfälle anzeigen'),
                subtitle: Text(
                  AppConfig.hasTrafficKey
                      ? 'Staus, Unfälle, Baustellen & Sperrungen (TomTom).'
                      : 'Inaktiv – TomTom-Key fehlt '
                          '(--dart-define=TOMTOM_API_KEY=...).',
                  style: const TextStyle(fontSize: 11),
                ),
                value: c.showTraffic && AppConfig.hasTrafficKey,
                onChanged: AppConfig.hasTrafficKey
                    ? (v) => c.setShowTraffic(v ?? false)
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    'Filter (entlang der Route)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final cat in PoiCategory.all)
                    FilterChip(
                      label: Text(cat.label),
                      selected: c.activePoiCategories.contains(cat),
                      onSelected: (v) => c.togglePoiCategory(cat, v),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: SegmentedButton<RoutePreference>(
                  segments: const [
                    ButtonSegment(
                      value: RoutePreference.fastest,
                      label: Text('Schnell'),
                      icon: Icon(Icons.bolt),
                    ),
                    ButtonSegment(
                      value: RoutePreference.shortest,
                      label: Text('Kurz'),
                      icon: Icon(Icons.straighten),
                    ),
                  ],
                  selected: {c.options.preference},
                  onSelectionChanged: (s) => c.setRoutePreference(s.first),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: c.loading ? null : c.computeRoute,
                  icon: const Icon(Icons.route),
                  label: const Text('Route berechnen'),
                ),
              ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    c.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (c.route?.notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    c.route!.notice!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (c.route != null) _RouteSummary(controller: c),
            ],
          ),
        ),
      ),
    );
  }

  String _curvinessLabel(double v) {
    if (v < 0.2) return 'Schnell';
    if (v < 0.45) return 'Leicht kurvig';
    if (v < 0.7) return 'Kurvig';
    if (v < 0.9) return 'Sehr kurvig';
    return 'Maximal';
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    final r = controller.route!;
    final km = (r.distanceMeters / 1000).toStringAsFixed(1);
    final dur = Duration(milliseconds: r.durationMillis);
    final h = dur.inHours;
    final m = dur.inMinutes % 60;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(context, Icons.straighten, '$km km'),
          _stat(context, Icons.schedule, h > 0 ? '${h}h ${m}min' : '${m}min'),
          _stat(context, Icons.trending_up,
              '${r.ascentMeters.toStringAsFixed(0)} m'),
          _stat(context, Icons.trending_down,
              '${r.descentMeters.toStringAsFixed(0)} m'),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({
    required this.label,
    required this.icon,
    required this.selection,
    required this.placeholder,
    required this.onPick,
  });

  final String label;
  final IconData icon;
  final String? selection;
  final String placeholder;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = selection != null && selection!.isNotEmpty;
    return Material(
      color: const Color(0xFF111A2E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      hasValue ? selection! : placeholder,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasValue
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

void _openLocationSheet({
  required BuildContext context,
  required String title,
  required _PlaceSearch onSearch,
  required ValueChanged<GeocodeResult> onPicked,
  VoidCallback? currentLocation,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF111A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _LocationSearchSheet(
          title: title,
          onSearch: onSearch,
          onPicked: (r) {
            Navigator.of(sheetCtx).pop();
            onPicked(r);
          },
          useCurrentLocation: currentLocation == null
              ? null
              : () {
                  Navigator.of(sheetCtx).pop();
                  currentLocation();
                },
        ),
      );
    },
  );
}

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet({
    required this.title,
    required this.onSearch,
    required this.onPicked,
    this.useCurrentLocation,
  });

  final String title;
  final _PlaceSearch onSearch;
  final ValueChanged<GeocodeResult> onPicked;
  final VoidCallback? useCurrentLocation;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<GeocodeResult> _results = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Future<void> _run(String v) async {
    if (v.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await widget.onSearch(v);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Adresse oder Ort eingeben',
              suffixIcon: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _onChanged,
          ),
          if (widget.useCurrentLocation != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Aktueller Standort'),
                onPressed: widget.useCurrentLocation,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Mindestens 3 Buchstaben eingeben…',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: scheme.outlineVariant,
                    ),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, size: 18),
                        title: Text(
                          r.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => widget.onPicked(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
