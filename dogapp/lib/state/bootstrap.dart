import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../data/dog_repository.dart';
import '../data/firebase_repository.dart';
import '../data/local_repository.dart';
import '../firebase_options.dart';
import 'app_state.dart';

enum Startphase {
  /// Verbindung wird aufgebaut, Konfiguration geprüft.
  laden,

  /// Cloud ist da, aber niemand ist angemeldet.
  anmeldung,

  /// Alles bereit – [BootstrapController.state] ist gesetzt.
  bereit,
}

/// Regelt den Start: Cloud oder lokal, angemeldet oder nicht.
///
/// Die App soll unter allen Umständen benutzbar sein. Fehlt die
/// Firebase-Konfiguration oder ist der Dienst nicht erreichbar, läuft
/// sie lokal weiter, statt mit einem Fehler stehen zu bleiben – ein
/// Hundetagebuch, das nicht aufgeht, ist schlimmer als eines, das
/// vorübergehend nur auf einem Gerät schreibt.
class BootstrapController extends ChangeNotifier {
  Startphase _phase = Startphase.laden;
  Startphase get phase => _phase;

  AppState? _state;
  AppState? get state => _state;

  String? _fehler;
  String? get fehler => _fehler;

  String? _hinweis;
  String? get hinweis => _hinweis;

  bool _busy = false;
  bool get busy => _busy;

  /// E-Mail der angemeldeten Person, für die Anzeige.
  String? _angemeldetAls;
  String? get angemeldetAls => _angemeldetAls;

  bool get cloud => _state?.isShared ?? false;

  StreamSubscription<User?>? _authSub;

  /// Für welchen Benutzer der Zustand gebaut wurde – verhindert, dass
  /// dieselbe Anmeldung die App mehrfach neu aufbaut.
  String? _aktuelleUid;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    if (!await _initFirebase()) {
      await _starteLokal();
      return;
    }

    // Firebase merkt sich die Anmeldung über Neustarts hinweg. Der
    // Stream liefert deshalb gleich beim Abonnieren den bekannten
    // Benutzer – oder null, wenn noch niemand angemeldet ist.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_aufBenutzer);
  }

  Future<void> _aufBenutzer(User? user) async {
    if (user == null) {
      _aktuelleUid = null;
      _angemeldetAls = null;
      _state = null;
      _phase = Startphase.anmeldung;
      notifyListeners();
      return;
    }

    if (user.uid == _aktuelleUid) return;
    _aktuelleUid = user.uid;
    _angemeldetAls = user.email;
    await _starteCloud();
  }

  Future<void> anmelden(String email, String passwort) async {
    _busy = true;
    _fehler = null;
    _hinweis = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: passwort,
      );
      // Der authStateChanges-Stream übernimmt ab hier.
    } on FirebaseAuthException catch (e) {
      _fehler = _lesbar(e);
    } catch (e) {
      _fehler = 'Anmeldung nicht möglich: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> passwortZuruecksetzen(String email) async {
    _busy = true;
    _fehler = null;
    _hinweis = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _hinweis = 'Wir haben eine E-Mail an $email geschickt. Darin steht '
          'ein Link, über den sich ein neues Passwort setzen lässt. '
          'Schau notfalls im Spam-Ordner nach.';
    } on FirebaseAuthException catch (e) {
      _fehler = _lesbar(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> abmelden() async {
    await FirebaseAuth.instance.signOut();
  }

  /// Firebase-Fehlercodes in Sätze übersetzen, mit denen jemand etwas
  /// anfangen kann.
  static String _lesbar(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'Diese E-Mail-Adresse sieht nicht richtig aus.',
        'user-disabled' => 'Dieser Zugang wurde deaktiviert.',
        'user-not-found' || 'invalid-credential' || 'wrong-password' =>
          'E-Mail oder Passwort stimmt nicht.',
        'too-many-requests' =>
          'Zu viele Versuche. Warte einen Moment und probier es dann '
              'noch einmal.',
        'network-request-failed' =>
          'Keine Verbindung. Prüf die Internetverbindung und versuch es '
              'erneut.',
        _ => 'Anmeldung fehlgeschlagen (${e.code}).',
      };

  Future<bool> _initFirebase() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options.apiKey.isEmpty || options.projectId.isEmpty) return false;

      await Firebase.initializeApp(options: options);
      return true;
    } catch (e) {
      _fehler = '$e';
      return false;
    }
  }

  Future<void> _starteCloud() async {
    _phase = Startphase.laden;
    notifyListeners();

    try {
      final repo = FirebaseRepository(haushalt: AppConfig.haushalt);
      _state = await _baue(repo);
    } catch (e) {
      _fehler = '$e';
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
