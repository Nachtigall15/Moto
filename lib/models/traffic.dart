import 'package:latlong2/latlong.dart';

enum TrafficKind { accident, jam, roadworks, closure, hazard, other }

/// Ein Verkehrsereignis (TomTom Incident). Framework-unabhängig.
class TrafficIncident {
  const TrafficIncident({
    required this.position,
    required this.kind,
    required this.description,
    required this.delaySeconds,
  });

  final LatLng position;
  final TrafficKind kind;
  final String description;
  final int delaySeconds;

  /// TomTom `iconCategory` -> Kategorie.
  /// 1 Unfall · 6 Stau · 7 Spur gesperrt · 8 Straße gesperrt ·
  /// 9 Baustelle · 2/3/4/5/10/11/14 = Gefahr/Wetter.
  static TrafficKind kindFromIconCategory(int code) {
    switch (code) {
      case 1:
        return TrafficKind.accident;
      case 6:
        return TrafficKind.jam;
      case 9:
        return TrafficKind.roadworks;
      case 7:
      case 8:
        return TrafficKind.closure;
      case 2:
      case 3:
      case 4:
      case 5:
      case 10:
      case 11:
      case 14:
        return TrafficKind.hazard;
      default:
        return TrafficKind.other;
    }
  }
}
