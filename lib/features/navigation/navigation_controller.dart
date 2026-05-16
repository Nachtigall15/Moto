import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../models/geo.dart';
import '../../models/poi.dart';
import '../../models/route_options.dart';
import '../../models/route_result.dart';
import '../../models/traffic.dart';
import '../../models/weather.dart';
import '../../services/geocoding_service.dart';
import '../../services/poi_service.dart';
import '../../services/routing_service.dart';
import '../../services/speed_camera_service.dart';
import '../../services/traffic_service.dart';
import '../../services/weather_service.dart';

class NavigationController extends ChangeNotifier {
  NavigationController({
    GeocodingService? geocoding,
    RoutingService? routing,
    SpeedCameraService? speedCameras,
    PoiService? poi,
    TrafficService? traffic,
    WeatherService? weather,
  })  : _geocoding = geocoding ?? GeocodingService(),
        _routing = routing ?? RoutingService(),
        _speedCameras = speedCameras ?? SpeedCameraService(),
        _poi = poi ?? PoiService(),
        _traffic = traffic ?? TrafficService(),
        _weather = weather ?? WeatherService();

  final GeocodingService _geocoding;
  final RoutingService _routing;
  final SpeedCameraService _speedCameras;
  final PoiService _poi;
  final TrafficService _traffic;
  final WeatherService _weather;

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

  DateTime departure = DateTime.now();
  RouteWeather? weather;
  bool loadingWeather = false;
  String? weatherError;

  /// Eingelegte Pause (Rastmöglichkeit als Wegpunkt + Wartezeit).
  Poi? pauseStop;
  Duration pauseDuration = Duration.zero;
  double _pauseAfterMeters = 0;

  bool get hasPause => pauseStop != null;

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

  void setDeparture(DateTime value) {
    departure = value;
    notifyListeners();
    if (route != null) _loadWeather();
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
    // Frische Route: evtl. eingelegte Pause verwerfen.
    pauseStop = null;
    pauseDuration = Duration.zero;
    _pauseAfterMeters = 0;
    await _runRoute();
  }

  Future<void> _runRoute({List<LatLng> via = const []}) async {
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
        via: via,
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
      await _loadWeather();
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

  Future<void> _loadWeather() async {
    final r = route;
    if (r == null) return;
    loadingWeather = true;
    weatherError = null;
    notifyListeners();
    try {
      weather = await _weather.forecastForRoute(
        route: r,
        departure: departure,
        pauseAfterMeters: _pauseAfterMeters,
        pause: pauseDuration,
      );
    } catch (e) {
      weatherError = 'Wetter konnte nicht geladen werden.';
      weather = null;
    } finally {
      loadingWeather = false;
      notifyListeners();
    }
  }

  /// Sucht eine Rastmöglichkeit kurz vor dem ersten Regen-Abschnitt,
  /// baut sie als Wegpunkt in die Route ein und legt eine Wartezeit
  /// in Höhe der Regendauer ein (Regen „aussitzen").
  Future<void> suggestPause() async {
    final r = route;
    final w = weather;
    if (r == null || w == null || !w.hasRain) return;

    loading = true;
    weatherError = null;
    notifyListeners();

    try {
      final window = w.rainWindows.first;
      final preMeters = (window.startMeters - 3000).clamp(0.0, r.distanceMeters);
      final anchor = r.pointAtDistance(preMeters).position;
      final stop = await _poi.nearestRestStop(anchor);
      if (stop == null) {
        weatherError = 'Keine Rastmöglichkeit vor dem Regen gefunden.';
        return;
      }
      pauseStop = stop;
      pauseDuration = Duration(
        minutes: window.duration.inMinutes < 15
            ? 15
            : window.duration.inMinutes,
      );
      // _runRoute lädt Route+Layer+Wetter neu; danach kennen wir die
      // Distanz des Stopps in der neuen Route für die Wartezeit-Schwelle.
      await _runRoute(via: [stop.position]);
      final nr = route;
      if (nr != null) {
        _pauseAfterMeters = nr.nearestTo(stop.position).cumulativeMeters;
        await _loadWeather();
      }
    } catch (e) {
      weatherError = 'Pause konnte nicht eingeplant werden.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> clearPause() async {
    pauseStop = null;
    pauseDuration = Duration.zero;
    _pauseAfterMeters = 0;
    await _runRoute();
  }
}
