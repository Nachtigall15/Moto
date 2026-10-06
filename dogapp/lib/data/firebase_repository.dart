import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'dog_repository.dart';

/// Speichert alles in Firestore – auch die Fotos.
///
/// Alle Daten eines Haushalts liegen unter `haushalte/<code>/…`. Wer
/// denselben Code eingibt, sieht denselben Stand – das ist die ganze
/// Zuordnung, absichtlich ohne Benutzerkonten.
///
/// Fotos liegen als Daten in einer eigenen Sammlung statt in Cloud
/// Storage. Storage verlangt bei neuen Projekten den kostenpflichtigen
/// Tarif; für Bilder von rund 100 kB ist die Datenbank völlig
/// ausreichend, und die App bleibt damit im kostenlosen Kontingent.
/// Weil die Sammlung nicht abonniert wird, belasten die Fotos auch
/// keine der laufenden Abfragen.
///
/// Die Lesezugriffe sind Snapshot-Streams: Trägt jemand auf einem
/// anderen Gerät eine Fütterung ein, schiebt der Server die Änderung
/// von selbst nach, ohne dass die Oberfläche etwas anders macht als
/// beim lokalen Speicher.
class FirebaseRepository implements DogRepository {
  FirebaseRepository({required this.haushalt});

  /// Kennung des Haushalts, unter der alle Daten liegen.
  final String haushalt;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _wurzel =>
      _db.collection('haushalte').doc(haushalt);

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _wurzel.collection('dokumente').doc(id);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _wurzel.collection(name);

  DocumentReference<Map<String, dynamic>> _foto(String id) =>
      _wurzel.collection('fotos').doc(id);

  @override
  bool get isShared => true;

  @override
  String get backendLabel => 'Geteilt · Haushalt „$haushalt"';

  @override
  Future<void> init() async {
    // Offline-Zwischenspeicher: Einträge lassen sich auch ohne Netz
    // machen – beim Spaziergang ohne Empfang der Normalfall – und
    // gehen raus, sobald wieder Verbindung besteht.
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {
      // In manchen Browsern (privates Fenster, mehrere Tabs) lässt
      // sich der Zwischenspeicher nicht einschalten. Die App
      // funktioniert dann online weiter.
    }
  }

  // --- Einzeldokumente -----------------------------------------------

  @override
  Stream<Map<String, dynamic>?> watchDoc(String id) =>
      _doc(id).snapshots().map((snap) => snap.data());

  @override
  Future<void> setDoc(String id, Map<String, dynamic> data) =>
      _doc(id).set(data);

  // --- Sammlungen ----------------------------------------------------

  @override
  Stream<List<Map<String, dynamic>>> watchCollection(
    String name, {
    String? sortierFeld,
    int? limit,
  }) {
    Query<Map<String, dynamic>> abfrage = _col(name);
    // Absteigend: Das Jüngste ist das, was im Alltag zählt.
    if (sortierFeld != null) {
      abfrage = abfrage.orderBy(sortierFeld, descending: true);
    }
    if (limit != null) abfrage = abfrage.limit(limit);

    return abfrage.snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList(),
        );
  }

  @override
  Future<void> upsert(String name, String id, Map<String, dynamic> data) =>
      _col(name).doc(id).set(data);

  @override
  Future<void> delete(String name, String id) => _col(name).doc(id).delete();

  @override
  Future<List<Map<String, dynamic>>> alleEintraege(String sammlung) async {
    final snap = await _col(sammlung).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  @override
  Future<Map<String, String>> alleFotos() async {
    final snap = await _wurzel.collection('fotos').get();
    return {
      for (final doc in snap.docs)
        'cloud:${doc.id}': doc.data()['daten'] as String? ?? '',
    };
  }

  // --- Fotos ---------------------------------------------------------

  @override
  Future<String> putPhoto(String id, Uint8List bytes) async {
    await _foto(id).set({
      'daten': base64Encode(bytes),
      'gespeichert': DateTime.now().toIso8601String(),
    });
    return 'cloud:$id';
  }

  @override
  Future<Uint8List?> getPhoto(String ref) async {
    if (!ref.startsWith('cloud:')) return null;
    try {
      final snap = await _foto(ref.substring(6)).get();
      final daten = snap.data()?['daten'] as String?;
      if (daten == null || daten.isEmpty) return null;
      return base64Decode(daten);
    } on FirebaseException {
      // Foto gelöscht oder noch nicht angekommen – die Oberfläche
      // zeigt dann den Platzhalter.
      return null;
    }
  }

  @override
  Future<void> deletePhoto(String ref) async {
    if (!ref.startsWith('cloud:')) return;
    try {
      await _foto(ref.substring(6)).delete();
    } on FirebaseException {
      // Schon weg – kein Grund, den Löschvorgang scheitern zu lassen.
    }
  }
}
