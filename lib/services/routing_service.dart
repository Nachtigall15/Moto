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

/// Routing über BRouter (keyless).
///
/// Kurvigkeit & „Autobahn meiden" werden in ein BRouter-Profil
/// übersetzt: große/gerade Straßen (Motorway/Trunk/Primary/Secondary)
/// werden mit steigendem Regler zunehmend teurer, kleine Land-/Neben-
/// straßen (meist kurviger) dadurch bevorzugt. Das generierte Profil
/// wird einmalig auf den BRouter-Server hochgeladen und die Profil-ID
/// pro Profiltext gecacht. Schlägt am Custom-Profil irgendetwas fehl,
/// wird transparent auf das eingebaute Server-Profil `car-fast`
/// zurückgefallen, damit immer eine Route herauskommt.
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Profiltext -> hochgeladene BRouter-Profil-ID (pro Session gecacht).
  final Map<String, String> _profileIds = {};

  Future<RouteResult> route({
    required LatLng start,
    required LatLng destination,
    required RouteOptions options,
    List<LatLng> via = const [],
  }) async {
    final waypoints = <LatLng>[start, ...via, destination];
    final lonlats =
        waypoints.map((p) => '${p.longitude},${p.latitude}').join('|');

    final profileText = _buildProfile(options);

    Map<String, dynamic> geojson;
    String? notice;
    try {
      final id = await _profileId(profileText);
      geojson = await _fetchRoute(lonlats, id);
    } on RoutingException {
      // Fallback: eingebautes Server-Profil – immer gültig, nur weniger
      // kurvig. Fehler hier propagieren als echter Routing-Fehler.
      geojson = await _fetchRoute(lonlats, 'car-fast');
      notice = 'Kurven-Spezialprofil derzeit nicht verfügbar – Route mit '
          'Standard-Autoprofil berechnet (weniger kurvig).';
    }

    return _parse(geojson, notice);
  }

  /// Lädt das Profil (falls noch nicht geschehen) hoch und liefert die
  /// vom BRouter-Server vergebene Profil-ID.
  Future<String> _profileId(String profileText) async {
    final cached = _profileIds[profileText];
    if (cached != null) return cached;

    final res = await _client.post(
      Uri.parse(AppConfig.brouterUploadUrl),
      headers: {
        'Content-Type': 'text/plain',
        'User-Agent': AppConfig.userAgent,
      },
      body: profileText,
    );
    if (res.statusCode != 200) {
      throw RoutingException('Profil-Upload fehlgeschlagen (${res.statusCode}).');
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    String? id;
    if (body != null) {
      final err = body['error'];
      if (err is String && err.isNotEmpty) {
        throw RoutingException('Profil-Fehler: $err');
      }
      final pid = body['profileid'];
      if (pid is String && pid.isNotEmpty) id = pid;
    } else {
      // Manche Server-Versionen liefern die ID als reinen Text.
      final t = res.body.trim();
      if (t.startsWith('custom_')) id = t;
    }
    if (id == null) {
      throw RoutingException('Keine Profil-ID vom Server erhalten.');
    }

    _profileIds[profileText] = id;
    return id;
  }

  Future<Map<String, dynamic>> _fetchRoute(
      String lonlats, String profile) async {
    final uri = Uri.parse(AppConfig.brouterRouteUrl).replace(queryParameters: {
      'lonlats': lonlats,
      'profile': profile,
      'alternativeidx': '0',
      'format': 'geojson',
    });

    final res = await _client.get(
      uri,
      headers: {'User-Agent': AppConfig.userAgent},
    );
    if (res.statusCode != 200) {
      throw RoutingException(_errorMessage(res));
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['type'] == 'FeatureCollection') return data;
    } catch (_) {
      // Body ist kein GeoJSON -> BRouter-Klartext-Fehler unten.
    }
    final msg = res.body.trim();
    throw RoutingException(
      'Routing-Fehler: ${msg.isEmpty ? 'keine Route gefunden' : msg}',
    );
  }

  RouteResult _parse(Map<String, dynamic> geojson, String? notice) {
    final features = geojson['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw RoutingException('Keine Route gefunden.');
    }
    final feature = features.first as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List<dynamic>;
    if (coords.isEmpty) {
      throw RoutingException('Keine Route gefunden.');
    }
    final props =
        (feature['properties'] as Map<String, dynamic>?) ?? const {};

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

    // BRouter liefert Werte als Strings; bei Fehlen aus der Geometrie
    // abgeleitete Distanz nutzen.
    final distance =
        double.tryParse('${props['track-length']}') ?? cumulative;
    final timeSec = double.tryParse('${props['total-time']}') ?? 0.0;

    return RouteResult(
      points: points,
      distanceMeters: distance,
      durationMillis: (timeSec * 1000).round(),
      notice: notice,
    );
  }

  /// Übersetzt Regler/Schalter in ein eigenständiges BRouter-Auto-
  /// profil. Kleine Straßen bleiben bei Kostenfaktor 1, große werden
  /// mit steigender Kurvigkeit teurer → der Router weicht auf kurvige
  /// Nebenstrecken aus. Defensiv: nicht eindeutig „Auto" => Faktor 1,
  /// damit nie alle Wege blockiert werden.
  String _buildProfile(RouteOptions o) {
    final c = o.curviness.clamp(0.0, 1.0).toDouble();
    String f(double base) => (1.0 + base * c).toStringAsFixed(2);

    final motorway = f(9.0); // 1 → 10
    final trunk = f(5.0); // 1 → 6
    final primary = f(3.0); // 1 → 4
    final secondary = f(1.5); // 1 → 2.5

    // Hartes Meiden der Autobahn nur, wenn gewünscht.
    final blockMw = o.avoidMotorways
        ? 'or highway=motorway highway=motorway_link'
        : '0';

    return '''
---context:global
assign validForCars   true
assign validForBikes  false
assign validForFoot   false
assign turnInstructionMode 0

---context:way
assign turncost   0
assign initialcost 0
assign costfactor
  switch route=ferry  50
  switch highway=  9999
  switch or highway=footway or highway=path or highway=cycleway or highway=bridleway or highway=steps or highway=pedestrian or highway=track  9999
  switch $blockMw  9999
  switch or highway=motorway highway=motorway_link  $motorway
  switch or highway=trunk highway=trunk_link  $trunk
  switch or highway=primary highway=primary_link  $primary
  switch or highway=secondary highway=secondary_link  $secondary
  1.0

---context:node
assign initialcost 0
''';
  }

  String _errorMessage(http.Response res) {
    final body = res.body.trim();
    if (body.isNotEmpty && body.length < 300) {
      return 'Routing-Fehler (${res.statusCode}): $body';
    }
    return 'Routing-Fehler (${res.statusCode}).';
  }
}
