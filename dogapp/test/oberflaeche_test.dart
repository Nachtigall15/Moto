import 'package:dogapp/app.dart';
import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/features/feeding/feeding_screen.dart';
import 'package:dogapp/features/sleep/sleep_screen.dart';
import 'package:dogapp/models/feeding_entry.dart';
import 'package:dogapp/models/sleep_entry.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:dogapp/state/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
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

  group('Tagessummen in der Liste', () {
    /// Einträge anlegen und auf die Zustellung durch den Stream warten.
    ///
    /// Muss durch [WidgetTester.runAsync] laufen: Im Widget-Test steht
    /// die Uhr still, ein schlichtes `await` auf den Speichervorgang
    /// käme deshalb nie zurück.
    Future<void> trageEin(
      WidgetTester tester,
      Future<void> Function() eintraege,
    ) async {
      await tester.runAsync(() async {
        await eintraege();
        await Future<void>.delayed(Duration.zero);
      });
    }

    Future<void> zeige(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Schlaf: vergangener Tag zeigt seine Gesamtdauer',
        (tester) async {
      final gestern = DateTime.now().subtract(const Duration(days: 1));
      final tag = DateTime(gestern.year, gestern.month, gestern.day);

      await trageEin(tester, () async {
        await state.saveSleep(SleepEntry(
          start: tag.add(const Duration(hours: 13)),
          ende: tag.add(const Duration(hours: 15)),
        ));
        await state.saveSleep(SleepEntry(
          start: tag.add(const Duration(hours: 21)),
          ende: tag.add(const Duration(hours: 22, minutes: 30)),
        ));
      });

      await zeige(tester, const SleepScreen());

      expect(find.text('3 h 30 min'), findsOneWidget);
      expect(find.text('2 Phasen'), findsOneWidget);
    });

    testWidgets('Futter: vergangener Tag zeigt seine Tagesmenge',
        (tester) async {
      final gestern = DateTime.now().subtract(const Duration(days: 1));
      final tag = DateTime(gestern.year, gestern.month, gestern.day, 8);

      await trageEin(tester, () async {
        await state.saveFeeding(
            FeedingEntry(zeitpunkt: tag, futter: 'Trocken', menge: 150));
        await state.saveFeeding(FeedingEntry(
            zeitpunkt: tag.add(const Duration(hours: 9)),
            futter: 'Nass',
            menge: 300));
      });

      await zeige(tester, const FeedingScreen());

      expect(find.text('450 g'), findsOneWidget);
      expect(find.text('2 Mahlzeiten'), findsOneWidget);
    });
  });
}
