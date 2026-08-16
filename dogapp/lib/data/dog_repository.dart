import 'dart:typed_data';

/// Speicher-Abstraktion für alle Daten der App.
///
/// Die Oberfläche kennt nur dieses Interface. Dahinter steckt entweder
/// [LocalRepository] (nur dieses Gerät) oder – sobald die
/// Firebase-Konfiguration vorliegt – eine Cloud-Variante mit
/// Live-Synchronisation. Deshalb sind alle Lesezugriffe Streams: bei
/// der Cloud-Variante schiebt der Server Änderungen von anderen
/// Geräten von selbst nach, ohne dass die Screens etwas anders machen.
abstract class DogRepository {
  Future<void> init();

  /// Einzeldokument (z. B. das Hundeprofil).
  Stream<Map<String, dynamic>?> watchDoc(String id);
  Future<void> setDoc(String id, Map<String, dynamic> data);

  /// Sammlung gleichartiger Einträge (Fütterungen, Schlaf, Gewicht …).
  ///
  /// [sortierFeld] und [limit] begrenzen das Ergebnis auf die
  /// jüngsten Einträge. Ohne diese Begrenzung würde die App nach einem
  /// Jahr bei jedem Start mehrere tausend Fütterungen laden – langsam
  /// beim Öffnen und unnötig teuer, obwohl niemand die Fütterung vom
  /// letzten März sucht.
  Stream<List<Map<String, dynamic>>> watchCollection(
    String name, {
    String? sortierFeld,
    int? limit,
  });
  Future<void> upsert(String name, String id, Map<String, dynamic> data);
  Future<void> delete(String name, String id);

  /// Fotos werden getrennt von den Einträgen abgelegt, damit die
  /// Listen leicht bleiben. Zurück kommt eine Referenz, die im
  /// jeweiligen Eintrag landet.
  Future<String> putPhoto(String id, Uint8List bytes);
  Future<Uint8List?> getPhoto(String ref);
  Future<void> deletePhoto(String ref);

  /// Für die Statusanzeige in der Oberfläche.
  bool get isShared;
  String get backendLabel;
}
