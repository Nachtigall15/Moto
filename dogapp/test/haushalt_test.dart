import 'package:dogapp/data/haushalt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Haushalts-Code', () {
    test('unterschiedliche Schreibweisen meinen denselben Haushalt', () {
      // Sonst sitzt eine Person allein in einem leeren Datenbestand,
      // nur weil sie großgeschrieben oder ein Leerzeichen getippt hat.
      const erwartet = 'bheki-zuhause';
      for (final eingabe in [
        'bheki-zuhause',
        'Bheki Zuhause',
        '  BHEKI   zuhause  ',
        'bheki_zuhause',
        'bheki--zuhause',
        'Bheki-Zuhause!',
      ]) {
        expect(Haushalt.normalisiere(eingabe), erwartet, reason: eingabe);
      }
    });

    test('Umlaute werden umgeschrieben statt entfernt', () {
      expect(Haushalt.normalisiere('Hündin Küche'), 'huendin-kueche');
      expect(Haushalt.normalisiere('straße'), 'strasse');
    });

    test('zu kurze Eingaben werden abgelehnt', () {
      expect(Haushalt.istGueltig('abc'), isFalse);
      expect(Haushalt.istGueltig('---'), isFalse);
      expect(Haushalt.istGueltig('abcd'), isTrue);
    });

    test('Code taugt als Pfad in der Datenbank', () {
      final code = Haushalt.normalisiere('Bheki / Zuhause 2026');
      expect(code.contains('/'), isFalse);
      expect(code, 'bheki-zuhause-2026');
    });
  });
}
