import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/dog_repository.dart';
import '../models/dog_profile.dart';
import '../models/feeding_entry.dart';
import '../models/sleep_entry.dart';
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

  /// Jeweils neueste zuerst – so werden die Listen überall angezeigt.
  List<FeedingEntry> get feedings => _feedings;
  List<SleepEntry> get sleeps => _sleeps;
  List<WeightEntry> get weights => _weights;

  Future<void> init() async {
    await _repo.init();

    _subs.add(_repo.watchDoc(_dProfile).listen((data) {
      _profile = data == null ? const DogProfile() : DogProfile.fromJson(data);
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cFeedings).listen((rows) {
      _feedings = rows.map(FeedingEntry.fromJson).toList()
        ..sort((a, b) => b.zeitpunkt.compareTo(a.zeitpunkt));
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cSleeps).listen((rows) {
      _sleeps = rows.map(SleepEntry.fromJson).toList()
        ..sort((a, b) => b.start.compareTo(a.start));
      notifyListeners();
    }));

    _subs.add(_repo.watchCollection(_cWeights).listen((rows) {
      _weights = rows.map(WeightEntry.fromJson).toList()
        ..sort((a, b) => b.zeitpunkt.compareTo(a.zeitpunkt));
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

  WeightEntry? get letztesGewicht =>
      _weights.isEmpty ? null : _weights.first;

  /// Veränderung zum vorletzten Wiegen – positiv heißt zugenommen.
  double? get gewichtsDifferenz {
    if (_weights.length < 2) return null;
    return _weights[0].gewichtKg - _weights[1].gewichtKg;
  }
}
