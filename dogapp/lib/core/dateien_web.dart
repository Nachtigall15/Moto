import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Bietet [daten] als Download an.
///
/// Der Umweg über einen unsichtbaren Link ist im Browser der übliche
/// Weg: Es gibt keine Programmierschnittstelle zum Speichern, nur den
/// Klick, den man selbst auslöst.
Future<void> speichereDatei(
  String dateiname,
  Uint8List daten,
  String typ,
) async {
  final blob = web.Blob(
    <JSAny>[daten.toJS].toJS,
    web.BlobPropertyBag(type: typ),
  );
  final adresse = web.URL.createObjectURL(blob);

  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = adresse
    ..download = dateiname
    ..style.display = 'none';
  web.document.body!.appendChild(link);
  link.click();
  link.remove();

  // Erst freigeben, wenn der Browser den Download angestoßen hat.
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(adresse);
}

/// Öffnet den Dateiauswahl-Dialog. Gibt null zurück, wenn abgebrochen
/// wird – was sich technisch nicht sauber erkennen lässt, weshalb das
/// Ergebnis erst kommt, wenn tatsächlich etwas gewählt wurde.
Future<Uint8List?> waehleDatei(String akzeptiert) {
  final fertig = Completer<Uint8List?>();

  final eingabe = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = akzeptiert
    ..style.display = 'none';

  eingabe.onchange = ((web.Event _) {
    final dateien = eingabe.files;
    if (dateien == null || dateien.length == 0) {
      if (!fertig.isCompleted) fertig.complete(null);
      return;
    }
    dateien.item(0)!.arrayBuffer().toDart.then((puffer) {
      if (!fertig.isCompleted) {
        fertig.complete(puffer.toDart.asUint8List());
      }
    });
  }).toJS;

  web.document.body!.appendChild(eingabe);
  eingabe.click();
  // Als Verweis übergeben ginge nicht: Browser-Methoden lassen sich
  // nicht als Funktionswert weiterreichen.
  return fertig.future.whenComplete(() => eingabe.remove());
}
