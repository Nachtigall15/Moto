/// Nutzer-Einstellungen für die Routenberechnung.
class RouteOptions {
  const RouteOptions({
    this.curviness = 0.5,
    this.avoidMotorways = true,
  });

  /// 0.0 = schnellste Strecke, 1.0 = maximal kurvig. Aktuell ohne
  /// Wirkung: GraphHopper-Free kann kein Custom Model (flexible mode);
  /// es wird die schnellste Strecke berechnet.
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
