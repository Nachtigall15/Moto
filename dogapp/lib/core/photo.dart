import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'config.dart';

/// Verkleinert ein aufgenommenes Foto und speichert es als JPEG.
///
/// Ohne diesen Schritt landen 3–5 MB pro Handyfoto in der Datenbank.
/// Die EXIF-Drehung wird vorher eingerechnet, sonst liegen
/// Hochkant-Fotos quer.
///
/// Zusätzlich greift eine Notbremse: Passt das Ergebnis nicht in
/// [AppConfig.photoMaxBytes], wird schrittweise stärker komprimiert
/// und am Ende auch verkleinert. Ein einzelnes riesiges Bild soll
/// nicht dazu führen, dass das Speichern kommentarlos scheitert.
Uint8List? shrinkPhoto(Uint8List raw) {
  // Beschädigte oder unbekannte Dateien lassen den Decoder nicht nur
  // null zurückgeben, sondern teilweise auch mit einer Ausnahme
  // abbrechen. Beides bedeutet dasselbe: kein Bild.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(raw);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;

  final upright = img.bakeOrientation(decoded);

  var kante = AppConfig.photoMaxEdge;
  var qualitaet = AppConfig.photoJpegQuality;
  var ergebnis = _kodiere(upright, kante, qualitaet);

  while (ergebnis.length > AppConfig.photoMaxBytes) {
    if (qualitaet > 45) {
      qualitaet -= 10;
    } else if (kante > 400) {
      kante = (kante * 0.8).round();
    } else {
      // Weiter zu verkleinern würde das Foto unbrauchbar machen.
      break;
    }
    ergebnis = _kodiere(upright, kante, qualitaet);
  }

  return ergebnis;
}

Uint8List _kodiere(img.Image bild, int maxKante, int qualitaet) {
  final laengsteSeite = bild.width > bild.height ? bild.width : bild.height;

  final skaliert = laengsteSeite <= maxKante
      ? bild
      : img.copyResize(
          bild,
          width: bild.width >= bild.height ? maxKante : null,
          height: bild.height > bild.width ? maxKante : null,
          interpolation: img.Interpolation.average,
        );

  return img.encodeJpg(skaliert, quality: qualitaet);
}
