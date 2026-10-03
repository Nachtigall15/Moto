import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'state/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deutsche Monats-/Wochentagsnamen für alle Datumsformate.
  await initializeDateFormatting('de_DE');

  // Der Start läuft asynchron weiter: Die Oberfläche kommt sofort und
  // zeigt so lange eine Ladeanzeige, statt vor einem weißen Bildschirm
  // auf die Verbindung zu warten.
  final bootstrap = BootstrapController();
  runApp(DogApp(bootstrap: bootstrap));
  await bootstrap.start();
}
