/// Zentrale Konfiguration der Hunde-App.
///
/// Die App läuft ohne jede Konfiguration sofort los – dann liegen alle
/// Daten nur lokal im Browser des jeweiligen Geräts. Sobald die
/// Firebase-Werte per `--dart-define` mitgegeben werden, schaltet die
/// App automatisch auf die geteilte Cloud-Datenbank um, sodass mehrere
/// Personen auf mehreren Geräten denselben Stand sehen:
///
///   flutter run \
///     --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_AUTH_DOMAIN=... \
///     --dart-define=FIREBASE_PROJECT_ID=... \
///     --dart-define=FIREBASE_STORAGE_BUCKET=... \
///     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///     --dart-define=FIREBASE_APP_ID=...
///
/// Diese Werte sind keine Geheimnisse – sie identifizieren nur das
/// Projekt. Der Zugriffsschutz passiert über die Firestore-Regeln.
class AppConfig {
  AppConfig._();

  static const String firebaseApiKey =
      String.fromEnvironment('FIREBASE_API_KEY');
  static const String firebaseAuthDomain =
      String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseAppId =
      String.fromEnvironment('FIREBASE_APP_ID');

  /// Nur wenn alle Pflichtwerte da sind, ist ein Cloud-Start möglich.
  static bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseAppId.isNotEmpty;

  /// Alle Daten liegen unter `haushalte/<id>/…`. So können später
  /// mehrere Familien dieselbe Installation nutzen, ohne sich zu
  /// sehen – und der Wechsel auf einen anderen Haushalt ist nur ein
  /// anderer Pfad, kein Datenumbau.
  static const String defaultHouseholdId = 'standard';

  /// Fotos werden vor dem Speichern auf diese Kantenlänge verkleinert.
  /// Reicht für die Verlaufsansicht locker und hält den lokalen
  /// Browser-Speicher (~5 MB) lange durch.
  static const int photoMaxEdge = 900;
  static const int photoJpegQuality = 78;
}
