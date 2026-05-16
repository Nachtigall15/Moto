import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../models/route_options.dart';
import '../../models/route_result.dart';
import '../../models/traffic.dart';
import '../../services/geocoding_service.dart';
import '../../services/poi_service.dart';
import '../../services/routing_service.dart';
import '../../services/speed_camera_service.dart';
import '../../services/traffic_service.dart';

class NavigationController extends ChangeNotifier {
  NavigationController({
    GeocodingService? geocoding,
    RoutingService? routing,
    SpeedCameraService? speedCameras,
    PoiService? poi,
    TrafficService? traffic,
  })  : _geocoding = geocoding ?? GeocodingService(),
        _routing = routing ?? RoutingService(),
        _speedCameras = speedCameras ?? SpeedCameraService(),
        _poi = poi ?? PoiService(),
        _traffic = traffic ?? TrafficService();

  final GeocodingService _geocoding;
  final RoutingService _routing;
  final SpeedCameraService _speedCameras;
  final PoiService _poi;
  final TrafficService _traffic;

  GeocodeResult? start;
  GeocodeResult? destination;
  RouteOptions options = const RouteOptions();

  RouteResult? route;
  bool loading = false;
  String? error;

  /// Position des Höhen-Sliders als Distanz ab Start (Meter).
  double cursorMeters = 0;

  bool showSpeedCameras = true;
  List<LatLng> speedCameras = const [];

  final Set<PoiCategory> activePoiCategories = {};
  List<Poi> pois = const [];

  bool showTraffic = true;
  List<TrafficIncident> trafficIncidents = const [];

  Future<List<GeocodeResult>> searchPlaces(String query) =>
      _geocoding.search(query);

  void setStart(GeocodeResult value) {
    start = value;
    notifyListeners();
  }

  void setDestination(GeocodeResult value) {
    destination = value;
    notifyListeners();
  }

  void updateCurviness(double value) {
    options = options.copyWith(curviness: value);
    notifyListeners();
  }

  void setAvoidMotorways(bool value) {
    options = options.copyWith(avoidMotorways: value);
    notifyListeners();
  }

  void setShowSpeedCameras(bool value) {
    showSpeedCameras = value;
    if (!value) {
      speedCameras = const [];
    } else if (route != null) {
      _loadSpeedCameras();
    }
    notifyListeners();
  }

  void setShowTraffic(bool value) {
    showTraffic = value;
    if (!value) {
      trafficIncidents = const [];
    } else if (route != null) {
      _loadTraffic();
    }
    notifyListeners();
  }

  void setCursorMeters(double value) {
    cursorMeters = value;
    notifyListeners();
  }

  void togglePoiCategory(PoiCategory category, bool active) {
    if (active) {
      activePoiCategories.add(category);
    } else {
      activePoiCategories.remove(category);
      pois = pois.where((p) => p.category != category).toList();
    }
    if (route != null && activePoiCategories.isNotEmpty) {
      _loadPois();
    }
    notifyListeners();
  }

  Future<void> computeRoute() async {
    if (start == null || destination == null) {
      error = 'Bitte Start und Ziel auswählen.';
      notifyListeners();
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await _routing.route(
        start: start!.position,
        destination: destination!.position,
        options: options,
      );
      route = result;
      cursorMeters = 0;
      if (showSpeedCameras) {
        await _loadSpeedCameras();
      }
      if (activePoiCategories.isNotEmpty) {
        await _loadPois();
      }
      if (showTraffic) {
        await _loadTraffic();
      }
    } on RoutingException catch (e) {
      error = e.message;
      route = null;
    } catch (e) {
      error = 'Unerwarteter Fehler: $e';
      route = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSpeedCameras() async {
    final r = route;
    if (r == null) return;
    try {
      speedCameras = await _speedCameras.camerasInBounds(boundsOf(r.polyline));
    } catch (_) {
      // Blitzer sind optional – Fehler nicht als Routenfehler werten.
      speedCameras = const [];
    }
    notifyListeners();
  }

  Future<void> _loadPois() async {
    final r = route;
    if (r == null || activePoiCategories.isEmpty) return;
    try {
      pois = await _poi.poisInBounds(
        boundsOf(r.polyline),
        activePoiCategories,
      );
    } catch (_) {
      // POIs sind optional – Fehler nicht als Routenfehler werten.
      pois = const [];
    }
    notifyListeners();
  }

  Future<void> _loadTraffic() async {
    final r = route;
    if (r == null) return;
    try {
      trafficIncidents =
          await _traffic.incidentsInBounds(boundsOf(r.polyline));
    } catch (_) {
      // Verkehr ist optional – Fehler nicht als Routenfehler werten.
      trafficIncidents = const [];
    }
    notifyListeners();
  }
}
