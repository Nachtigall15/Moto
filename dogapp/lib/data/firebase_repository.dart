import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'dog_repository.dart';

/// Speichert alles in Firestore, Fotos in Firebase Storage.
///
/// Alle Daten eines Haushalts liegen unter `haushalte/<code>/…`. Wer
/// denselben Code eingibt, sieht denselben Stand – das ist die ganze
/// Zuordnung, absichtlich ohne Benutzerkonten.
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

  Reference _photoRef(String id) =>
      FirebaseStorage.instance.ref('haushalte/$haushalt/fotos/$id.jpg');

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
  Stream<List<Map<String, dynamic>>> watchCollection(String name) =>
      _col(name).snapshots().map(
            (snap) => snap.docs.map((d) => d.data()).toList(),
          );

  @override
  Future<void> upsert(String name, String id, Map<String, dynamic> data) =>
      _col(name).doc(id).set(data);

  @override
  Future<void> delete(String name, String id) => _col(name).doc(id).delete();

  // --- Fotos ---------------------------------------------------------

  @override
  Future<String> putPhoto(String id, Uint8List bytes) async {
    await _photoRef(id).putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return 'cloud:$id';
  }

  @override
  Future<Uint8List?> getPhoto(String ref) async {
    if (!ref.startsWith('cloud:')) return null;
    try {
      // Großzügig bemessen: Die App verkleinert Fotos vor dem
      // Speichern auf ~100 kB.
      return await _photoRef(ref.substring(6)).getData(8 * 1024 * 1024);
    } on FirebaseException {
      // Foto gelöscht oder (noch) nicht hochgeladen – die Oberfläche
      // zeigt dann den Platzhalter.
      return null;
    }
  }

  @override
  Future<void> deletePhoto(String ref) async {
    if (!ref.startsWith('cloud:')) return;
    try {
      await _photoRef(ref.substring(6)).delete();
    } on FirebaseException {
      // Schon weg – kein Grund, den Löschvorgang scheitern zu lassen.
    }
  }
}
