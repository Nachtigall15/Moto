import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/dog_repository.dart';
import '../data/firebase_repository.dart';
import '../data/haushalt.dart';
import '../data/local_repository.dart';
import '../firebase_options.dart';
import 'app_state.dart';

enum Startphase {
  /// Verbindung wird aufgebaut, Konfiguration geprüft.
  laden,

  /// Cloud ist da, aber dieses Gerät gehört noch keinem Haushalt an.
  haushaltFehlt,

  /// Alles bereit – [BootstrapController.state] ist gesetzt.
  bereit,
}

/// Regelt den Start: Cloud oder lokal, Haushalt bekannt oder nicht.
///
/// Die App soll unter allen Umständen benutzbar sein. Fehlt die
/// Firebase-Konfiguration oder scheitert die Anmeldung, läuft sie
/// lokal weiter, statt mit einem Fehler stehen zu bleiben – ein
/// Hundetagebuch, das nicht aufgeht, ist schlimmer als eines, das
/// vorübergehend nur auf einem Gerät schreibt.
class BootstrapController extends ChangeNotifier {
  Startphase _phase = Startphase.laden;
  Startphase get phase => _phase;

  AppState? _state;
  AppState? get state => _state;

  /// Meldung, falls die Cloud nicht erreichbar war.
  String? _cloudFehler;
  String? get cloudFehler => _cloudFehler;

  bool _cloudMoeglich = false;

  /// Ob die App gerade im Cloud-Modus läuft.
  bool get cloud => _state?.isShared ?? false;

  Future<void> start() async {
    _cloudMoeglich = await _initFirebase();

    if (!_cloudMoeglich) {
      await _starteLokal();
      return;
    }

    final code = await Haushalt.lies();
    if (code == null) {
      _phase = Startphase.haushaltFehlt;
      notifyListeners();
      return;
    }
    await _starteCloud(code);
  }

  /// Haushalt setzen (erste Einrichtung auf einem Gerät).
  Future<void> setzeHaushalt(String eingabe) async {
    await Haushalt.speichere(eingabe);
    _phase = Startphase.laden;
    notifyListeners();
    await _starteCloud(Haushalt.normalisiere(eingabe));
  }

  /// Haushalt wechseln – etwa wenn sich jemand vertippt hat und
  /// deshalb allein in einem leeren Datenbestand sitzt.
  Future<void> wechsleHaushalt() async {
    await Haushalt.vergiss();
    _state = null;
    _phase = _cloudMoeglich ? Startphase.haushaltFehlt : Startphase.laden;
    notifyListeners();
    if (!_cloudMoeglich) await _starteLokal();
  }

  /// Ohne Cloud weitermachen – zum Ausprobieren oder wenn gerade kein
  /// Netz da ist.
  Future<void> nurLokal() async {
    _phase = Startphase.laden;
    notifyListeners();
    await _starteLokal();
  }

  Future<bool> _initFirebase() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options.apiKey.isEmpty || options.projectId.isEmpty) return false;

      await Firebase.initializeApp(options: options);
      // Anonyme Anmeldung: Die Zugriffsregeln verlangen eine
      // Anmeldung, aber niemand soll ein Konto anlegen müssen.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      return true;
    } catch (e) {
      _cloudFehler = '$e';
      return false;
    }
  }

  Future<void> _starteCloud(String code) async {
    try {
      final repo = FirebaseRepository(haushalt: code);
      _state = await _baue(repo);
    } catch (e) {
      _cloudFehler = '$e';
      await _starteLokal();
      return;
    }
    _phase = Startphase.bereit;
    notifyListeners();
  }

  Future<void> _starteLokal() async {
    _state = await _baue(LocalRepository());
    _phase = Startphase.bereit;
    notifyListeners();
  }

  Future<AppState> _baue(DogRepository repo) async {
    final state = AppState(repo);
    await state.init();
    return state;
  }
}
