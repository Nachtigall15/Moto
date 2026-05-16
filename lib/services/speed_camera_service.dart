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

  Future<List<LatLng>> camerasInBounds(GeoBounds bounds) async {
    final s = bounds.south;
    final w = bounds.west;
    final n = bounds.north;
    final e = bounds.east;

    final query = '[out:json][timeout:25];'
        'node["highway"="speed_camera"]($s,$w,$n,$e);'
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
}
