import 'package:shared_preferences/shared_preferences.dart';

/// Der Haushalts-Code entscheidet, welche Daten ein Gerät sieht.
///
/// Er wird einmal pro Gerät eingegeben und danach lokal gemerkt. Weil
/// er als Pfad in der Datenbank landet, wird er streng normalisiert –
/// „Bheki 2026" und „bheki-2026" sollen denselben Haushalt meinen und
/// nicht zwei getrennte Datenbestände anlegen.
class Haushalt {
  Haushalt._();

  static const _key = 'hund:haushalt';
  static const int minLaenge = 4;

  /// Kleinschreibung, Leerzeichen zu Bindestrichen, alles andere außer
  /// Buchstaben, Ziffern und Bindestrich fliegt raus.
  static String normalisiere(String eingabe) {
    final klein = eingabe.trim().toLowerCase();
    final ersetzt = klein
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[\s_]+'), '-');
    return ersetzt
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static bool istGueltig(String eingabe) =>
      normalisiere(eingabe).length >= minLaenge;

  static Future<String?> lies() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null || code.isEmpty) return null;
    return code;
  }

  static Future<void> speichere(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalisiere(code));
  }

  static Future<void> vergiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
