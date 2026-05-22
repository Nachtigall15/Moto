/// Routen-Präferenz: schnellste oder kürzeste Strecke (über
/// GraphHopper-Alternativen ausgewählt).
enum RoutePreference { fastest, shortest }

/// Nutzer-Einstellungen für die Routenberechnung.
class RouteOptions {
  const RouteOptions({
    this.curviness = 0.5,
    this.avoidMotorways = true,
    this.preference = RoutePreference.fastest,
  });

  /// 0.0 = schnellste Strecke, 1.0 = maximal kurvig. Aktuell ohne
  /// Wirkung: GraphHopper-Free kann kein Custom Model (flexible mode);
  /// es wird die schnellste Strecke berechnet.
  final double curviness;

  /// Autobahnen meiden – für Motorrad-Touren meist erwünscht.
  final bool avoidMotorways;

  /// Schnellste vs. kürzeste Route. Wird über GraphHopper-Alternativen
  /// realisiert (mehrere Pfade, der jeweils passende wird gewählt).
  final RoutePreference preference;

  RouteOptions copyWith({
    double? curviness,
    bool? avoidMotorways,
    RoutePreference? preference,
  }) {
    return RouteOptions(
      curviness: curviness ?? this.curviness,
      avoidMotorways: avoidMotorways ?? this.avoidMotorways,
      preference: preference ?? this.preference,
    );
  }
}
