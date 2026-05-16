/// Zentrale Konfiguration / Endpunkte.
///
/// Routing läuft über BRouter (keyless, kurvig). Optionaler Key beim
/// Start nur noch für den TomTom-Verkehrslayer:
///   flutter run --dart-define=TOMTOM_API_KEY=dein_key
/// Ohne TomTom-Key ist lediglich der Verkehrs-Layer inaktiv – Routing,
/// Karte, Suche, Wetter & Höhenprofil funktionieren ohne jeden Key.
class AppConfig {
  AppConfig._();

  static const String tomTomApiKey =
      String.fromEnvironment('TOMTOM_API_KEY');

  static bool get hasTrafficKey => tomTomApiKey.isNotEmpty;

  // BRouter – keyless Motorrad-/Kurven-Routing inkl. Höhendaten.
  // Routing-Endpunkt + Upload-Endpunkt für generierte Custom-Profile.
  static const String brouterRouteUrl = 'https://brouter.de/brouter';
  static const String brouterUploadUrl =
      'https://brouter.de/brouter/profile';

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

  // OSM-Kartenkacheln.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Pflicht laut OSM-Nutzungsregeln (identifiziert die App).
  static const String userAgent = 'moto-app/0.1 (motorcycle navigation MVP)';
}
