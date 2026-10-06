/// Datei herunterladen und Datei auswählen.
///
/// Beides geht nur im Browser. Die Weiche sorgt dafür, dass der Rest
/// der App (und damit die Tests) auch ohne Browser übersetzt.
library;

export 'dateien_stub.dart' if (dart.library.js_interop) 'dateien_web.dart';
