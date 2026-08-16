/// Zentrale Konfiguration der Hunde-App.
///
/// Die Firebase-Werte stehen in `lib/firebase_options.dart` – hier
/// bleiben nur die Einstellungen, die das Verhalten der App steuern.
class AppConfig {
  AppConfig._();

  /// Alle Daten liegen unter `haushalte/<id>/…`. Ein fester Wert
  /// genügt: Wer die Daten sehen darf, entscheiden die Konten und die
  /// Regeln in `firestore.rules`, nicht der Pfad. Die Ebene bleibt
  /// trotzdem im Datenmodell, damit später ein zweiter Hund oder
  /// Haushalt danebenpasst, ohne alles umzubauen.
  static const String haushalt = 'bheki';

  /// Wie viele Einträge je Sammlung geladen werden.
  ///
  /// Die App zeigt einen Ausschnitt der jüngsten Vergangenheit, nicht
  /// das komplette Archiv. Ohne Begrenzung lädt sie nach einem Jahr
  /// bei jedem Start mehrere tausend Einträge – langsam und unnötig.
  /// Die Werte sind so gewählt, dass jeweils grob ein Vierteljahr
  /// abgedeckt ist; ältere Einträge bleiben gespeichert und tauchen
  /// wieder auf, sobald die Grenze angehoben wird.
  ///
  /// Gewicht ist die Ausnahme: Messungen gibt es selten, und der
  /// Entwicklungsverlauf lebt gerade davon, weit zurückzureichen.
  static const int limitFuetterungen = 400;
  static const int limitSchlaf = 400;
  static const int limitGewicht = 400;
  static const int limitTermine = 300;
  static const int limitGaben = 500;
  static const int limitTraining = 500;

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
