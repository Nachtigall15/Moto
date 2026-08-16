import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'dog_repository.dart';

/// Speichert alles auf dem Gerät (im Browser: localStorage).
///
/// Bewusst simpel gehalten: pro Sammlung ein JSON-Objekt, pro Foto ein
/// eigener Schlüssel. Das reicht für die Datenmengen einer Hunde-App
/// locker und macht Export/Import zu einem einzigen JSON-Dump.
class LocalRepository implements DogRepository {
  LocalRepository({this.namespace = 'hund'});

  final String namespace;

  late final SharedPreferences _prefs;

  final Map<String, StreamController<List<Map<String, dynamic>>>>
      _collectionControllers = {};
  final Map<String, StreamController<Map<String, dynamic>?>> _docControllers =
      {};

  @override
  bool get isShared => false;

  @override
  String get backendLabel => 'Nur auf diesem Gerät';

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String _collectionKey(String name) => '$namespace:c:$name';
  String _docKey(String id) => '$namespace:d:$id';
  String _photoKey(String id) => '$namespace:p:$id';

  // --- Einzeldokumente -----------------------------------------------

  Map<String, dynamic>? _readDoc(String id) {
    final raw = _prefs.getString(_docKey(id));
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Stream<Map<String, dynamic>?> watchDoc(String id) {
    final controller = _docControllers.putIfAbsent(
      id,
      () => StreamController<Map<String, dynamic>?>.broadcast(),
    );
    // Der aktuelle Stand muss auch dann ankommen, wenn sich nach dem
    // Abonnieren nichts mehr ändert.
    scheduleMicrotask(() => controller.add(_readDoc(id)));
    return controller.stream;
  }

  @override
  Future<void> setDoc(String id, Map<String, dynamic> data) async {
    await _prefs.setString(_docKey(id), jsonEncode(data));
    _docControllers[id]?.add(data);
  }

  // --- Sammlungen ----------------------------------------------------

  Map<String, dynamic> _readCollection(String name) {
    final raw = _prefs.getString(_collectionKey(name));
    if (raw == null || raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _entriesOf(String name) => _readCollection(name)
      .values
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  /// Merkt sich, wie eine Sammlung abonniert wurde, damit spätere
  /// Änderungen mit demselben Ausschnitt zugestellt werden.
  final Map<String, ({String? feld, int? limit})> _fenster = {};

  @override
  Stream<List<Map<String, dynamic>>> watchCollection(
    String name, {
    String? sortierFeld,
    int? limit,
  }) {
    _fenster[name] = (feld: sortierFeld, limit: limit);
    final controller = _collectionControllers.putIfAbsent(
      name,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );
    scheduleMicrotask(() => controller.add(_ausschnitt(name)));
    return controller.stream;
  }

  /// Dieselbe Begrenzung wie in der Cloud-Variante, nur lokal
  /// gerechnet: absteigend sortieren, dann abschneiden. Die Werte sind
  /// ISO-Zeitstempel als Text – die lassen sich direkt vergleichen.
  List<Map<String, dynamic>> _ausschnitt(String name) {
    final alle = _entriesOf(name);
    final fenster = _fenster[name];
    if (fenster == null) return alle;

    final feld = fenster.feld;
    if (feld != null) {
      alle.sort((a, b) {
        final av = a[feld]?.toString() ?? '';
        final bv = b[feld]?.toString() ?? '';
        return bv.compareTo(av);
      });
    }

    final limit = fenster.limit;
    if (limit != null && alle.length > limit) {
      return alle.sublist(0, limit);
    }
    return alle;
  }

  Future<void> _writeCollection(String name, Map<String, dynamic> data) async {
    await _prefs.setString(_collectionKey(name), jsonEncode(data));
    _collectionControllers[name]?.add(_ausschnitt(name));
  }

  @override
  Future<void> upsert(
    String name,
    String id,
    Map<String, dynamic> data,
  ) async {
    final all = _readCollection(name)..[id] = data;
    await _writeCollection(name, all);
  }

  @override
  Future<void> delete(String name, String id) async {
    final all = _readCollection(name)..remove(id);
    await _writeCollection(name, all);
  }

  @override
  Future<List<Map<String, dynamic>>> alleEintraege(String sammlung) async =>
      _entriesOf(sammlung);

  @override
  Future<Map<String, String>> alleFotos() async {
    final praefix = '$namespace:p:';
    return {
      for (final key in _prefs.getKeys())
        if (key.startsWith(praefix))
          'local:${key.substring(praefix.length)}': _prefs.getString(key) ?? '',
    };
  }

  // --- Fotos ---------------------------------------------------------

  @override
  Future<String> putPhoto(String id, Uint8List bytes) async {
    await _prefs.setString(_photoKey(id), base64Encode(bytes));
    return 'local:$id';
  }

  @override
  Future<Uint8List?> getPhoto(String ref) async {
    if (!ref.startsWith('local:')) return null;
    final raw = _prefs.getString(_photoKey(ref.substring(6)));
    if (raw == null) return null;
    return base64Decode(raw);
  }

  @override
  Future<void> deletePhoto(String ref) async {
    if (!ref.startsWith('local:')) return;
    await _prefs.remove(_photoKey(ref.substring(6)));
  }
}
