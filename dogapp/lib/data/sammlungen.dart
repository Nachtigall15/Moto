/// Namen aller gespeicherten Sammlungen an einer Stelle.
///
/// Vorher standen sie verstreut im Anwendungszustand. Für die
/// Sicherung müssen sie vollständig aufzählbar sein – sonst fehlt im
/// Export irgendwann eine Sammlung, ohne dass es jemandem auffällt,
/// und genau das merkt man erst beim Zurückspielen.
class Sammlungen {
  Sammlungen._();

  static const fuetterungen = 'fuetterungen';
  static const schlaf = 'schlaf';
  static const gewicht = 'gewicht';
  static const termine = 'termine';
  static const medikamente = 'medikamente';
  static const gaben = 'medikamentengaben';
  static const impfungen = 'impfungen';
  static const uebungen = 'uebungen';
  static const trainingseinheiten = 'trainingseinheiten';
  static const trainingsplaene = 'trainingsplaene';
  static const leckerli = 'leckerli';

  /// Reihenfolge egal, Vollständigkeit nicht.
  static const List<String> alle = [
    fuetterungen,
    schlaf,
    gewicht,
    termine,
    medikamente,
    gaben,
    impfungen,
    uebungen,
    trainingseinheiten,
    trainingsplaene,
    leckerli,
  ];

  /// Einzeldokumente (keine Sammlung).
  static const profil = 'profil';
}
