import 'dart:typed_data';

import 'package:dogapp/core/config.dart';
import 'package:dogapp/core/photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Erzeugt ein Testbild mit Farbverlauf und Rauschen. Eine einfarbige
/// Fläche würde sich so gut komprimieren, dass die Größenbremse nie
/// anspringt – das Bild muss dem JPEG etwas zu tun geben.
Uint8List _testfoto(int breite, int hoehe) {
  final bild = img.Image(width: breite, height: hoehe);
  for (var y = 0; y < hoehe; y++) {
    for (var x = 0; x < breite; x++) {
      bild.setPixelRgb(
        x,
        y,
        (x * 7 + y * 3) % 256,
        (x * x + y) % 256,
        (x + y * y) % 256,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(bild, quality: 100));
}

void main() {
  group('Foto verkleinern', () {
    test('Handyfoto wird auf die Zielkante gebracht', () {
      final gross = _testfoto(3000, 2000);
      final klein = shrinkPhoto(gross)!;

      final bild = img.decodeImage(klein)!;
      expect(bild.width, AppConfig.photoMaxEdge);
      expect(bild.height, lessThan(AppConfig.photoMaxEdge));
      expect(klein.length, lessThan(gross.length));
    });

    test('Hochkant-Fotos werden an der Höhe ausgerichtet', () {
      final hochkant = shrinkPhoto(_testfoto(1200, 2400))!;
      final bild = img.decodeImage(hochkant)!;

      expect(bild.height, AppConfig.photoMaxEdge);
      expect(bild.width, lessThan(AppConfig.photoMaxEdge));
    });

    test('kleine Bilder werden nicht künstlich vergrößert', () {
      final winzig = shrinkPhoto(_testfoto(300, 200))!;
      final bild = img.decodeImage(winzig)!;

      expect(bild.width, 300);
      expect(bild.height, 200);
    });

    test('Ergebnis passt in ein Datenbankdokument', () {
      // Sonst scheitert das Speichern in Firestore kommentarlos.
      for (final foto in [
        _testfoto(4000, 3000),
        _testfoto(1600, 1600),
        _testfoto(900, 600),
      ]) {
        final klein = shrinkPhoto(foto)!;
        expect(klein.length, lessThanOrEqualTo(AppConfig.photoMaxBytes));

        // Auch nach der Base64-Kodierung muss Luft zum 1-MiB-Limit
        // bleiben – die bläht die Daten um ein Drittel auf.
        expect((klein.length * 4 / 3).round(), lessThan(1024 * 1024));
      }
    });

    test('kaputte Daten geben null statt einer Ausnahme', () {
      expect(shrinkPhoto(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    });
  });
}
