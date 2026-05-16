import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/route_result.dart';
import '../models/weather.dart';

/// Wetter-Forecast entlang der Route über Open-Meteo (keyless).
///
/// Die Route wird in bis zu [maxSamples] Punkte zerlegt; je Punkt wird
/// die voraussichtliche Ankunftszeit (ETA) aus Abfahrtszeit + anteiliger
/// Fahrdauer (+ optionale Pause) geschätzt und das passende Stunden-
/// Wetter dort abgefragt. Open-Meteo erlaubt mehrere Koordinaten pro
/// Request -> nur ein Aufruf.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const int maxSamples = 12;

  Future<RouteWeather> forecastForRoute({
    required RouteResult route,
    required DateTime departure,
    double pauseAfterMeters = 0,
    Duration pause = Duration.zero,
  }) async {
    final pts = route.points;
    if (pts.isEmpty) return RouteWeather(samples: const []);

    final total = route.distanceMeters;
    final step = pts.length <= maxSamples
        ? 1
        : (pts.length / maxSamples).ceil();

    final sampled = <int>[];
    for (var i = 0; i < pts.length; i += step) {
      sampled.add(i);
    }
    if (sampled.last != pts.length - 1) sampled.add(pts.length - 1);

    DateTime etaAt(double cum) {
      final frac = total == 0 ? 0.0 : cum / total;
      var t = departure.add(
        Duration(milliseconds: (route.durationMillis * frac).round()),
      );
      if (cum > pauseAfterMeters && pause > Duration.zero) {
        t = t.add(pause);
      }
      return t;
    }

    final lats = <String>[];
    final lons = <String>[];
    for (final i in sampled) {
      lats.add(pts[i].position.latitude.toStringAsFixed(4));
      lons.add(pts[i].position.longitude.toStringAsFixed(4));
    }

    final lastEta = etaAt(pts.last.cumulativeMeters);
    final days = (lastEta.toUtc().difference(DateTime.now().toUtc()).inHours /
                24)
            .ceil() +
        2;

    final uri = Uri.parse(AppConfig.openMeteoUrl).replace(
      queryParameters: {
        'latitude': lats.join(','),
        'longitude': lons.join(','),
        'hourly': 'temperature_2m,precipitation,weather_code',
        'timezone': 'GMT',
        'forecast_days': days.clamp(1, 16).toString(),
      },
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Wetter-Abfrage fehlgeschlagen (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    final locations = decoded is List
        ? decoded.cast<Map<String, dynamic>>()
        : [decoded as Map<String, dynamic>];

    final samples = <WeatherSample>[];
    for (var s = 0; s < sampled.length; s++) {
      final loc = locations[math.min(s, locations.length - 1)];
      final hourly = loc['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List<dynamic>).cast<String>();
      final temps = (hourly['temperature_2m'] as List<dynamic>);
      final precs = (hourly['precipitation'] as List<dynamic>);
      final codes = (hourly['weather_code'] as List<dynamic>);

      final pt = pts[sampled[s]];
      final eta = etaAt(pt.cumulativeMeters);
      final idx = _nearestHour(times, eta.toUtc());

      samples.add(WeatherSample(
        position: pt.position,
        cumulativeMeters: pt.cumulativeMeters,
        eta: eta,
        temperature: (temps[idx] as num?)?.toDouble() ?? double.nan,
        precipitation: (precs[idx] as num?)?.toDouble() ?? 0.0,
        weatherCode: (codes[idx] as num?)?.toInt() ?? 0,
      ));
    }

    return RouteWeather(samples: samples);
  }

  int _nearestHour(List<String> isoTimes, DateTime targetUtc) {
    var best = 0;
    var bestDelta = const Duration(days: 9999);
    for (var i = 0; i < isoTimes.length; i++) {
      // Open-Meteo liefert bei timezone=GMT lokale=UTC-Zeit ohne Suffix.
      final t = DateTime.parse('${isoTimes[i]}Z');
      final delta = (t.difference(targetUtc)).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return best;
  }
}
