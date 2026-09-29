import 'package:dogapp/app.dart';
import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/data/sammlungen.dart';
import 'package:dogapp/features/stubenreinheit/stubenreinheit_screen.dart';
import 'package:dogapp/models/geschaeft.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:dogapp/state/bootstrap.dart';
import 'package:dogapp/state/stubenreinheit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fester Bezugspunkt: ein Mittwoch um 12 Uhr.
  final jetzt = DateTime(2026, 9, 30, 12);
  DateTime heuteUm(int h, [int m = 0]) => DateTime(2026, 9, 30, h, m);
  DateTime vorTagen(int tage, int h) => DateTime(2026, 9, 30 - tage, h);

  Geschaeft pipi(DateTime t, {Ort ort = Ort.draussen, bool gemeldet = false}) =>
      Geschaeft(
        zeitpunkt: t,
        art: Geschaeftsart.pipi,
        ort: ort,
        gemeldet: gemeldet,
      );
  Geschaeft kaki(DateTime t, {Ort ort = Ort.draussen}) =>
      Geschaeft(zeitpunkt: t, art: Geschaeftsart.kaki, ort: ort);

  group('Eintrag', () {
    test('übersteht den Weg durch JSON', () {
      final g = Geschaeft(
        zeitpunkt: heuteUm(8, 30),
        art: Geschaeftsart.kaki,
        ort: Ort.drinnen,
        gemeldet: true,
        notiz: 'nach dem Spielen',
      );
      final zurueck = Geschaeft.fromJson(g.toJson());
      expect(zurueck.id, g.id);
      expect(zurueck.zeitpunkt, g.zeitpunkt);
      expect(zurueck.art, Geschaeftsart.kaki);
      expect(zurueck.ort, Ort.drinnen);
      expect(zurueck.gemeldet, isTrue);
      expect(zurueck.notiz, 'nach dem Spielen');
      expect(zurueck.label, 'Kaki drinnen');
    });

    test('die Sammlung wird mitgesichert', () {
      expect(Sammlungen.alle, contains(Sammlungen.geschaefte));
    });
  });

  group('Tag', () {
    test('zählt Arten und Orte getrennt', () {
      final tag = stubenTag([
        pipi(heuteUm(8, 30)),
        kaki(heuteUm(8, 35)),
        pipi(heuteUm(10), ort: Ort.drinnen),
        pipi(heuteUm(11), gemeldet: true),
      ]);
      expect(tag.pipi, 3);
      expect(tag.kaki, 1);
      expect(tag.draussen, 3);
      expect(tag.drinnen, 1);
      expect(tag.gemeldet, 1);
      expect(quoteLabel(tag.quote), '75 %');
      expect(tag.zusammenfassung, '3× Pipi · 1× Kaki');
    });

    test('ohne Einträge gibt es keine Quote statt 0 %', () {
      expect(stubenTag(const []).quote, isNull);
      expect(quoteLabel(null), '–');
    });
  });

  group('Bilanz', () {
    test('Woche und Vorwoche werden getrennt gezählt', () {
      final b = stubenBilanz([
        pipi(heuteUm(8)),
        pipi(vorTagen(6, 9)),
        // Vorwoche: halb daneben
        pipi(vorTagen(7, 9)),
        pipi(vorTagen(10, 9), ort: Ort.drinnen),
        // Zu alt für beide
        pipi(vorTagen(20, 9), ort: Ort.drinnen),
      ], jetzt);

      expect(b.woche.gesamt, 2);
      expect(b.woche.quote, 1.0);
      expect(b.vorwoche.gesamt, 2);
      expect(b.vorwoche.quote, 0.5);
      expect(b.tage, hasLength(bilanzTage));
      expect(b.tage.first.$1, DateTime(2026, 9, 30));
      expect(b.tage.first.$2.gesamt, 1);
    });

    test('der Rhythmus lässt die Nacht außen vor', () {
      final b = stubenBilanz([
        pipi(vorTagen(1, 20)),
        // Nacht: 11 Stunden, darf nicht zählen
        pipi(heuteUm(7)),
        pipi(heuteUm(9)),
        pipi(heuteUm(11)),
        pipi(heuteUm(11, 30)),
      ], jetzt);

      // Abstände 2 h, 2 h, 30 min → Median 2 h
      expect(b.pipiAbstand, const Duration(hours: 2));
      expect(b.letztesPipi!.zeitpunkt, heuteUm(11, 30));
      expect(b.naechsterGang, heuteUm(13, 30));
    });

    test('zu wenige Pipis ergeben noch keinen Rhythmus', () {
      final b = stubenBilanz([pipi(heuteUm(8)), pipi(heuteUm(10))], jetzt);
      expect(b.pipiAbstand, isNull);
      expect(b.naechsterGang, isNull);
    });

    test('Tage ohne Missgeschick und wann es passiert', () {
      final b = stubenBilanz([
        pipi(vorTagen(3, 18), ort: Ort.drinnen),
        kaki(vorTagen(5, 18), ort: Ort.drinnen),
        pipi(vorTagen(4, 7), ort: Ort.drinnen),
        pipi(heuteUm(8)),
      ], jetzt);

      expect(b.tageOhneMissgeschick(jetzt), 3);
      expect(b.missgeschickStunden.first, (18, 2));
      expect(b.missgeschickStunden[1], (7, 1));
    });

    test('ohne Missgeschick gibt es keinen Zähler', () {
      final b = stubenBilanz([pipi(heuteUm(8))], jetzt);
      expect(b.tageOhneMissgeschick(jetzt), isNull);
    });
  });

  group('Zustand', () {
    late AppState state;

    setUp(() async {
      await initializeDateFormatting('de_DE');
      SharedPreferences.setMockInitialValues({});
      state = AppState(LocalRepository());
      await state.init();
    });

    test('Einträge landen neueste zuerst und lassen sich löschen', () async {
      final heute = DateTime.now();
      final erst = pipi(DateTime(heute.year, heute.month, heute.day, 0, 1));
      await state.saveGeschaeft(erst);
      await state.saveGeschaeft(kaki(erst.zeitpunkt.add(
        const Duration(minutes: 5),
      )));
      await Future<void>.delayed(Duration.zero);

      expect(state.geschaefte, hasLength(2));
      expect(state.geschaefte.first.art, Geschaeftsart.kaki);
      expect(state.geschaefteAm(heute), hasLength(2));

      await state.deleteGeschaeft(erst.id);
      await Future<void>.delayed(Duration.zero);
      expect(state.geschaefte, hasLength(1));
    });

    testWidgets('ein Tipp auf „Pipi draußen" trägt ein', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(home: StubenreinheitScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.text('Pipi draußen'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(state.geschaefte, hasLength(1));
      expect(state.geschaefte.single.label, 'Pipi draußen');
      expect(find.textContaining('eingetragen'), findsOneWidget);
    });

    testWidgets('der Reiter hängt im Alltag', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        DogApp(bootstrap: BootstrapController.bereit(state)),
      );
      await tester.pumpAndSettle();

      // Die Karte auf der Übersicht führt direkt hinein.
      expect(find.text('Stubenreinheit'), findsWidgets);
      final knopf = find.widgetWithText(TextButton, 'Übersicht');
      await tester.ensureVisible(knopf);
      await tester.pumpAndSettle();
      await tester.tap(knopf);
      await tester.pumpAndSettle();

      expect(find.text('Jetzt eintragen'), findsOneWidget);
    });
  });
}
