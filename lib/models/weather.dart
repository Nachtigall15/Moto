import 'package:latlong2/latlong.dart';

/// Wetter an einem Routenpunkt zur voraussichtlichen Ankunftszeit (ETA).
class WeatherSample {
  const WeatherSample({
    required this.position,
    required this.cumulativeMeters,
    required this.eta,
    required this.temperature,
    required this.precipitation,
    required this.weatherCode,
  });

  final LatLng position;
  final double cumulativeMeters;
  final DateTime eta;
  final double temperature;
  final double precipitation;
  final int weatherCode;

  bool get isRain => precipitation >= 0.2 || _rainCode(weatherCode);

  static bool _rainCode(int c) =>
      // WMO: 51-67 Niesel/Regen, 80-82 Schauer, 95-99 Gewitter,
      // 71-77/85-86 Schnee.
      (c >= 51 && c <= 67) ||
      (c >= 71 && c <= 77) ||
      (c >= 80 && c <= 99);

  String get condition {
    final c = weatherCode;
    if (c == 0) return 'Klar';
    if (c <= 3) return 'Bewölkt';
    if (c <= 48) return 'Nebel';
    if (c <= 67) return 'Regen';
    if (c <= 77) return 'Schnee';
    if (c <= 82) return 'Schauer';
    if (c <= 86) return 'Schneeschauer';
    return 'Gewitter';
  }
}

/// Ein zusammenhängender Regen-Abschnitt entlang der Route.
class RainWindow {
  const RainWindow({
    required this.startMeters,
    required this.endMeters,
    required this.startEta,
    required this.endEta,
  });

  final double startMeters;
  final double endMeters;
  final DateTime startEta;
  final DateTime endEta;

  Duration get duration => endEta.difference(startEta);
}

class RouteWeather {
  RouteWeather({required this.samples}) : rainWindows = _windows(samples);

  final List<WeatherSample> samples;
  final List<RainWindow> rainWindows;

  bool get hasRain => rainWindows.isNotEmpty;

  static List<RainWindow> _windows(List<WeatherSample> s) {
    final windows = <RainWindow>[];
    int? startIdx;
    for (var i = 0; i < s.length; i++) {
      if (s[i].isRain) {
        startIdx ??= i;
      } else if (startIdx != null) {
        windows.add(_window(s, startIdx, i - 1));
        startIdx = null;
      }
    }
    if (startIdx != null) {
      windows.add(_window(s, startIdx, s.length - 1));
    }
    return windows;
  }

  static RainWindow _window(List<WeatherSample> s, int a, int b) {
    return RainWindow(
      startMeters: s[a].cumulativeMeters,
      endMeters: s[b].cumulativeMeters,
      startEta: s[a].eta,
      endEta: s[b].eta,
    );
  }
}
