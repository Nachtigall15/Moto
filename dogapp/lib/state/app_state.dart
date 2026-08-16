import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/format.dart';
import '../data/dog_repository.dart';
import '../models/appointment.dart';
import '../models/dog_profile.dart';
import '../models/feeding_entry.dart';
import '../models/medication.dart';
import '../models/sleep_entry.dart';
import '../models/training.dart';
import '../models/treat.dart';
import '../models/vaccination.dart';
import '../models/weight_entry.dart';

/// Hält den kompletten Anwendungszustand und ist die einzige Stelle,
/// die mit dem Repository spricht.
///
/// Alle Listen kommen aus Streams. Beim lokalen Speicher ist das nur
/// bequem – mit der Cloud-Anbindung ist es der Grund, warum Änderungen
/// eines anderen Geräts ohne Zutun in der Oberfläche auftauchen.
class AppState extends ChangeNotifier {
  AppState(this._repo);

  final DogRepository _repo;

  static const _cFeedings = 'fuetterungen';
  static const _cSleeps = 'schlaf';
  static const _cWeights = 'gewicht';
  static const _cAppointments = 'termine';
  static const _cMedications = 'medikamente';
  static const _cMedLogs = 'medikamentengaben';
  static const _cVaccinations = 'impfungen';
  static const _cExercises = 'uebungen';
  static const _cTrainingLogs = 'trainingseinheiten';
  static const _cPlans = 'trainingsplaene';
  static const _cTreats = 'leckerli';
  static const _dProfile = 'profil';

  final List<StreamSubscription<dynamic>> _subs = [];

  bool _ready = false;
  bool get ready => _ready;

  bool get isShared => _repo.isShared;
  String get backendLabel => _repo.backendLabel;

  DogProfile _profile = const DogProfile();
  DogProfile get profile => _profile;

  List<FeedingEntry> _feedings = const [];
  List<SleepEntry> _sleeps = const [];
  List<WeightEntry> _weights = const [];
  List<Appointment> _appointments = const [];
  List<Medication> _medications = const [];
  List<Vaccination> _vaccinations = const [];
  Map<String, MedicationLog> _medLogs = const {};

  /// Jeweils neueste zuerst – so werden die Listen überall angezeigt.
  List<FeedingEntry> get feedings => _feedings;
  List<SleepEntry> get sleeps => _sleeps;
  List<WeightEntry> get weights => _weights;

  /// Termine dagegen chronologisch aufsteigend – ein Kalender liest
  /// sich vorwärts.
  List<Appointment> get appointments => _appointments;
  List<Medication> get medications => _medications;
  List<Vaccination> get vaccinations => _vaccinations;

  List<TrainingExercise> _exercises = const [];
  List<TrainingPlan> _plans = const [];
  List<Treat> _treats = const [];
  Map<String, TrainingLog> _trainingLogs = const {};

  List<TrainingExercise> get exercises => _exercises;
  List<TrainingPlan> get plans => _plans;
  List<Treat> get treats => _treats;

