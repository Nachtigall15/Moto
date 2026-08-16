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
  /// Reicht für den Entwicklungsverlauf locker.
  static const int photoMaxEdge = 800;
  static const int photoJpegQuality = 72;

  /// Obergrenze für ein gespeichertes Foto.
  ///
  /// Fotos liegen als Daten direkt im Datenbankeintrag, damit die App
  /// ohne Cloud Storage auskommt – und damit ohne kostenpflichtigen
  /// Tarif. Ein Firestore-Dokument darf 1 MiB groß sein; die
  /// Base64-Kodierung bläht die Daten um ein Drittel auf. 600 kB roh
  /// lassen also reichlich Luft. Übliche Handyfotos landen nach dem
  /// Verkleinern bei rund einem Zehntel davon – die Grenze ist eine
  /// Notbremse, kein Regelfall.
  static const int photoMaxBytes = 600 * 1024;
}
