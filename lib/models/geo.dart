import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Ein Routenpunkt inkl. Höhe und aufsummierter Distanz ab Start.
/// `cumulativeMeters` ist die Brücke zwischen Höhen-Graph (x = km) und
/// der Karte (Marker an genau diesem Punkt).
class RoutePoint {
  const RoutePoint({
    required this.position,
    required this.elevation,
    required this.cumulativeMeters,
  });

  final LatLng position;
  final double elevation;
  final double cumulativeMeters;
}

/// Haversine-Distanz in Metern.
double distanceMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _deg2rad(b.latitude - a.latitude);
  final dLng = _deg2rad(b.longitude - a.longitude);
  final lat1 = _deg2rad(a.latitude);
  final lat2 = _deg2rad(b.latitude);

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

/// Framework-unabhängige Bounding-Box (kein Abhängigkeit auf flutter_map
/// in der Modell-/Service-Schicht).
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  LatLng get southWest => LatLng(south, west);
  LatLng get northEast => LatLng(north, east);
}

GeoBounds boundsOf(List<LatLng> points) {
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final p in points) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  return GeoBounds(
    south: minLat,
    west: minLng,
    north: maxLat,
    east: maxLng,
  );
}
