/// Zentrale Konfiguration / Endpunkte.
///
/// Den GraphHopper-Key beim Start mitgeben:
///   flutter run --dart-define=GRAPHHOPPER_API_KEY=dein_key
/// Ohne Key funktionieren Karte + Adresssuche; nur die Routenberechnung
/// meldet dann einen klaren Hinweis statt einer Route.
class AppConfig {
  AppConfig._();

  static const String graphHopperApiKey =
      String.fromEnvironment('GRAPHHOPPER_API_KEY');

  static bool get hasRoutingKey => graphHopperApiKey.isNotEmpty;

  // GraphHopper Directions API (Routing inkl. Höhendaten + Custom Model).
  static const String graphHopperRouteUrl =
      'https://graphhopper.com/api/1/route';

  // Nominatim – keyless Geocoding (OpenStreetMap). Fairer Gebrauch:
  // sinnvoller User-Agent + nicht für Massenanfragen verwenden.
  static const String nominatimSearchUrl =
      'https://nominatim.openstreetmap.org/search';

  // Overpass API – keyless POI/Blitzer-Abfragen aus OpenStreetMap.
  static const String overpassUrl =
      'https://overpass-api.de/api/interpreter';

  // OSM-Kartenkacheln.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Pflicht laut OSM-Nutzungsregeln (identifiziert die App).
  static const String userAgent = 'moto-app/0.1 (motorcycle navigation MVP)';
}
