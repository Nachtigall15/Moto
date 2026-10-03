import 'package:firebase_core/firebase_core.dart';

/// Firebase-Konfiguration der App (Projekt `bheki-dog`, Web).
///
/// Diese Werte sind keine Geheimnisse – sie stehen in jeder Web-App im
/// Quelltext und benennen nur das Projekt. Der Zugriffsschutz passiert
/// über die Regeln in `firestore.rules` und `storage.rules`.
///
/// Inhaltlich dasselbe, was `flutterfire configure --platforms=web`
/// erzeugt hätte; wer den Befehl später doch laufen lässt, darf die
/// Datei bedenkenlos überschreiben.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDxs91bqlzHO7-LSd64kMc8DxA1tKtsL44',
    authDomain: 'bheki-dog.firebaseapp.com',
    projectId: 'bheki-dog',
    storageBucket: 'bheki-dog.firebasestorage.app',
    messagingSenderId: '837173292462',
    appId: '1:837173292462:web:992f3b2bf2474994b82c3f',
    measurementId: 'G-TE9G4N2VB9',
  );
}
