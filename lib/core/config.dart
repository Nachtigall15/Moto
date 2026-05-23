/// Zentrale Konfiguration / Endpunkte.
///
/// Routing läuft über die GraphHopper Directions API (Speed-Modus,
/// CORS-fähig → funktioniert im Browser). Keys beim Start mitgeben
/// (NICHT im Code hinterlegen/committen):
///   flutter run \
///     --dart-define=GRAPHHOPPER_API_KEY=dein_key \
///     --dart-define=TOMTOM_API_KEY=dein_key
/// Ohne GraphHopper-Key: kein Routing (Karte/Suche/Wetter laufen).
/// Ohne TomTom-Key ist nur der Verkehrs-Layer inaktiv.
class AppConfig {
  AppConfig._();

  static const String graphHopperApiKey =
      String.fromEnvironment('GRAPHHOPPER_API_KEY');

  static bool get hasRoutingKey => graphHopperApiKey.isNotEmpty;

  static const String tomTomApiKey =
      String.fromEnvironment('TOMTOM_API_KEY');

  static bool get hasTrafficKey => tomTomApiKey.isNotEmpty;

  // GraphHopper Directions API (Routing inkl. Höhendaten). Speed-Modus
  // – Custom Model/„flexible mode" ist im Free-Tarif gesperrt.
  static const String graphHopperRouteUrl =
      'https://graphhopper.com/api/1/route';

  // TomTom Traffic Incident Details v5 (Staus + Unfälle + Sperrungen).
  static const String tomTomIncidentsUrl =
      'https://api.tomtom.com/traffic/services/5/incidentDetails';

  // Nominatim – keyless Geocoding (OpenStreetMap). Fairer Gebrauch:
  // sinnvoller User-Agent + nicht für Massenanfragen verwenden.
  static const String nominatimSearchUrl =
      'https://nominatim.openstreetmap.org/search';

  // Overpass API – keyless POI/Blitzer-Abfragen aus OpenStreetMap.
  static const String overpassUrl =
      'https://overpass-api.de/api/interpreter';

  // Open-Meteo – keyless Wetter-Forecast (mehrere Koordinaten/Request).
  static const String openMeteoUrl =
      'https://api.open-meteo.com/v1/forecast';

  // Karten-Kacheln: OSM Standard. Bewusst ohne Subdomain-Rotation,
  // weil OSM heute HTTP/2 nutzt und die a/b/c-Hosts inzwischen als
  // deprecated gelten.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Pflicht laut OSM-Nutzungsregeln (identifiziert die App).
  static const String userAgent = 'moto-app/0.1 (motorcycle navigation MVP)';
}
