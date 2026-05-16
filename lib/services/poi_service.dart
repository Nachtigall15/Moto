import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../models/geo.dart';
import '../models/poi.dart';

/// Motorrad-relevante POIs (Geschäfte, Werkstätten) aus OpenStreetMap
/// via Overpass, keyless. Pro Kategorie eine Abfrage, damit jedes
/// Ergebnis seiner Kategorie zugeordnet bleibt.
class PoiService {
  PoiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Poi>> poisInBounds(
    GeoBounds bounds,
    Set<PoiCategory> categories,
  ) async {
    if (categories.isEmpty) return const [];
    final results = await Future.wait(
      categories.map((c) => _fetchCategory(bounds, c)),
    );
    return results.expand((e) => e).toList();
  }

  Future<List<Poi>> _fetchCategory(GeoBounds b, PoiCategory cat) async {
    final bbox = '${b.south},${b.west},${b.north},${b.east}';
    final union = cat.overpassSelectors
        .map((sel) => 'nwr$sel($bbox);')
        .join();
    final query = '[out:json][timeout:25];($union);out center 200;';

    final res = await _client.post(
      Uri.parse(AppConfig.overpassUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': AppConfig.userAgent,
      },
      body: {'data': query},
    );

    if (res.statusCode != 200) {
      throw Exception('POI-Abfrage fehlgeschlagen (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? const [];
    final pois = <Poi>[];
    for (final raw in elements) {
      final m = raw as Map<String, dynamic>;
      final center = m['center'] as Map<String, dynamic>?;
      final lat = m['lat'] ?? center?['lat'];
      final lon = m['lon'] ?? center?['lon'];
      if (lat == null || lon == null) continue;
      final tags = m['tags'] as Map<String, dynamic>?;
      pois.add(Poi(
        position: LatLng((lat as num).toDouble(), (lon as num).toDouble()),
        category: cat,
        name: tags?['name'] as String?,
      ));
    }
    return pois;
  }

  /// Nächste Rastmöglichkeit (Autohof/Rastplatz/Tankstelle) im Umkreis
  /// von [around]. Für den Pausen-Vorschlag bei Regen.
  Future<Poi?> nearestRestStop(
    LatLng around, {
    double radiusMeters = 6000,
  }) async {
    final r = radiusMeters.round();
    final union = PoiCategory.restStop.overpassSelectors
        .map((sel) =>
            'nwr$sel(around:$r,${around.latitude},${around.longitude});')
        .join();
    final query = '[out:json][timeout:25];($union);out center 60;';

    final res = await _client.post(
      Uri.parse(AppConfig.overpassUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': AppConfig.userAgent,
      },
      body: {'data': query},
    );
    if (res.statusCode != 200) {
      throw Exception('Rastplatz-Abfrage fehlgeschlagen (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? const [];
    Poi? best;
    var bestDist = double.infinity;
    for (final raw in elements) {
      final m = raw as Map<String, dynamic>;
      final center = m['center'] as Map<String, dynamic>?;
      final lat = m['lat'] ?? center?['lat'];
      final lon = m['lon'] ?? center?['lon'];
      if (lat == null || lon == null) continue;
      final pos = LatLng((lat as num).toDouble(), (lon as num).toDouble());
      final d = haversineMeters(around, pos);
      if (d < bestDist) {
        bestDist = d;
        final tags = m['tags'] as Map<String, dynamic>?;
        best = Poi(
          position: pos,
          category: PoiCategory.restStop,
          name: tags?['name'] as String?,
        );
      }
    }
    return best;
  }
}
