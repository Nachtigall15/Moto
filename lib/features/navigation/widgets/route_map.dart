import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';
import '../../../models/geo.dart';
import '../../../models/poi.dart';
import '../../../models/route_result.dart';
import '../../../models/traffic.dart';

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.start,
    required this.destination,
    required this.cursorMeters,
    required this.speedCameras,
    required this.pois,
    required this.traffic,
    required this.pauseStop,
    required this.currentLocation,
  });

  final RouteResult? route;
  final LatLng? start;
  final LatLng? destination;
  final double cursorMeters;
  final List<LatLng> speedCameras;
  final List<Poi> pois;
  final List<TrafficIncident> traffic;
  final LatLng? pauseStop;
  final LatLng? currentLocation;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _map = MapController();
  bool _initialCentered = false;

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sobald die Route steht, auf sie zoomen (höchste Priorität).
    if (widget.route != null && widget.route != oldWidget.route) {
      final b = boundsOf(widget.route!.polyline);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(b.southWest, b.northEast),
            padding: const EdgeInsets.all(40),
          ),
        );
      });
      return;
    }
    // Erst-Zentrierung auf den aktuellen Standort, sobald der vom
    // Controller eintrudelt (Übergang null -> Wert) und noch keine
    // Route gewählt wurde. War der Standort schon beim ersten Build
    // bekannt, hat MapOptions.initialCenter ihn bereits gesetzt.
    final here = widget.currentLocation;
    if (!_initialCentered &&
        here != null &&
        oldWidget.currentLocation != here &&
        widget.route == null) {
      _initialCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _map.move(here, 12);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final route = widget.route;
    final cursor = route?.pointAtDistance(widget.cursorMeters).position;

    final markers = <Marker>[
      if (widget.currentLocation != null)
        Marker(
          point: widget.currentLocation!,
          width: 22,
          height: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      if (widget.start != null)
        _pin(widget.start!, Icons.trip_origin, Colors.greenAccent),
      if (widget.destination != null)
        _pin(widget.destination!, Icons.flag, scheme.primary),
      if (widget.pauseStop != null)
        _pin(widget.pauseStop!, Icons.local_cafe, Colors.brown.shade300),
      for (final cam in widget.speedCameras)
        _pin(cam, Icons.camera_alt, Colors.amber, size: 22),
      for (final poi in widget.pois)
        _pin(
          poi.position,
          _poiIcon(poi.category),
          _poiColor(poi.category),
          size: 22,
        ),
      for (final inc in widget.traffic)
        Marker(
          point: inc.position,
          width: 30,
          height: 30,
          child: Tooltip(
            message: inc.delaySeconds > 0
                ? '${inc.description} (+${(inc.delaySeconds / 60).round()} min)'
                : inc.description,
            child: Icon(
              _trafficIcon(inc.kind),
              color: _trafficColor(inc.kind),
              size: 24,
            ),
          ),
        ),
      if (cursor != null)
        Marker(
          point: cursor,
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
    ];

    final initialCenter = widget.currentLocation ??
        widget.start ??
        widget.destination ??
        const LatLng(51.16, 10.45); // Mitte Deutschlands als Fallback
    final initialZoom = widget.currentLocation != null ? 12.0 : 6.0;

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 3,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.osmTileUrl,
          subdomains: AppConfig.osmTileSubdomains,
          userAgentPackageName: 'moto.app',
          tileSize: 256,
          maxNativeZoom: 19,
          // Default-Puffer (2) reicht; höhere Werte erzeugen unnötig
          // viele parallele Tile-Requests, die iOS-Safari unter Last
          // teils stehenlässt.
          keepBuffer: 2,
        ),
        if (route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route.polyline,
                strokeWidth: 4,
                color: scheme.primary,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  IconData _poiIcon(PoiCategory c) =>
      c == PoiCategory.workshop ? Icons.build : Icons.two_wheeler;

  Color _poiColor(PoiCategory c) =>
      c == PoiCategory.workshop ? Colors.lightBlueAccent : Colors.tealAccent;

  IconData _trafficIcon(TrafficKind k) {
    switch (k) {
      case TrafficKind.accident:
        return Icons.car_crash;
      case TrafficKind.jam:
        return Icons.traffic;
      case TrafficKind.roadworks:
        return Icons.construction;
      case TrafficKind.closure:
        return Icons.block;
      case TrafficKind.hazard:
        return Icons.warning;
      case TrafficKind.other:
        return Icons.info;
    }
  }

  Color _trafficColor(TrafficKind k) {
    switch (k) {
      case TrafficKind.accident:
      case TrafficKind.closure:
        return Colors.redAccent;
      case TrafficKind.jam:
        return Colors.orangeAccent;
      case TrafficKind.roadworks:
        return Colors.amber;
      case TrafficKind.hazard:
        return Colors.deepOrangeAccent;
      case TrafficKind.other:
        return Colors.white70;
    }
  }

  Marker _pin(LatLng p, IconData icon, Color color, {double size = 30}) {
    return Marker(
      point: p,
      width: size + 6,
      height: size + 6,
      child: Icon(icon, color: color, size: size),
    );
  }
}
