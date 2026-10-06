import 'dart:typed_data';

/// Platzhalter für alles, was kein Browser ist – in Tests etwa.
Future<void> speichereDatei(
  String dateiname,
  Uint8List daten,
  String typ,
) async {
  throw UnsupportedError('Datei-Download gibt es nur im Browser.');
}

Future<Uint8List?> waehleDatei(String akzeptiert) async {
  throw UnsupportedError('Dateiauswahl gibt es nur im Browser.');
}
