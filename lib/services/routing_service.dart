import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../models/geo.dart';
import '../models/route_options.dart';
import '../models/route_result.dart';

class RoutingException implements Exception {
  RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Routing über die GraphHopper Directions API.
///
/// Kurvigkeit: Die Standard-Cloud-Profile (car/bike/...) liefern keinen
/// `curvature`-Wert. Wir nähern „kurvig & fahrspaßig" daher über die
/// Straßenklasse an – große Straßen (Autobahn/Bundesstraße) werden mit
/// steigendem Regler zunehmend abgewertet, kleine Land-/Nebenstraßen
/// (meist kurviger) dadurch bevorzugt. Wer in seinem GraphHopper-Konto
/// ein echtes `motorcycle`-Profil mit `curvature` hat, kann das Custom
/// Model unten 1:1 darauf umstellen.
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RouteResult> route({
    required LatLng start,
    required LatLng destination,
    required RouteOptions options,
  }) async {
    if (!AppConfig.hasRoutingKey) {
      throw RoutingException(
        'Kein GraphHopper-API-Key gesetzt. App starten mit:\n'
        'flutter run --dart-define=GRAPHHOPPER_API_KEY=dein_key',
      );
    }

    final uri = Uri.parse(AppConfig.graphHopperRouteUrl)
        .replace(queryParameters: {'key': AppConfig.graphHopperApiKey});

    final body = <String, dynamic>{
      // GraphHopper erwartet im POST-Body [lng, lat].
      'points': [
        [start.longitude, start.latitude],
        [destination.longitude, destination.latitude],
      ],
      'profile': 'car',
      'elevation': true,
      'points_encoded': false,
      'instructions': false,
      'locale': 'de',
      // Custom Model erfordert deaktiviertes Contraction Hierarchies.
      'ch.disable': true,
      'custom_model': _curvinessModel(options),
    };

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': AppConfig.userAgent,
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw RoutingException(_errorMessage(res));
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final paths = data['paths'] as List<dynamic>?;
    if (paths == null || paths.isEmpty) {
      throw RoutingException('Keine Route gefunden.');
    }

    final path = paths.first as Map<String, dynamic>;
    final coords =
        (path['points'] as Map<String, dynamic>)['coordinates'] as List<dynamic>;

    final points = <RoutePoint>[];
    var cumulative = 0.0;
    LatLng? previous;
    for (final raw in coords) {
      final c = raw as List<dynamic>;
      final pos = LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      final ele = c.length > 2 ? (c[2] as num).toDouble() : 0.0;
      if (previous != null) {
        cumulative += distanceMeters(previous, pos);
      }
      points.add(RoutePoint(
        position: pos,
        elevation: ele,
        cumulativeMeters: cumulative,
      ));
      previous = pos;
    }

    return RouteResult(
      points: points,
      distanceMeters: (path['distance'] as num).toDouble(),
      durationMillis: (path['time'] as num).toInt(),
    );
  }

  /// Mappt den Kurvigkeits-Regler (0..1) auf Straßenklassen-Gewichte.
  Map<String, dynamic> _curvinessModel(RouteOptions o) {
    final c = o.curviness.clamp(0.0, 1.0).toDouble();

    // Bei c=0 keine Abwertung (=schnellste Strecke), bei c=1 starke
    // Abwertung großer Straßen → kleine, kurvige Straßen gewinnen.
    double penalty(double maxPenalty) =>
        (1.0 - c * maxPenalty).clamp(0.05, 1.0).toDouble();

    final priority = <Map<String, dynamic>>[
      {'if': 'road_class == MOTORWAY', 'multiply_by': penalty(0.95)},
      {'if': 'road_class == TRUNK', 'multiply_by': penalty(0.8)},
      {'if': 'road_class == PRIMARY', 'multiply_by': penalty(0.45)},
    ];

    if (o.avoidMotorways) {
      priority.insert(
        0,
        {'if': 'road_class == MOTORWAY', 'multiply_by': 0.0},
      );
    }

    return {'priority': priority};
  }

  String _errorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = body['message'];
      if (msg is String && msg.isNotEmpty) {
        return 'Routing-Fehler (${res.statusCode}): $msg';
      }
    } catch (_) {
      // Body nicht parsebar – generische Meldung unten.
    }
    if (res.statusCode == 401) {
      return 'Routing-Fehler: API-Key ungültig (401).';
    }
    return 'Routing-Fehler (${res.statusCode}).';
  }
}
