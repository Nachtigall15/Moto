import 'dart:typed_data';

import 'package:dogapp/core/format.dart';
import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/models/dog_profile.dart';
import 'package:dogapp/models/feeding_entry.dart';
import 'package:dogapp/models/sleep_entry.dart';
import 'package:dogapp/models/weight_entry.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;

  /// Die Listen kommen über Streams – nach einer Änderung braucht die
  /// Zustellung eine Runde in der Event-Loop.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    // Die Zeitangaben der Abschnitte werden deutsch formatiert.
    await initializeDateFormatting('de_DE');
    SharedPreferences.setMockInitialValues({});
    state = AppState(LocalRepository());
    await state.init();
  });

  group('Fütterung', () {
    test('Einträge liegen neueste zuerst und zählen pro Einheit', () async {
      final heute = DateTime.now();
      await state.saveFeeding(FeedingEntry(
        zeitpunkt: heute.subtract(const Duration(hours: 3)),
        futter: 'Trockenfutter',
        menge: 150,
      ));
      await state.saveFeeding(FeedingEntry(
        zeitpunkt: heute,
        futter: 'Nassfutter',
        menge: 200,
      ));
      await state.saveFeeding(FeedingEntry(
        zeitpunkt: heute,
        futter: 'Kausnack',
        menge: 1,
        einheit: Einheit.stueck,
        mahlzeit: Mahlzeit.leckerli,
      ));

      await settle();

      expect(state.feedings.first.futter, 'Nassfutter');
      expect(state.feedingsOn(heute), hasLength(3));

      // Gramm und Stück dürfen nicht in einer Summe landen.
      final totals = state.totalsOn(heute);
      expect(totals[Einheit.gramm], 350);
      expect(totals[Einheit.stueck], 1);
    });

    test('Futtersorten werden ohne Dubletten vorgeschlagen', () async {
      final now = DateTime.now();
      await state.saveFeeding(
        FeedingEntry(zeitpunkt: now, futter: 'Trockenfutter', menge: 100),
      );
      await state.saveFeeding(
        FeedingEntry(
          zeitpunkt: now.add(const Duration(minutes: 1)),
          futter: 'Trockenfutter',
          menge: 120,
        ),
      );

      await settle();

      expect(state.bekannteFuttersorten, ['Trockenfutter']);
    });

    test('die häufigsten Fütterungen stehen als Vorlage bereit', () async {
      final jetzt = DateTime.now();
      Future<void> futter(
        String name,
        double menge,
        int vorStunden, {
        Mahlzeit mahlzeit = Mahlzeit.fruehstueck,
        Einheit einheit = Einheit.gramm,
      }) =>
          state.saveFeeding(FeedingEntry(
            zeitpunkt: jetzt.subtract(Duration(hours: vorStunden)),
            futter: name,
            menge: menge,
            einheit: einheit,
            mahlzeit: mahlzeit,
          ));

      // Dreimal dasselbe Frühstück …
      await futter('Trockenfutter', 150, 72);
      await futter('Trockenfutter', 150, 48);
      await futter('Trockenfutter', 150, 24);
      // … zweimal dasselbe Abendessen …
      await futter('Nassfutter', 300, 60, mahlzeit: Mahlzeit.abendessen);
      await futter('Nassfutter', 300, 36, mahlzeit: Mahlzeit.abendessen);
      // … einmal ein Kausnack …
      await futter('Kausnack', 1, 12,
          mahlzeit: Mahlzeit.leckerli, einheit: Einheit.stueck);
      // … und einmal dieselbe Sorte mit anderer Menge: eigene Vorlage.
      await futter('Trockenfutter', 90, 6);
      // Ohne Menge taucht nichts als komplette Vorlage auf.
      await futter('Reste', 0, 3);

      await settle();

      final vorlagen = state.futterVorlagen();
      final komplett = vorlagen.where((v) => v.istKomplett).toList();

      expect(komplett, hasLength(3));
      expect(komplett[0].futter, 'Trockenfutter');
      expect(komplett[0].menge, 150);
      expect(komplett[0].mahlzeit, Mahlzeit.fruehstueck);
      expect(komplett[0].anzahl, 3);
      expect(komplett[0].details, '150 g · Frühstück');

      expect(komplett[1].futter, 'Nassfutter');
      expect(komplett[1].anzahl, 2);

      // Gleich häufig (je einmal): das zuletzt Gefütterte zuerst.
      expect(komplett[2].futter, 'Trockenfutter');
      expect(komplett[2].menge, 90);

      // Danach die übrigen Sorten als reine Namen, ohne Dubletten.
      final namen = vorlagen.where((v) => !v.istKomplett).map((v) => v.futter);
      expect(namen, containsAll(['Kausnack', 'Reste']));
      expect(namen, isNot(contains('Nassfutter')));
    });

    test('ohne Fütterungen gibt es keine Vorlagen', () {
      expect(state.futterVorlagen(), isEmpty);
    });

    test('Löschen entfernt den Eintrag', () async {
      final entry =
          FeedingEntry(zeitpunkt: DateTime.now(), futter: 'Test', menge: 10);
      await state.saveFeeding(entry);
      await settle();
      expect(state.feedings, hasLength(1));

      await state.deleteFeeding(entry.id);
      await settle();
      expect(state.feedings, isEmpty);
    });
  });

  group('Schlaf', () {
    test('Start und Ende bilden eine abgeschlossene Phase', () async {
      await state.startSleep();
      await settle();
      expect(state.laufenderSchlaf, isNotNull);

      // Ein zweiter Start darf keine parallele Phase anlegen.
      await state.startSleep();
      await settle();
      expect(state.sleeps, hasLength(1));

      await state.stopSleep();
      await settle();
      expect(state.laufenderSchlaf, isNull);
      expect(state.sleeps.single.laeuft, isFalse);
    });

    test('Tagessumme zählt nur beendete Phasen', () async {
      final heute = DateTime.now();
      await state.saveSleep(SleepEntry(
        start: heute.subtract(const Duration(hours: 3)),
        ende: heute.subtract(const Duration(hours: 1)),
      ));
      await state.saveSleep(SleepEntry(start: heute));

      await settle();

      expect(state.sleepsOn(heute), hasLength(2));
      expect(state.sleepTotalOn(heute), const Duration(hours: 2));
    });
  });

  group('Tagessummen vergangener Tage', () {
    test('Schlaf: jeder Tag wird für sich summiert', () async {
      final vorgestern = DateTime.now().subtract(const Duration(days: 2));
      final tag = DateTime(vorgestern.year, vorgestern.month, vorgestern.day);

      // 22:00–23:30 und 13:00–15:00 am selben Tag = 3 h 30 min.
      await state.saveSleep(SleepEntry(
        start: tag.add(const Duration(hours: 22)),
        ende: tag.add(const Duration(hours: 23, minutes: 30)),
      ));
      await state.saveSleep(SleepEntry(
        start: tag.add(const Duration(hours: 13)),
        ende: tag.add(const Duration(hours: 15)),
      ));
      // Ein anderer Tag darf nicht mitzählen.
      await state.saveSleep(SleepEntry(
        start: tag.subtract(const Duration(hours: 5)),
        ende: tag.subtract(const Duration(hours: 1)),
      ));

      await settle();

      expect(
        state.sleepTotalOn(tag),
        const Duration(hours: 3, minutes: 30),
      );
      expect(
        schlafSumme(state.schlafAbschnitteAm(tag)),
        state.sleepTotalOn(tag),
      );
    });

    test('Schlaf: eine laufende Phase bleibt außen vor', () {
      final vorTagen = DateTime.now().subtract(const Duration(days: 3));
      final tag = DateTime(vorTagen.year, vorTagen.month, vorTagen.day);
      final summe = schlafSumme([
        ...zerlegeNachTagen(SleepEntry(
          start: tag.add(const Duration(hours: 10)),
          ende: tag.add(const Duration(hours: 12)),
        )),
        // Ohne Ende: läuft noch.
        ...zerlegeNachTagen(
          SleepEntry(start: tag.add(const Duration(hours: 14))),
          jetzt: tag.add(const Duration(hours: 16)),
        ),
      ]);

      expect(summe, const Duration(hours: 2));
    });

    test('Futter: Gramm und Stück bleiben getrennt und in fester Folge', () {
      final tag = DateTime.now().subtract(const Duration(days: 4));
      final summen = futterSumme([
        FeedingEntry(
          zeitpunkt: tag,
          futter: 'Kausnack',
          menge: 2,
          einheit: Einheit.stueck,
          mahlzeit: Mahlzeit.leckerli,
        ),
        FeedingEntry(zeitpunkt: tag, futter: 'Trockenfutter', menge: 250),
        FeedingEntry(zeitpunkt: tag, futter: 'Nassfutter', menge: 200),
      ]);

      expect(summen[Einheit.gramm], 450);
      expect(summen[Einheit.stueck], 2);
      // Gramm zuerst, unabhängig davon, was zuerst eingetragen wurde.
      expect(summen.keys.toList(), [Einheit.gramm, Einheit.stueck]);
      expect(futterSummeLabel(summen), '450 g · 2 Stück');
    });

    test('Futter: Tagessumme eines vergangenen Tages', () async {
      final gestern = DateTime.now().subtract(const Duration(days: 1));
      final tag = DateTime(gestern.year, gestern.month, gestern.day, 8);

      await state.saveFeeding(
          FeedingEntry(zeitpunkt: tag, futter: 'Trocken', menge: 150));
      await state.saveFeeding(FeedingEntry(
          zeitpunkt: tag.add(const Duration(hours: 10)),
          futter: 'Nass',
          menge: 300));
      // Heute – darf die Summe von gestern nicht verändern.
      await state.saveFeeding(FeedingEntry(
          zeitpunkt: DateTime.now(), futter: 'Trocken', menge: 999));

      await settle();

      expect(futterSummeLabel(state.totalsOn(tag)), '450 g');
    });

    test('Futter: leere Summe ergibt einen leeren Text', () {
      expect(futterSummeLabel(futterSumme(const [])), '');
    });
  });

  group('Nacht über Mitternacht', () {
    /// 22:00 bis 6:00 – die klassische Nacht per „Schläft jetzt" und
    /// „Aufgewacht" gebucht.
    SleepEntry nacht(DateTime tag) => SleepEntry(
          start: tag.add(const Duration(hours: 22)),
          ende: DateTime(tag.year, tag.month, tag.day + 1, 6),
        );

    test('wird an der Tagesgrenze in zwei Abschnitte geteilt', () {
      final tag = DateTime(2026, 3, 10);
      final abschnitte = zerlegeNachTagen(nacht(tag));

      expect(abschnitte, hasLength(2));

      expect(abschnitte[0].tag, tag);
      expect(abschnitte[0].dauer, const Duration(hours: 2));
      expect(abschnitte[0].gehtWeiter, isTrue);
      expect(abschnitte[0].kommtVonGestern, isFalse);
      expect(abschnitte[0].zeitLabel, '22:00 – 24:00 Uhr');

      expect(abschnitte[1].tag, DateTime(2026, 3, 11));
      expect(abschnitte[1].dauer, const Duration(hours: 6));
      expect(abschnitte[1].kommtVonGestern, isTrue);
      expect(abschnitte[1].gehtWeiter, isFalse);
      expect(abschnitte[1].zeitLabel, '00:00 – 06:00 Uhr');
    });

    test('zählt auf beide Tage statt komplett auf den ersten', () async {
      final gestern = DateTime.now().subtract(const Duration(days: 2));
      final tag = DateTime(gestern.year, gestern.month, gestern.day);
      final folgetag = DateTime(tag.year, tag.month, tag.day + 1);

      await state.saveSleep(nacht(tag));
      await settle();

      expect(state.sleepTotalOn(tag), const Duration(hours: 2));
      expect(state.sleepTotalOn(folgetag), const Duration(hours: 6));

      // Die Nacht taucht an beiden Tagen auf – geschlafen hat er an
      // beiden.
      expect(state.sleepsOn(tag), hasLength(1));
      expect(state.sleepsOn(folgetag), hasLength(1));

      // Gespeichert bleibt eine einzige Phase.
      expect(state.sleeps, hasLength(1));
      expect(state.sleeps.single.dauer, const Duration(hours: 8));
    });

    test('endet die Phase genau um Mitternacht, gibt es keinen '
        'leeren Abschnitt', () {
      final tag = DateTime(2026, 5, 4);
      final abschnitte = zerlegeNachTagen(SleepEntry(
        start: tag.add(const Duration(hours: 23)),
        ende: DateTime(tag.year, tag.month, tag.day + 1),
      ));

      expect(abschnitte, hasLength(1));
      expect(abschnitte.single.dauer, const Duration(hours: 1));
      expect(abschnitte.single.gehtWeiter, isFalse);
    });

    test('bei einer laufenden Nacht ist der gestrige Teil schon fest', () {
      final tag = DateTime(2026, 5, 4);
      final abschnitte = zerlegeNachTagen(
        SleepEntry(start: tag.add(const Duration(hours: 21))),
        jetzt: DateTime(tag.year, tag.month, tag.day + 1, 5, 30),
      );

      expect(abschnitte, hasLength(2));
      // Der abgeschlossene Vortag zählt mit …
      expect(abschnitte[0].offen, isFalse);
      expect(schlafSumme([abschnitte[0]]), const Duration(hours: 3));
      // … der laufende Tag nicht.
      expect(abschnitte[1].offen, isTrue);
      expect(schlafSumme([abschnitte[1]]), Duration.zero);
      expect(abschnitte[1].zeitLabel, 'seit 00:00 Uhr');
    });

    test('eine Phase über mehrere Tage ergibt einen Abschnitt je Tag', () {
      final tag = DateTime(2026, 5, 4, 20);
      final abschnitte = zerlegeNachTagen(SleepEntry(
        start: tag,
        ende: DateTime(2026, 5, 7, 8),
      ));

      expect(abschnitte, hasLength(4));
      expect(abschnitte[1].dauer, const Duration(hours: 24));
      expect(abschnitte[1].zeitLabel, '00:00 – 24:00 Uhr');
      expect(
        abschnitte.fold(Duration.zero, (s, a) => s + a.dauer),
        const Duration(hours: 60),
      );
    });
  });

  group('Gewicht', () {
    test('Differenz vergleicht die beiden jüngsten Messungen', () async {
      final now = DateTime.now();
      await state.saveWeight(WeightEntry(
        zeitpunkt: now.subtract(const Duration(days: 7)),
        gewichtKg: 12.4,
      ));
      await state.saveWeight(WeightEntry(zeitpunkt: now, gewichtKg: 13.0));

      await settle();

      expect(state.letztesGewicht!.gewichtKg, 13.0);
      expect(state.gewichtsDifferenz, closeTo(0.6, 0.0001));
    });

    test('Größe ist optional und bildet eine eigene Reihe', () async {
      final now = DateTime.now();

      await state.saveWeight(WeightEntry(
        zeitpunkt: now.subtract(const Duration(days: 30)),
        gewichtKg: 9.2,
        groesseCm: 38,
      ));
      // Zwischendurch nur gewogen, nicht gemessen.
      await state.saveWeight(WeightEntry(
        zeitpunkt: now.subtract(const Duration(days: 15)),
        gewichtKg: 12.0,
      ));
      await state.saveWeight(WeightEntry(
        zeitpunkt: now,
        gewichtKg: 15.4,
        groesseCm: 45.5,
      ));

      await settle();

      expect(state.weights, hasLength(3));
      // Die Größenreihe überspringt die Messung ohne Höhe, statt eine
      // Lücke in den Verlauf zu reißen.
      expect(state.groessenMessungen, hasLength(2));
      expect(state.letzteGroesse!.groesseCm, 45.5);
      expect(state.groessenDifferenz, closeTo(7.5, 0.0001));
      expect(state.gewichtsDifferenz, closeTo(3.4, 0.0001));
    });

    test('ohne Größenangaben gibt es keine Wachstumsdifferenz', () async {
      await state.saveWeight(
        WeightEntry(zeitpunkt: DateTime.now(), gewichtKg: 10),
      );
      await settle();

      expect(state.groessenMessungen, isEmpty);
      expect(state.letzteGroesse, isNull);
      expect(state.groessenDifferenz, isNull);
    });

    test('Fotoverlauf läuft vorwärts durch die Zeit', () async {
      final now = DateTime.now();
      final alt = WeightEntry(
        zeitpunkt: now.subtract(const Duration(days: 60)),
        gewichtKg: 8,
      );
      final neu = WeightEntry(zeitpunkt: now, gewichtKg: 16);

      await state.saveWeight(
        alt.copyWith(fotoRef: await state.storePhoto(alt.id, _bytes(1))),
      );
      await state.saveWeight(
        neu.copyWith(fotoRef: await state.storePhoto(neu.id, _bytes(2))),
      );
      // Eine Messung ohne Foto gehört nicht in den Verlauf.
      await state.saveWeight(WeightEntry(
        zeitpunkt: now.subtract(const Duration(days: 30)),
        gewichtKg: 12,
      ));

      await settle();

      final verlauf = state.fotoVerlauf;
      expect(verlauf, hasLength(2));
      expect(verlauf.first.zeitpunkt.isBefore(verlauf.last.zeitpunkt), isTrue);
    });

    test('Foto wird gespeichert, gelesen und mit dem Eintrag gelöscht',
        () async {
      final entry = WeightEntry(zeitpunkt: DateTime.now(), gewichtKg: 10);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final ref = await state.storePhoto(entry.id, bytes);
      await state.saveWeight(entry.copyWith(fotoRef: ref));

      await settle();

      expect(await state.loadPhoto(ref), bytes);

      await state.deleteWeight(state.weights.single);
      await settle();
      expect(state.weights, isEmpty);
      expect(await state.loadPhoto(ref), isNull);
    });
  });

  group('Heimtierausweis', () {
    test('überlebt Speichern und erneutes Laden', () async {
      final profil = const DogProfile().copyWith(
        name: 'Balu',
        rasse: 'Labrador',
        geschlecht: Geschlecht.ruede,
        kastriert: true,
        geburtsdatum: DateTime(2024, 3, 14),
        chipNummer: '276098106123456',
        tierarztTelefon: '0123 456789',
        zielgewichtKg: 30.5,
      );

      await state.saveProfile(profil);

      final frisch = AppState(LocalRepository());
      await frisch.init();
      // Der erste Stream-Wert kommt asynchron.
      await settle();

      expect(frisch.profile.name, 'Balu');
      expect(frisch.profile.geschlecht, Geschlecht.ruede);
      expect(frisch.profile.kastriert, isTrue);
      expect(frisch.profile.geburtsdatum, DateTime(2024, 3, 14));
      expect(frisch.profile.chipNummer, '276098106123456');
      expect(frisch.profile.zielgewichtKg, 30.5);
    });
  });

  group('Formatierung', () {
    test('Alter wird in Jahren, Monaten und Wochen ausgegeben', () {
      expect(
        formatAge(DateTime(2023, 1, 10), now: DateTime(2024, 4, 26)),
        '1 Jahr, 3 Monate, 2 Wochen',
      );
      // Ohne volle Woche steht nichts von Wochen da …
      expect(
        formatAge(DateTime(2023, 1, 10), now: DateTime(2024, 4, 12)),
        '1 Jahr, 3 Monate',
      );
      // … und ohne volles Jahr nichts von Jahren.
      expect(
        formatAge(DateTime(2024, 1, 10), now: DateTime(2024, 6, 27)),
        '5 Monate, 2 Wochen',
      );
      expect(
        formatAge(DateTime(2024, 1, 10), now: DateTime(2024, 1, 25)),
        '2 Wochen',
      );
      // In der ersten Woche zählen noch die Tage.
      expect(
        formatAge(DateTime(2024, 1, 10), now: DateTime(2024, 1, 14)),
        '4 Tage',
      );
      expect(
        formatAge(DateTime(2024, 1, 10), now: DateTime(2024, 1, 11)),
        '1 Tag',
      );
      // Kurzform für enge Stellen.
      expect(
        formatAge(DateTime(2023, 1, 10),
            now: DateTime(2024, 4, 26), kompakt: true),
        '1 Jahr, 3 Monate',
      );
    });

    test('Alter rechnet über Monatsenden hinweg richtig', () {
      // 31. Januar plus einen Monat ist der 29. Februar, nicht der
      // 2. März – sonst käme eine negative Tagesdifferenz heraus.
      expect(
        formatAge(DateTime(2024, 1, 31), now: DateTime(2024, 3, 1)),
        '1 Monat',
      );
      expect(
        formatAge(DateTime(2024, 1, 31), now: DateTime(2024, 2, 29)),
        '4 Wochen',
      );
      expect(
        formatAge(DateTime(2024, 6, 1), now: DateTime(2024, 5, 1)),
        'noch nicht geboren',
      );
    });

    test('Dauer wird kompakt geschrieben', () {
      expect(formatDuration(const Duration(minutes: 45)), '45 min');
      expect(formatDuration(const Duration(hours: 2)), '2 h');
      expect(formatDuration(const Duration(hours: 1, minutes: 20)), '1 h 20 min');
    });

    test('IDs sind eindeutig', () {
      final ids = List.generate(500, (_) => newId());
      expect(ids.toSet(), hasLength(500));
    });
  });
}

/// Kurze Platzhalter-Bilddaten für die Fototests.
Uint8List _bytes(int marker) => Uint8List.fromList([marker, 2, 3, 4]);
