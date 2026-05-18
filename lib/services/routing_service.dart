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

/// Routing über die GraphHopper Directions API im Speed-Modus.
///
/// Kurvigkeit & „Autobahn meiden" bräuchten den „flexible mode"
/// (custom_model), der im kostenlosen GraphHopper-Tarif gesperrt ist.
/// Es wird daher die schnellste Strecke berechnet; der Regler/Schalter
/// bleibt vorerst ohne Wirkung (nicht-blockierender Hinweis in der UI).
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RouteResult> route({
    required LatLng start,
    required LatLng destination,
    required RouteOptions options,
    List<LatLng> via = const [],
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
        for (final v in via) [v.longitude, v.latitude],
        [destination.longitude, destination.latitude],
      ],
      'profile': 'car',
      'elevation': true,
      'points_encoded': false,
      'instructions': false,
      'locale': 'de',
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
        cumulative += haversineMeters(previous, pos);
      }
      points.add(RoutePoint(
        position: pos,
        elevation: ele,
        cumulativeMeters: cumulative,
      ));
      previous = pos;
    }

    // Regler/Schalter können im Free-Tarif nicht umgesetzt werden –
    // ehrlich kommunizieren, statt stillschweigend zu ignorieren.
    final wantsCurvy = options.curviness > 0 || options.avoidMotorways;
    final notice = wantsCurvy
        ? 'Kurvigkeit & „Autobahn meiden" brauchen einen kostenpflichtigen '
            'Routing-Tarif – Route als schnellste Strecke berechnet.'
        : null;

    return RouteResult(
      points: points,
      distanceMeters: (path['distance'] as num).toDouble(),
      durationMillis: (path['time'] as num).toInt(),
      notice: notice,
    );
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