  Future<void> init() async {
    await _repo.init();

    _subs.add(_repo.watchDoc(_dProfile).listen((data) {
      _profile = data == null ? const DogProfile() : DogProfile.fromJson(data);
      notifyListeners();
    }));

    _subs.add(_repo
        .watchCollection(_cFeedings,
            sortierFeld: 'zeitpunkt', limit: AppConfig.limitFuetterungen)
        .listen((rows) {
      _feedings = rows.map(FeedingEntry.fromJson).toList()
        ..sort((a, b) => b.zeitpunkt.compareTo(a.zeitpunkt));
      notifyListeners();
    }));

    _subs.add(_repo
        .watchCollection(_cSleeps,
            sortierFeld: 'start', limit: AppConfig.limitSchlaf)
        .listen((rows) {
      _sleeps = rows.map(SleepEntry.fromJson).toList()
        ..sort((a, b) => b.start.compareTo(a.start));
      notifyListeners();
    }));

    _subs.add(_repo
        .watchCollection(_cWeights,
            sortierFeld: 'zeitpunkt', limit: AppConfig.limitGewicht)
        .listen((rows) {
      _weights = rows.map(WeightEntry.fromJson).toList()
        ..sort((a, b) => b.zeitpunkt.compareTo(a.zeitpunkt));
      notifyListeners();
    }));

    _subs.add(_repo
        .watchCollection(_cAppointments,
            sortierFeld: 'zeitpunkt', limit: AppConfig.limitTermine)
        .listen((rows) {
      _appointments = rows.map(Appointment.fromJson).toList()
        ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cMedications).listen((rows) {
      _medications = rows.map(Medication.fromJson).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
    }));

    _subs.add(_repo
        .watchCollection(_cMedLogs,
            sortierFeld: 'tag', limit: AppConfig.limitGaben)
        .listen((rows) {
      _medLogs = {
        for (final row in rows.map(MedicationLog.fromJson)) row.id: row,
      };
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cVaccinations).listen((rows) {
      _vaccinations = rows.map(Vaccination.fromJson).toList()
        ..sort((a, b) => b.datum.compareTo(a.datum));
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cExercises).listen((rows) {
      _exercises = rows.map(TrainingExercise.fromJson).toList()
        ..sort((a, b) {
          final g = a.gruppe.index.compareTo(b.gruppe.index);
          if (g != 0) return g;
          return a.reihenfolge.compareTo(b.reihenfolge);
        });
      notifyListeners();
    }));

    _subs.add(_repo
        .watchCollection(_cTrainingLogs,
            sortierFeld: 'tag', limit: AppConfig.limitTraining)
        .listen((rows) {
      _trainingLogs = {
        for (final row in rows.map(TrainingLog.fromJson)) row.id: row,
      };
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cPlans).listen((rows) {
      _plans = rows.map(TrainingPlan.fromJson).toList()
        ..sort(
            (a, b) => a.titel.toLowerCase().compareTo(b.titel.toLowerCase()));
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cTreats).listen((rows) {
      _treats = rows.map(Treat.fromJson).toList()
        ..sort((a, b) {
          final e = a.erlaubt.index.compareTo(b.erlaubt.index);
          if (e != 0) return e;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      notifyListeners();
    }));

    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  // --- Profil ---------------------------------------------------------

  Future<void> saveProfile(DogProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _repo.setDoc(_dProfile, profile.toJson());
  }

  // --- Fütterung ------------------------------------------------------

  Future<void> saveFeeding(FeedingEntry entry) =>
      _repo.upsert(_cFeedings, entry.id, entry.toJson());

  Future<void> deleteFeeding(String id) => _repo.delete(_cFeedings, id);

  List<FeedingEntry> feedingsOn(DateTime day) => _feedings
      .where((f) =>
          f.zeitpunkt.year == day.year &&
          f.zeitpunkt.month == day.month &&
          f.zeitpunkt.day == day.day)
      .toList();

  /// Futtermengen des Tages, getrennt nach Einheit – Gramm und Stück
  /// darf man nicht zusammenzählen.
  Map<Einheit, double> totalsOn(DateTime day) {
    final result = <Einheit, double>{};
    for (final f in feedingsOn(day)) {
      result[f.einheit] = (result[f.einheit] ?? 0) + f.menge;
    }
    return result;
  }

  /// Ob die Liste den kompletten Bestand zeigt oder am Fensterrand
  /// steht. Die Oberfläche sagt das dann dazu – sonst sucht jemand
  /// irgendwann vergeblich nach der Fütterung vom letzten Frühjahr und
  /// hält sie für verloren.
  bool get fuetterungenVollstaendig =>
      _feedings.length < AppConfig.limitFuetterungen;

  bool get schlafVollstaendig => _sleeps.length < AppConfig.limitSchlaf;

  /// Bereits verwendete Futtersorten als Vorschläge beim Eintragen.
  List<String> get bekannteFuttersorten {
    final seen = <String>{};
    for (final f in _feedings) {
      final name = f.futter.trim();
      if (name.isNotEmpty) seen.add(name);
    }
    final list = seen.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  // --- Schlaf ---------------------------------------------------------

  Future<void> saveSleep(SleepEntry entry) =>
      _repo.upsert(_cSleeps, entry.id, entry.toJson());

  Future<void> deleteSleep(String id) => _repo.delete(_cSleeps, id);

  SleepEntry? get laufenderSchlaf {
    for (final s in _sleeps) {
      if (s.laeuft) return s;
    }
    return null;
  }

  Future<void> startSleep() async {
    if (laufenderSchlaf != null) return;
    await saveSleep(SleepEntry(start: DateTime.now()));
  }

  Future<void> stopSleep() async {
    final running = laufenderSchlaf;
    if (running == null) return;
    await saveSleep(running.copyWith(ende: DateTime.now()));
  }

  List<SleepEntry> sleepsOn(DateTime day) => _sleeps
      .where((s) =>
          s.start.year == day.year &&
          s.start.month == day.month &&
          s.start.day == day.day)
      .toList();

  Duration sleepTotalOn(DateTime day) => sleepsOn(day)
      .where((s) => !s.laeuft)
      .fold(Duration.zero, (sum, s) => sum + s.dauer);

  // --- Gewicht & Fotos ------------------------------------------------

  Future<void> saveWeight(WeightEntry entry) =>
      _repo.upsert(_cWeights, entry.id, entry.toJson());

  Future<void> deleteWeight(WeightEntry entry) async {
    if (entry.hatFoto) await _repo.deletePhoto(entry.fotoRef!);
    await _repo.delete(_cWeights, entry.id);
  }

  Future<String> storePhoto(String id, Uint8List bytes) =>
      _repo.putPhoto(id, bytes);

  Future<Uint8List?> loadPhoto(String ref) => _repo.getPhoto(ref);

  Future<void> removePhoto(String ref) => _repo.deletePhoto(ref);

  WeightEntry? get letztesGewicht => _weights.isEmpty ? null : _weights.first;

  /// Veränderung zum vorletzten Wiegen – positiv heißt zugenommen.
  double? get gewichtsDifferenz {
    if (_weights.length < 2) return null;
    return _weights[0].gewichtKg - _weights[1].gewichtKg;
  }

  /// Messungen mit Größe – die Höhe wird seltener genommen als das
  /// Gewicht, deshalb eine eigene Reihe statt Lücken im Verlauf.
  List<WeightEntry> get groessenMessungen =>
      _weights.where((w) => w.hatGroesse).toList();

  WeightEntry? get letzteGroesse {
    final mit = groessenMessungen;
    return mit.isEmpty ? null : mit.first;
  }

  /// Wachstum seit der vorletzten Messung, in Zentimetern.
  double? get groessenDifferenz {
    final mit = groessenMessungen;
    if (mit.length < 2) return null;
    return mit[0].groesseCm! - mit[1].groesseCm!;
  }

  /// Alle Fotos in zeitlicher Reihenfolge – der eigentliche
  /// Entwicklungsverlauf zum Durchblättern.
  List<WeightEntry> get fotoVerlauf {
    final mit = _weights.where((w) => w.hatFoto).toList()
      ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
    return mit;
  }

  // --- Termine --------------------------------------------------------

  Future<void> saveAppointment(Appointment entry) =>
      _repo.upsert(_cAppointments, entry.id, entry.toJson());

  Future<void> deleteAppointment(String id) => _repo.delete(_cAppointments, id);

  /// Was noch aussteht: alles ab heute plus alles, was in der
  /// Vergangenheit liegt, aber niemand abgehakt hat.
  List<Appointment> get offeneTermine {
    final grenze = startOfDay(DateTime.now());
    return _appointments
        .where((a) => !a.erledigt && !a.zeitpunkt.isBefore(grenze))
        .toList();
  }

  List<Appointment> get verpassteTermine {
    final jetzt = DateTime.now();
    return _appointments
        .where((a) => !a.erledigt && a.zeitpunkt.isBefore(jetzt))
        .toList()
        .reversed
        .toList();
  }

  List<Appointment> get erledigteTermine =>
      _appointments.where((a) => a.erledigt).toList().reversed.toList();

  Appointment? get naechsterTermin {
    final jetzt = DateTime.now();
    for (final a in _appointments) {
      if (!a.erledigt && a.zeitpunkt.isAfter(jetzt)) return a;
    }
    return null;
  }

  List<Appointment> appointmentsOn(DateTime day) =>
      _appointments.where((a) => isSameDay(a.zeitpunkt, day)).toList();

  // --- Medikamente ----------------------------------------------------

  Future<void> saveMedication(Medication entry) =>
      _repo.upsert(_cMedications, entry.id, entry.toJson());

  Future<void> deleteMedication(String id) => _repo.delete(_cMedications, id);

  List<Medication> medicationsOn(DateTime day) =>
      _medications.where((m) => m.giltAm(day)).toList();

  bool istGegeben(String medikamentId, DateTime tag, int minute) =>
      _medLogs.containsKey(
        MedicationLog.buildId(medikamentId, tag, minute),
      );

  MedicationLog? gabe(String medikamentId, DateTime tag, int minute) =>
      _medLogs[MedicationLog.buildId(medikamentId, tag, minute)];

  /// Haken setzen oder zurücknehmen. Die feste ID sorgt dafür, dass
  /// zwei Personen dieselbe Gabe nicht doppelt eintragen können.
  Future<void> toggleGabe(
    String medikamentId,
    DateTime tag,
    int minute, {
    String wer = '',
  }) async {
    final id = MedicationLog.buildId(medikamentId, tag, minute);
    if (_medLogs.containsKey(id)) {
      await _repo.delete(_cMedLogs, id);
      return;
    }
    final log = MedicationLog(
      medikamentId: medikamentId,
      tag: tag,
      minute: minute,
      gegebenUm: DateTime.now(),
      wer: wer,
    );
    await _repo.upsert(_cMedLogs, id, log.toJson());
  }

  /// Alle Gaben eines Tages, nach Uhrzeit sortiert.
  ///
  /// Enthält die geplanten Zeiten und zusätzlich alles, was jemand
  /// außerhalb des Plans nachgetragen hat – eine Extra-Gabe darf nicht
  /// unsichtbar bleiben, nur weil sie nicht im Schema steht. Aus dem
  /// gleichen Grund kommen auch pausierte Medikamente in die Liste,
  /// sofern für den Tag eine Gabe eingetragen ist.
  List<MedicationDose> dosesOn(DateTime tag) {
    final logsAmTag =
        _medLogs.values.where((log) => isSameDay(log.tag, tag)).toList();

    final kandidaten = <String, Medication>{
      for (final m in medicationsOn(tag)) m.id: m,
    };
    for (final log in logsAmTag) {
      if (kandidaten.containsKey(log.medikamentId)) continue;
      for (final m in _medications) {
        if (m.id == log.medikamentId) kandidaten[m.id] = m;
      }
    }

    final doses = <MedicationDose>[];
    for (final m in kandidaten.values) {
      final eigeneLogs = {
        for (final log in logsAmTag)
          if (log.medikamentId == m.id) log.minute: log,
      };
      final minuten = <int>{...m.zeiten, ...eigeneLogs.keys};
      for (final minute in minuten) {
        doses.add(MedicationDose(
          medikament: m,
          minute: minute,
          tag: startOfDay(tag),
          log: eigeneLogs[minute],
        ));
      }
    }

    doses.sort((a, b) {
      final t = a.minute.compareTo(b.minute);
      if (t != 0) return t;
      return a.medikament.name
          .toLowerCase()
          .compareTo(b.medikament.name.toLowerCase());
    });
    return doses;
  }

  /// Wie viele Gaben stehen heute noch aus?
  int offeneGabenHeute() =>
      dosesOn(DateTime.now()).where((d) => !d.gegeben).length;

  // --- Impfungen ------------------------------------------------------

  Future<void> saveVaccination(Vaccination entry) =>
      _repo.upsert(_cVaccinations, entry.id, entry.toJson());

  Future<void> deleteVaccination(String id) => _repo.delete(_cVaccinations, id);

  /// Nur die jeweils jüngste Impfung pro Bezeichnung bestimmt den
  /// Status – eine drei Jahre alte Tollwutimpfung ist irrelevant,
  /// wenn letztes Jahr nachgeimpft wurde.
  List<Vaccination> get aktuelleImpfungen {
    final neueste = <String, Vaccination>{};
    for (final v in _vaccinations) {
      final bisher = neueste[v.bezeichnung];
      if (bisher == null || v.datum.isAfter(bisher.datum)) {
        neueste[v.bezeichnung] = v;
      }
    }
    final list = neueste.values.toList()
      ..sort((a, b) {
        final at = a.tageBisFaellig;
        final bt = b.tageBisFaellig;
        if (at == null && bt == null) return b.datum.compareTo(a.datum);
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });
    return list;
  }

  List<Vaccination> get faelligeImpfungen => aktuelleImpfungen
      .where((v) => v.istAbgelaufen || v.wirdBaldFaellig)
      .toList();

  // --- Training -------------------------------------------------------

  Future<void> saveExercise(TrainingExercise entry) =>
      _repo.upsert(_cExercises, entry.id, entry.toJson());

  Future<void> deleteExercise(String id) => _repo.delete(_cExercises, id);

  /// Legt den Startkatalog an. Bewusst nur auf Knopfdruck – eine App
  /// soll nicht ungefragt Daten erzeugen, die hinterher jemand
  /// einzeln wieder löscht.
  Future<void> seedExercises() async {
    if (_exercises.isNotEmpty) return;
    for (var i = 0; i < standardUebungen.length; i++) {
      final (name, gruppe, hinweis) = standardUebungen[i];
      final uebung = TrainingExercise(
        name: name,
        gruppe: gruppe,
        beschreibung: hinweis,
        reihenfolge: i,
      );
      await _repo.upsert(_cExercises, uebung.id, uebung.toJson());
    }
  }

  List<TrainingExercise> exercisesInGruppe(TrainingGruppe gruppe) =>
      _exercises.where((e) => e.gruppe == gruppe).toList();

  TrainingExercise? exerciseById(String id) {
    for (final e in _exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  bool istGeuebt(String uebungId, DateTime tag) =>
      _trainingLogs.containsKey(TrainingLog.buildId(uebungId, tag));

  Future<void> toggleUebung(
    String uebungId,
    DateTime tag, {
    String wer = '',
  }) async {
    final id = TrainingLog.buildId(uebungId, tag);
    if (_trainingLogs.containsKey(id)) {
      await _repo.delete(_cTrainingLogs, id);
      return;
    }
    final log = TrainingLog(
      uebungId: uebungId,
      tag: tag,
      erledigtUm: DateTime.now(),
      wer: wer,
    );
    await _repo.upsert(_cTrainingLogs, id, log.toJson());
  }

  /// An wie vielen der letzten [tage] Tage wurde überhaupt geübt?
  int trainingstageZuletzt({int tage = 7}) {
    final heute = startOfDay(DateTime.now());
    final tageMitTraining = <DateTime>{};
    for (final log in _trainingLogs.values) {
      final tag = startOfDay(log.tag);
      final abstand = heute.difference(tag).inDays;
      if (abstand >= 0 && abstand < tage) tageMitTraining.add(tag);
    }
    return tageMitTraining.length;
  }

  int geuebtHeute() {
    final heute = DateTime.now();
    return _exercises.where((e) => istGeuebt(e.id, heute)).length;
  }

  Future<void> savePlan(TrainingPlan plan) =>
      _repo.upsert(_cPlans, plan.id, plan.toJson());

  Future<void> deletePlan(String id) => _repo.delete(_cPlans, id);

  List<TrainingPlan> get aktivePlaene => _plans.where((p) => p.aktiv).toList();

  /// Die Übungen, die heute anstehen: alles aus den aktiven Plänen.
  /// Gibt es keinen Plan, sind es die Übungen, die gerade in Arbeit
  /// sind – so ist der Reiter nie leer, wenn schon etwas läuft.
  List<TrainingExercise> get heutigeUebungen {
    final ausPlaenen = <String>{
      for (final p in aktivePlaene) ...p.uebungIds,
    };
    if (ausPlaenen.isNotEmpty) {
      return _exercises.where((e) => ausPlaenen.contains(e.id)).toList();
    }
    return _exercises.where((e) => e.stand == Trainingsstand.inArbeit).toList();
  }

  // --- Leckerli -------------------------------------------------------

  Future<void> saveTreat(Treat entry) =>
      _repo.upsert(_cTreats, entry.id, entry.toJson());

  Future<void> deleteTreat(String id) => _repo.delete(_cTreats, id);

  Future<void> seedTreats() async {
    if (_treats.isNotEmpty) return;
    for (final (name, erlaubt, hinweis) in standardLeckerli) {
      final treat = Treat(
        name: name,
        erlaubt: erlaubt,
        beliebtheit: erlaubt == Erlaubnis.nein ? 0 : 2,
        notiz: hinweis,
      );
      await _repo.upsert(_cTreats, treat.id, treat.toJson());
    }
  }
}
