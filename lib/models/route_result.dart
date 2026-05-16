import 'package:latlong2/latlong.dart';

import 'geo.dart';

class RouteResult {
  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationMillis,
    this.notice,
  })  : ascentMeters = _ascent(points),
        descentMeters = _descent(points);

  final List<RoutePoint> points;
  final double distanceMeters;
  final int durationMillis;

  /// Nicht-blockierender Hinweis (z. B. „im Schnellmodus berechnet,
  /// weil Kurvigkeit im kostenlosen Tarif gesperrt ist"). UI zeigt das
  /// als Info, nicht als Fehler.
  final String? notice;
  final double ascentMeters;
  final double descentMeters;

  List<LatLng> get polyline => points.map((p) => p.position).toList();

  double get minElevation =>
      points.map((p) => p.elevation).reduce((a, b) => a < b ? a : b);
  double get maxElevation =>
      points.map((p) => p.elevation).reduce((a, b) => a > b ? a : b);

  /// Punkt, der einer Distanz ab Start am nächsten liegt – für den
  /// Slider unter dem Höhen-Graphen.
  RoutePoint pointAtDistance(double meters) {
    var best = points.first;
    var bestDelta = double.infinity;
    for (final p in points) {
      final d = (p.cumulativeMeters - meters).abs();
      if (d < bestDelta) {
        bestDelta = d;
        best = p;
      }
    }
    return best;
  }

  /// Routenpunkt, der einer Position am nächsten liegt (für Pausen-/
  /// Wegpunkt-Einfügung).
  RoutePoint nearestTo(LatLng target) {
    var best = points.first;
    var bestDist = double.infinity;
    for (final p in points) {
      final d = haversineMeters(p.position, target);
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }

  static double _ascent(List<RoutePoint> pts) {
    var sum = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final diff = pts[i].elevation - pts[i - 1].elevation;
      if (diff > 0) sum += diff;
    }
    return sum;
  }

  static double _descent(List<RoutePoint> pts) {
    var sum = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final diff = pts[i].elevation - pts[i - 1].elevation;
      if (diff < 0) sum += -diff;
    }
    return sum;
  }
}
