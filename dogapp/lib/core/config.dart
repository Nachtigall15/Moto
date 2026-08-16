/// Zentrale Konfiguration der Hunde-App.
///
/// Die Firebase-Werte stehen in `lib/firebase_options.dart` – hier
/// bleiben nur die Einstellungen, die das Verhalten der App steuern.
class AppConfig {
  AppConfig._();

  /// Alle Daten liegen unter `haushalte/<code>/…`. Welcher Haushalt
  /// gilt, entscheidet das Codewort, das beim ersten Start abgefragt
  /// wird (siehe `data/haushalt.dart`).

  /// Fotos werden vor dem Speichern auf diese Kantenlänge verkleinert.
  /// Reicht für die Verlaufsansicht locker und hält Speicher und
  /// Übertragung klein.
  static const int photoMaxEdge = 900;
  static const int photoJpegQuality = 78;
}
