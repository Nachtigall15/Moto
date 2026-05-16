import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config.dart';
import '../../../models/geo.dart';
import '../../../models/poi.dart';
import '../../../models/route_result.dart';

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.start,
    required this.destination,
    required this.cursorMeters,
    required this.speedCameras,
    required this.pois,
  });

  final RouteResult? route;
  final LatLng? start;
  final LatLng? destination;
  final double cursorMeters;
  final List<LatLng> speedCameras;
  final List<Poi> pois;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _map = MapController();

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
      if (widget.start != null)
        _pin(widget.start!, Icons.trip_origin, Colors.greenAccent),
      if (widget.destination != null)
        _pin(widget.destination!, Icons.flag, scheme.primary),
      for (final cam in widget.speedCameras)
        _pin(cam, Icons.camera_alt, Colors.amber, size: 22),
      for (final poi in widget.pois)
        _pin(
          poi.position,
          _poiIcon(poi.category),
          _poiColor(poi.category),
          size: 22,
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

  Marker _pin(LatLng p, IconData icon, Color color, {double size = 30}) {
    return Marker(
      point: p,
      width: size + 6,
      height: size + 6,
      child: Icon(icon, color: color, size: size),
    );
  }
}
