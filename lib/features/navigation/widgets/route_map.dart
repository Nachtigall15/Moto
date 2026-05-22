import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
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
  });

  final RouteResult? route;
  final LatLng? start;
  final LatLng? destination;
  final double cursorMeters;
  final List<LatLng> speedCameras;
  final List<Poi> pois;
  final List<TrafficIncident> traffic;
  final LatLng? pauseStop;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _map = MapController();
  LatLng? _currentLocation;
  bool _initialCentered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateUser());
  }

  /// Holt einmalig den aktuellen Standort und zentriert die Karte
  /// darauf, solange noch keine Route/kein Start gewählt wurde.
  /// Fehler (Permission abgelehnt, kein Fix, Service aus) führen
  /// stillschweigend zum Default-Center.
  Future<void> _locateUser() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = here);
      final hasUserPick = widget.start != null ||
          widget.destination != null ||
          widget.route != null;
      if (!_initialCentered && !hasUserPick) {
        _map.move(here, 12);
        _initialCentered = true;
      }
    } catch (_) {
      // Standort-Fehler ignorieren – Default-Ansicht bleibt.
    }
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final route = widget.route;
    final cursor = route?.pointAtDistance(widget.cursorMeters).position;

    final markers = <Marker>[
      if (_currentLocation != null)
        Marker(
          point: _currentLocation!,
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

    return FlutterMap(
      mapController: _map,
      options: const MapOptions(
        initialCenter: LatLng(48.137, 11.575),
        initialZoom: 7.0,
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.osmTileUrl,
          userAgentPackageName: 'moto.app',
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
