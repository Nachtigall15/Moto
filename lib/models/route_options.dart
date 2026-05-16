/// Nutzer-Einstellungen für die Routenberechnung.
class RouteOptions {
  const RouteOptions({
    this.curviness = 0.5,
    this.avoidMotorways = true,
  });

  /// 0.0 = schnellste Strecke, 1.0 = maximal kurvig (mehr Fahrspaß,
  /// meist langsamer). Wird auf ein GraphHopper-Custom-Model gemappt.
  final double curviness;

  /// Autobahnen meiden – für Motorrad-Touren meist erwünscht.
  final bool avoidMotorways;

  RouteOptions copyWith({double? curviness, bool? avoidMotorways}) {
    return RouteOptions(
      curviness: curviness ?? this.curviness,
      avoidMotorways: avoidMotorways ?? this.avoidMotorways,
    );
  }
}
