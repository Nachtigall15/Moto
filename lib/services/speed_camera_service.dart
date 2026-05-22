import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../models/geo.dart';

/// Blitzer aus OpenStreetMap (Overpass), keyless.
///
/// Hinweis: In Deutschland ist die Nutzung einer Blitzer-Warnung WÄHREND
/// der Fahrt untersagt (§ 23 Abs. 1c StVO). Dieser Layer ist für die
/// Routenplanung gedacht und lässt sich per Kontrollkästchen abschalten.
class SpeedCameraService {
  SpeedCameraService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Blitzer entlang einer Route (Korridor von `radiusMeters` um den
  /// Streckenverlauf), statt der gesamten Bounding-Box – sonst überflutet
  /// eine Langstrecke die Karte mit hunderten Markern.
  Future<List<LatLng>> camerasAlongRoute(
    List<LatLng> polyline, {
    double radiusMeters = 2000,
    double sampleSpacingMeters = 5000,
    int maxSeeds = 200,
  }) async {
    if (polyline.isEmpty) return const [];

    final seeds = _subsample(polyline, sampleSpacingMeters, maxSeeds);
    final around = seeds
        .map((p) => '${p.latitude.toStringAsFixed(5)},'
            '${p.longitude.toStringAsFixed(5)}')
        .join(',');

    final query = '[out:json][timeout:25];'
        'node["highway"="speed_camera"](around:'
        '${radiusMeters.toStringAsFixed(0)},$around);'
        'out;';

    final res = await _client.post(
      Uri.parse(AppConfig.overpassUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': AppConfig.userAgent,
      },
      body: {'data': query},
    );

    if (res.statusCode != 200) {
      throw Exception('Blitzer-Abfrage fehlgeschlagen (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? const [];
    return elements
        .map((raw) => raw as Map<String, dynamic>)
        .where((m) => m['lat'] != null && m['lon'] != null)
        .map((m) => LatLng(
              (m['lat'] as num).toDouble(),
              (m['lon'] as num).toDouble(),
            ))
        .toList();
  }

  /// Verteilt Stützpunkte gleichmäßig (~ `spacing` m) entlang der Route
  /// und kappt die Liste, damit die Overpass-Query handhabbar bleibt.
  List<LatLng> _subsample(
      List<LatLng> polyline, double spacing, int maxSeeds) {
    if (polyline.length <= 2) return polyline;
    final out = <LatLng>[polyline.first];
    var acc = 0.0;
    for (var i = 1; i < polyline.length; i++) {
      acc += haversineMeters(polyline[i - 1], polyline[i]);
      if (acc >= spacing) {
        out.add(polyline[i]);
        acc = 0;
        if (out.length >= maxSeeds - 1) break;
      }
    }
    out.add(polyline.last);
    return out;
  }
}
