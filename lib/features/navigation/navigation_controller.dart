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

  void setRoutePreference(RoutePreference value) {
    if (options.preference == value) return;
    options = options.copyWith(preference: value);
    notifyListeners();
    // Wenn bereits eine Route existiert, passend neu berechnen, damit
    // die Auswahl spürbar greift.
    if (route != null) {
      _runRoute(loadWeather: false);
    }
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

  Future<void> _runRoute({
    List<LatLng> via = const [],
    bool loadWeather = true,
  }) async {
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
      if (loadWeather) {
        await _loadWeather();
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

  /// Plant eine Pause so, dass man möglichst lange trocken fährt, kurz
  /// vor dem Regen an einer Rastmöglichkeit hält und dort genau so
  /// lange wartet, bis die regnerischen Abschnitte danach abgeklungen
  /// sind (adaptiv, mit Ober-/Untergrenze).
  Future<void> suggestPause() async {
    final r = route;
    final w = weather;
    if (r == null || w == null || !w.hasRain) return;

    loading = true;
    weatherError = null;
    notifyListeners();

    try {
      final rainStart = w.rainWindows.first.startMeters;
      if (rainStart < 1500) {
        weatherError =
            'Regen bereits ab dem Start – eine Pause hilft hier kaum.';
        return;
      }

      // Rastmöglichkeiten nur im trockenen Abschnitt vor dem Regen.
      final prePositions = r.points
          .where((p) => p.cumulativeMeters <= rainStart)
          .map((p) => p.position)
          .toList();
      final candidates = await _poi
          .poisInBounds(boundsOf(prePositions), {PoiCategory.restStop});

      Poi? stop;
      var stopMeters = -1.0;
      for (final c in candidates) {
        final np = r.nearestTo(c.position);
        final offRoute = haversineMeters(c.position, np.position);
        // Nah an der Route und spätestmöglich, aber sicher vor Regen.
        if (offRoute <= 1500 &&
            np.cumulativeMeters < rainStart - 500 &&
            np.cumulativeMeters > stopMeters) {
          stop = c;
          stopMeters = np.cumulativeMeters;
        }
      }
      // Fallback: nächste Rast ~3 km vor Regenbeginn.
      stop ??= await _poi.nearestRestStop(
        r
            .pointAtDistance((rainStart - 3000).clamp(0.0, r.distanceMeters))
            .position,
      );
      if (stop == null) {
        weatherError = 'Keine Rastmöglichkeit vor dem Regen gefunden.';
        return;
      }

      // Stopp als Wegpunkt einbauen (Wetter erst nach Wartezeit-Tuning).
      pauseStop = stop;
      await _runRoute(via: [stop.position], loadWeather: false);
      final nr = route;
      if (nr == null) return; // _runRoute hat error gesetzt
      _pauseAfterMeters = nr.nearestTo(stop.position).cumulativeMeters;

      // Adaptive Wartezeit: erhöhen, bis nach dem Stopp kein Regen mehr
      // auf der Route liegt (max. 4 h).
      const stepMin = 30;
      const maxMin = 240;
      var waitMin = 15;
      RouteWeather? best;
      while (true) {
        final cand = await _weather.forecastForRoute(
          route: nr,
          departure: departure,
          pauseAfterMeters: _pauseAfterMeters,
          pause: Duration(minutes: waitMin),
        );
        best = cand;
        final rainAfter = cand.samples.any(
          (s) => s.cumulativeMeters >= _pauseAfterMeters && s.isRain,
        );
        if (!rainAfter || waitMin >= maxMin) break;
        waitMin += stepMin;
      }
      pauseDuration = Duration(minutes: waitMin);
      weather = best;
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
