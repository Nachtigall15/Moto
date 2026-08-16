import 'package:firebase_core/firebase_core.dart';

import 'core/config.dart';

/// Firebase-Konfiguration der App.
///
/// **Diese Datei ist ein Platzhalter und darf überschrieben werden.**
/// Der übliche Weg ist:
///
///     cd dogapp
///     flutterfire configure --project=bheki-dog --platforms=web
///
/// Danach steht hier die von FlutterFire erzeugte Fassung mit den
/// echten Projektwerten, und die App startet ohne weiteres Zutun im
/// Cloud-Modus. Bis dahin liest der Platzhalter dieselben Werte aus
/// `--dart-define` (siehe `core/config.dart`); fehlen sie, bleibt die
/// App im lokalen Modus.
///
/// Die Werte sind keine Geheimnisse – sie benennen nur das Projekt.
/// Der Zugriffsschutz passiert über die Firestore-Regeln
/// (`firestore.rules`).
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        authDomain: AppConfig.firebaseAuthDomain,
        projectId: AppConfig.firebaseProjectId,
        storageBucket: AppConfig.firebaseStorageBucket,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        appId: AppConfig.firebaseAppId,
      );
}
