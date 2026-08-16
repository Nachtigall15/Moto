import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/core/format.dart';
import 'package:dogapp/models/appointment.dart';
import 'package:dogapp/models/medication.dart';
import 'package:dogapp/models/training.dart';
import 'package:dogapp/models/treat.dart';
import 'package:dogapp/models/vaccination.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(LocalRepository());
    await state.init();
  });

  group('Termine', () {
    test('trennt offen, verpasst und erledigt', () async {
      final jetzt = DateTime.now();

      await state.saveAppointment(Appointment(
        zeitpunkt: jetzt.add(const Duration(days: 2)),
        titel: 'Impftermin',
        kategorie: TerminArt.impfung,
      ));
      await state.saveAppointment(Appointment(
        zeitpunkt: jetzt.subtract(const Duration(days: 3)),
        titel: 'Vergessene Kontrolle',
      ));
      await state.saveAppointment(Appointment(
        zeitpunkt: jetzt.subtract(const Duration(days: 5)),
        titel: 'War beim Trimmen',
        erledigt: true,
      ));

      await settle();

      expect(state.verpassteTermine.single.titel, 'Vergessene Kontrolle');
      expect(state.erledigteTermine.single.titel, 'War beim Trimmen');
      expect(state.naechsterTermin!.titel, 'Impftermin');
    });

    test('nächster Termin überspringt erledigte', () async {
      final jetzt = DateTime.now();
      await state.saveAppointment(Appointment(
        zeitpunkt: jetzt.add(const Duration(hours: 2)),
        titel: 'Schon abgehakt',
        erledigt: true,
      ));
      await state.saveAppointment(Appointment(
        zeitpunkt: jetzt.add(const Duration(days: 1)),
        titel: 'Steht an',
      ));

      await settle();

      expect(state.naechsterTermin!.titel, 'Steht an');
    });
  });

  group('Medikamente', () {
    test('Gabe abhaken ist umkehrbar und nicht doppelbar', () async {
      final med = Medication(
        name: 'Wurmkur',
        zeiten: [8 * 60, 20 * 60],
      );
      await state.saveMedication(med);
      await settle();

      final heute = DateTime.now();
      expect(state.offeneGabenHeute(), 2);

      await state.toggleGabe(med.id, heute, 8 * 60);
      await settle();
      expect(state.istGegeben(med.id, heute, 8 * 60), isTrue);
      expect(state.offeneGabenHeute(), 1);

      // Zweimal abhaken darf keine zweite Gabe erzeugen.
      await state.toggleGabe(med.id, heute, 8 * 60);
      await settle();
      expect(state.istGegeben(med.id, heute, 8 * 60), isFalse);
      expect(state.offeneGabenHeute(), 2);
    });

    test('Gabe lässt sich für einen vergangenen Tag nachtragen', () async {
      final med = Medication(name: 'Metacam', zeiten: [12 * 60]);
      await state.saveMedication(med);
      await settle();

      final gestern = DateTime.now().subtract(const Duration(days: 1));
      await state.toggleGabe(med.id, gestern, 12 * 60);
      await settle();

      // Der Haken hängt am gewählten Tag, nicht an heute.
      expect(state.istGegeben(med.id, gestern, 12 * 60), isTrue);
      expect(state.istGegeben(med.id, DateTime.now(), 12 * 60), isFalse);
      expect(state.offeneGabenHeute(), 1);
    });

    test('Gabe außerhalb des Plans taucht im Tag auf', () async {
      final med = Medication(name: 'Wurmkur', zeiten: [8 * 60]);
      await state.saveMedication(med);
      await settle();

      final heute = DateTime.now();
      // 17:30 steht nicht im Plan – eine Extra-Gabe.
      await state.toggleGabe(med.id, heute, 17 * 60 + 30);
      await settle();

      final doses = state.dosesOn(heute);
      expect(doses.map((d) => d.minute), [8 * 60, 17 * 60 + 30]);
      expect(doses.first.gegeben, isFalse);
      expect(doses.first.nachgetragen, isFalse);
      expect(doses.last.gegeben, isTrue);
      expect(doses.last.nachgetragen, isTrue);
    });

    test('Gaben eines Tages sind nach Uhrzeit sortiert', () async {
      await state.saveMedication(
        Medication(name: 'Abends', zeiten: [20 * 60]),
      );
      await state.saveMedication(
        Medication(name: 'Morgens', zeiten: [7 * 60, 12 * 60]),
      );
      await settle();

      final doses = state.dosesOn(DateTime.now());
      expect(
        doses.map((d) => '${d.medikament.name}@${d.zeitLabel}'),
        ['Morgens@07:00', 'Morgens@12:00', 'Abends@20:00'],
      );
      // Der Zeitpunkt trägt den Tag mit, damit sich Gaben und Termine
      // im Kalender gemeinsam sortieren lassen.
      expect(doses.first.zeitpunkt.hour, 7);
      expect(isSameDay(doses.first.zeitpunkt, DateTime.now()), isTrue);
    });

    test('pausierte und abgelaufene Medikamente fallen aus dem Tagesplan',
        () async {
      final heute = DateTime.now();

      await state.saveMedication(
        Medication(name: 'Pausiert', zeiten: [8 * 60], aktiv: false),
      );
      await state.saveMedication(Medication(
        name: 'Abgelaufen',
        zeiten: [8 * 60],
        bis: heute.subtract(const Duration(days: 1)),
      ));
      await state.saveMedication(Medication(
        name: 'Läuft',
        zeiten: [8 * 60],
        von: heute.subtract(const Duration(days: 1)),
        bis: heute.add(const Duration(days: 3)),
      ));

      await settle();

      expect(
        state.medicationsOn(heute).map((m) => m.name),
        ['Läuft'],
      );
    });
  });

  group('Übersichten', () {
    test('Gabenverlauf steht chronologisch, neueste zuerst', () async {
      final med = Medication(name: 'Metacam', zeiten: [8 * 60, 20 * 60]);
      await state.saveMedication(med);
      await settle();

      final heute = DateTime.now();
      final gestern = heute.subtract(const Duration(days: 1));
      await state.toggleGabe(med.id, gestern, 20 * 60);
      await state.toggleGabe(med.id, heute, 8 * 60);
      await settle();

      final verlauf = state.gabenVerlauf;
      expect(verlauf, hasLength(2));
      expect(verlauf.first.zeitpunkt.isAfter(verlauf.last.zeitpunkt), isTrue);
      expect(state.gabenLetzteTage(), 2);
      // Vor acht Tagen war nichts – der Zeitraum grenzt wirklich ein.
      expect(state.gabenLetzteTage(tage: 1), 1);
    });

    test('Gaben zu gelöschten Medikamenten bleiben im Verlauf', () async {
      final med = Medication(name: 'Kurzzeitmittel', zeiten: [9 * 60]);
      await state.saveMedication(med);
      await settle();
      await state.toggleGabe(med.id, DateTime.now(), 9 * 60);
      await settle();

      await state.deleteMedication(med.id);
      await settle();

      // Die Gabe hat stattgefunden – sie darf nicht verschwinden,
      // nur weil das Mittel aus der Liste genommen wurde.
      expect(state.medications, isEmpty);
      expect(state.gabenVerlauf, hasLength(1));
      expect(state.gabenVerlauf.single.medikament.name,
          'Nicht mehr hinterlegt');
    });

    test('Impfungen werden nach Art gebündelt', () async {
      final heute = startOfDay(DateTime.now());

      await state.saveVaccination(Vaccination(
        bezeichnung: 'Tollwut',
        datum: heute.subtract(const Duration(days: 800)),
      ));
      await state.saveVaccination(Vaccination(
        bezeichnung: 'Tollwut',
        datum: heute.subtract(const Duration(days: 90)),
      ));
      await state.saveVaccination(Vaccination(
        bezeichnung: 'Leptospirose',
        datum: heute.subtract(const Duration(days: 10)),
      ));
      await settle();

      final gruppen = state.impfungenNachArt;
      expect(gruppen, hasLength(2));

      // Die Art mit der jüngsten Impfung steht oben – hier
      // Leptospirose vor 10 Tagen, Tollwut liegt 90 Tage zurück.
      expect(gruppen.first.$1, 'Leptospirose');

      final tollwut = gruppen.firstWhere((g) => g.$1 == 'Tollwut').$2;
      expect(tollwut, hasLength(2));
      // Innerhalb einer Art ebenfalls die jüngste zuerst.
      expect(tollwut.first.datum, heute.subtract(const Duration(days: 90)));
      expect(tollwut.last.datum, heute.subtract(const Duration(days: 800)));
    });
  });

  group('Impfungen', () {
    test('nur die jüngste Impfung je Bezeichnung zählt', () async {
      final heute = DateTime.now();

      await state.saveVaccination(Vaccination(
        bezeichnung: 'Tollwut',
        datum: DateTime(heute.year - 4, 1, 1),
        gueltigBis: DateTime(heute.year - 1, 1, 1),
      ));
      await state.saveVaccination(Vaccination(
        bezeichnung: 'Tollwut',
        datum: DateTime(heute.year - 1, 1, 1),
        gueltigBis: heute.add(const Duration(days: 400)),
      ));

      await settle();

      expect(state.vaccinations, hasLength(2));
      expect(state.aktuelleImpfungen, hasLength(1));
      expect(state.aktuelleImpfungen.single.istAbgelaufen, isFalse);
      expect(state.faelligeImpfungen, isEmpty);
    });

    test('überfällige und bald fällige Impfungen werden gemeldet', () async {
      final heute = DateTime.now();

      await state.saveVaccination(Vaccination(
        bezeichnung: 'Leptospirose',
        datum: heute.subtract(const Duration(days: 400)),
        gueltigBis: heute.subtract(const Duration(days: 35)),
      ));
      await state.saveVaccination(Vaccination(
        bezeichnung: 'Zwingerhusten',
        datum: heute.subtract(const Duration(days: 330)),
        gueltigBis: heute.add(const Duration(days: 30)),
      ));
      await state.saveVaccination(Vaccination(
        bezeichnung: 'Borreliose',
        datum: heute.subtract(const Duration(days: 10)),
        gueltigBis: heute.add(const Duration(days: 355)),
      ));

      await settle();

      final faellig = state.faelligeImpfungen.map((v) => v.bezeichnung);
      expect(faellig, containsAll(['Leptospirose', 'Zwingerhusten']));
      expect(faellig, isNot(contains('Borreliose')));
    });
  });

  group('Training', () {
    test('Startkatalog wird einmalig angelegt', () async {
      await state.seedExercises();
      await settle();

      expect(state.exercises, hasLength(standardUebungen.length));

      // Ein zweiter Aufruf darf nichts verdoppeln.
      await state.seedExercises();
      await settle();
      expect(state.exercises, hasLength(standardUebungen.length));
    });

    test('Übung abhaken zählt in den Tagesstatistiken', () async {
      final uebung = TrainingExercise(
        name: 'Sitz',
        stand: Trainingsstand.inArbeit,
      );
      await state.saveExercise(uebung);
      await settle();

      // Ohne Plan kommen die Übungen „in Arbeit" in die Tagesliste.
      expect(state.heutigeUebungen.single.name, 'Sitz');

      await state.toggleUebung(uebung.id, DateTime.now());
      await settle();

      expect(state.istGeuebt(uebung.id, DateTime.now()), isTrue);
      expect(state.geuebtHeute(), 1);
      expect(state.trainingstageZuletzt(), 1);
    });

    test('aktiver Plan bestimmt die Tagesliste', () async {
      final a = TrainingExercise(name: 'Bleib');
      final b = TrainingExercise(name: 'Aus');
      await state.saveExercise(a);
      await state.saveExercise(b);
      await state.savePlan(TrainingPlan(
        titel: 'Woche 1',
        uebungIds: [a.id],
      ));

      await settle();

      expect(state.heutigeUebungen.map((e) => e.name), ['Bleib']);
    });
  });

  group('Leckerli', () {
    test('Startliste enthält Erlaubtes und Verbotenes', () async {
      await state.seedTreats();
      await settle();

      expect(state.treats, hasLength(standardLeckerli.length));
      expect(
        state.treats.where((t) => t.erlaubt == Erlaubnis.nein),
        isNotEmpty,
      );
      // Sortierung: erlaubt zuerst, verboten zuletzt.
      expect(state.treats.first.erlaubt, Erlaubnis.ja);
      expect(state.treats.last.erlaubt, Erlaubnis.nein);
    });
  });
}
