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
/// Für „Schnell vs. Kurz" werden Alternativen via
/// `algorithm=alternative_route` angefragt und die passende ausgewählt
/// (kürzeste Zeit bzw. kürzeste Distanz). Lehnt der Tarif Alternativen
/// ab, fällt der Service auf die Einzel-Route zurück und meldet das
/// als nicht-blockierenden Hinweis.
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

    final baseBody = <String, dynamic>{
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

    // Erst mit Alternativen anfragen, damit „Kurz" tatsächlich eine
    // andere Strecke wählen kann.
    var res = await _post(uri, {
      ...baseBody,
      'algorithm': 'alternative_route',
      'alternative_route.max_paths': 3,
    });

    String? altNotice;
    if (res.statusCode != 200) {
      // Lehnt der Tarif Alternativen ab -> Einzel-Route.
      res = await _post(uri, baseBody);
      altNotice = 'Alternativen werden vom aktuellen Routing-Tarif nicht '
          'unterstützt – nur eine Variante verfügbar.';
    }
    if (res.statusCode != 200) {
      throw RoutingException(_errorMessage(res));
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final rawPaths = data['paths'] as List<dynamic>?;
    if (rawPaths == null || rawPaths.isEmpty) {
      throw RoutingException('Keine Route gefunden.');
    }
    final paths = rawPaths.cast<Map<String, dynamic>>();

    final chosen = _pick(paths, options.preference);
    final onlyOne = paths.length < 2;

    // Notice-Stack: Tarif-Hinweise + ggf. „Kurz nicht verfügbar".
    final notices = <String>[];
    if (altNotice != null) notices.add(altNotice);
    if (options.preference == RoutePreference.shortest && onlyOne) {
      notices.add('Kürzeste-Variante nicht verfügbar – '
          'gleiche Strecke wie Schnell.');
    }
    final wantsCurvy = options.curviness > 0 || options.avoidMotorways;
    if (wantsCurvy) {
      notices.add('Kurvigkeit & „Autobahn meiden" brauchen einen '
          'kostenpflichtigen Routing-Tarif – Strecke ohne diese Vorgaben.');
    }

    return _toResult(chosen, notices.isEmpty ? null : notices.join('\n'));
  }

  Future<http.Response> _post(Uri uri, Map<String, dynamic> body) {
    return _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': AppConfig.userAgent,
      },
      body: jsonEncode(body),
    );
  }

  Map<String, dynamic> _pick(
      List<Map<String, dynamic>> paths, RoutePreference pref) {
    if (paths.length == 1) return paths.first;
    double key(Map<String, dynamic> p) => switch (pref) {
          RoutePreference.fastest => (p['time'] as num).toDouble(),
          RoutePreference.shortest => (p['distance'] as num).toDouble(),
        };
    return paths.reduce((a, b) => key(a) <= key(b) ? a : b);
  }

  RouteResult _toResult(Map<String, dynamic> path, String? notice) {
    final coords = (path['points'] as Map<String, dynamic>)['coordinates']
        as List<dynamic>;

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
