import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../models/poi.dart';
import 'navigation_controller.dart';
import 'widgets/elevation_chart.dart';
import 'widgets/location_search_field.dart';
import 'widgets/route_map.dart';

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
    final maxHeight = MediaQuery.of(context).size.height * 0.55;
    return Material(
      elevation: 4,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            LocationSearchField(
              label: 'Start',
              icon: Icons.trip_origin,
              onSearch: c.searchPlaces,
              onSelected: c.setStart,
              selectedLabel: c.start?.label,
            ),
            const SizedBox(height: 8),
            LocationSearchField(
              label: 'Ziel',
              icon: Icons.flag_outlined,
              onSearch: c.searchPlaces,
              onSelected: c.setDestination,
              selectedLabel: c.destination?.label,
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
            const SizedBox(height: 4),
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
