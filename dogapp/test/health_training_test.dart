import 'package:dogapp/data/local_repository.dart';
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
