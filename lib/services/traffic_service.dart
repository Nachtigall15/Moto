import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../models/geo.dart';
import '../models/traffic.dart';

/// Verkehrslage & Unfälle über die TomTom Traffic Incident Details API
/// (v5). Key per --dart-define=TOMTOM_API_KEY=... ; ohne Key inaktiv.
///
/// Hinweis: TomTom begrenzt die bbox-Größe. Bei sehr langen Routen kann
/// die Abfrage scheitern – der Layer ist optional und wirft den Fehler
/// nicht in die Routenberechnung zurück (Controller fängt ihn).
class TrafficService {
  TrafficService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _fields =
      '{incidents{type,geometry{type,coordinates},'
      'properties{iconCategory,magnitudeOfDelay,delay,'
      'events{description,code,iconCategory}}}}';

  Future<List<TrafficIncident>> incidentsInBounds(GeoBounds b) async {
    if (!AppConfig.hasTrafficKey) return const [];

    // TomTom-bbox-Reihenfolge: minLon,minLat,maxLon,maxLat.
    final bbox = '${b.west},${b.south},${b.east},${b.north}';
    final uri = Uri.parse(AppConfig.tomTomIncidentsUrl).replace(
      queryParameters: {
        'key': AppConfig.tomTomApiKey,
        'bbox': bbox,
        'fields': _fields,
        'language': 'de-DE',
        'timeValidityFilter': 'present',
      },
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Verkehrs-Abfrage fehlgeschlagen (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final incidents = data['incidents'] as List<dynamic>? ?? const [];

    final result = <TrafficIncident>[];
    for (final raw in incidents) {
      final m = raw as Map<String, dynamic>;
      final props = m['properties'] as Map<String, dynamic>? ?? const {};
      final geom = m['geometry'] as Map<String, dynamic>?;
      final pos = _positionOf(geom);
      if (pos == null) continue;

      final iconCategory = (props['iconCategory'] as num?)?.toInt() ?? 0;
      final events = props['events'] as List<dynamic>? ?? const [];
      final desc = events.isNotEmpty
          ? (events.first as Map<String, dynamic>)['description'] as String?
          : null;

      result.add(TrafficIncident(
        position: pos,
        kind: TrafficIncident.kindFromIconCategory(iconCategory),
        description: desc?.trim().isNotEmpty == true
            ? desc!.trim()
            : 'Verkehrsereignis',
        delaySeconds: (props['delay'] as num?)?.toInt() ?? 0,
      ));
    }
    return result;
  }

  /// Mittlerer Punkt der Geometrie (Point oder Line/MultiLine).
  LatLng? _positionOf(Map<String, dynamic>? geom) {
    if (geom == null) return null;
    final coords = geom['coordinates'];
    final flat = <List<num>>[];
    void collect(dynamic node) {
      if (node is List && node.isNotEmpty) {
        if (node.first is num && node.length >= 2) {
          flat.add([node[0] as num, node[1] as num]);
        } else {
          for (final child in node) {
            collect(child);
          }
        }
      }
    }

    collect(coords);
    if (flat.isEmpty) return null;
    final mid = flat[flat.length ~/ 2];
    return LatLng(mid[1].toDouble(), mid[0].toDouble());
  }
}
