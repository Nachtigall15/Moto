import 'dart:typed_data';

import 'package:dogapp/core/format.dart';
import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/models/dog_profile.dart';
import 'package:dogapp/models/feeding_entry.dart';
import 'package:dogapp/models/sleep_entry.dart';
import 'package:dogapp/models/weight_entry.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;

  /// Die Listen kommen über Streams – nach einer Änderung braucht die
  /// Zustellung eine Runde in der Event-Loop.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
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
    test('Alter wird in Jahren und Monaten ausgegeben', () {
      expect(
        formatAge(DateTime(2023, 1, 10), now: DateTime(2024, 4, 12)),
        '1 Jahr, 3 Monate',
      );
      expect(
        formatAge(DateTime(2024, 1, 10), now: DateTime(2024, 1, 20)),
        '10 Tage',
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
