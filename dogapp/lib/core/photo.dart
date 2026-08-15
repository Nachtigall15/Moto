import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'config.dart';

/// Verkleinert ein aufgenommenes/ausgewähltes Foto auf eine
/// vernünftige Kantenlänge und speichert es als JPEG.
///
/// Ohne diesen Schritt landen 3–5 MB pro Handyfoto im Speicher – der
/// Browser-Speicher wäre nach wenigen Bildern voll und die Cloud-Kosten
/// unnötig hoch. Die EXIF-Drehung wird vorher eingerechnet, sonst
/// liegen Hochkant-Fotos quer.
Uint8List? shrinkPhoto(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;

  final upright = img.bakeOrientation(decoded);
  final longestEdge =
      upright.width > upright.height ? upright.width : upright.height;

  final scaled = longestEdge <= AppConfig.photoMaxEdge
      ? upright
      : img.copyResize(
          upright,
          width: upright.width >= upright.height
              ? AppConfig.photoMaxEdge
              : null,
          height: upright.height > upright.width
              ? AppConfig.photoMaxEdge
              : null,
          interpolation: img.Interpolation.average,
        );

  return img.encodeJpg(scaled, quality: AppConfig.photoJpegQuality);
}
