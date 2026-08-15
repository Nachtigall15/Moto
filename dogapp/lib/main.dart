import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/dog_repository.dart';
import 'data/local_repository.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deutsche Monats-/Wochentagsnamen für alle Datumsformate.
  await initializeDateFormatting('de_DE');

  // Solange keine Cloud-Konfiguration vorliegt, läuft die App
  // vollständig lokal weiter – der Umstieg ist später ein Austausch
  // dieser einen Zeile.
  final DogRepository repo = LocalRepository();
  final state = AppState(repo);
  await state.init();

  runApp(DogApp(state: state));
}
