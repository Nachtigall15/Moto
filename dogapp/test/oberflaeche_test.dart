import 'package:dogapp/app.dart';
import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:dogapp/state/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diese Tests halten fest, dass Fenster, die über der Navigation
/// geöffnet werden, den Anwendungszustand finden.
///
/// Genau daran ist die App einmal gescheitert: Der Zustand hing
/// unterhalb der MaterialApp, Dialoge und Eingabefenster hängen aber
/// am selben Navigator wie die Startseite und sind deren Geschwister,
/// nicht deren Kinder. Jedes Eingabefenster stürzte beim Öffnen ab –
/// im Release-Build sichtbar nur als grauer Kasten.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;

  setUp(() async {
    await initializeDateFormatting('de_DE');
    SharedPreferences.setMockInitialValues({});
    state = AppState(LocalRepository());
    await state.init();
  });

  Future<void> starteApp(WidgetTester tester) async {
    await tester.pumpWidget(
      DogApp(bootstrap: BootstrapController.bereit(state)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('die Übersicht baut sich auf', (tester) async {
    await starteApp(tester);
    expect(find.text('Übersicht'), findsWidgets);
  });

  testWidgets('der Heimtierausweis öffnet sich als eigene Seite',
      (tester) async {
    await starteApp(tester);

    await tester.tap(find.byIcon(Icons.badge_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Heimtierausweis'), findsOneWidget);
  });

  testWidgets('das Bearbeiten-Fenster findet den Zustand', (tester) async {
    await starteApp(tester);

    await tester.tap(find.byIcon(Icons.badge_outlined).first);
    await tester.pumpAndSettle();

    // Dieser Schritt liest den Zustand aus einer weiteren Route –
    // ohne den Zustand über der MaterialApp fliegt hier alles auseinander.
    await tester.tap(find.text('Angaben eintragen'));
    await tester.pumpAndSettle();

    expect(find.text('Angaben bearbeiten'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Rasse'), findsOneWidget);
  });

  testWidgets('die Sicherungsseite öffnet sich', (tester) async {
    await starteApp(tester);

    await tester.tap(find.byIcon(Icons.save_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Sicherung herunterladen'), findsOneWidget);
  });
}
