import '../core/format.dart';

/// Ein Medikament mit festen Gabezeiten.
///
/// [zeiten] sind Minuten seit Mitternacht – das lässt sich sortieren,
/// speichern und vergleichen, ohne von der Zeitzone abzuhängen.
class Medication {
  Medication({
    String? id,
    required this.name,
    this.dosis = '',
    List<int>? zeiten,
    this.von,
    this.bis,
    this.notiz = '',
    this.aktiv = true,
  })  : id = id ?? newId(),
        zeiten = zeiten == null ? const [] : (List<int>.from(zeiten)..sort());

  final String id;
  final String name;
  final String dosis;
  final List<int> zeiten;
  final DateTime? von;
  final DateTime? bis;
  final String notiz;
  final bool aktiv;

  /// Läuft die Gabe an diesem Tag? Außerhalb von [von]/[bis] taucht das
  /// Medikament nicht in der Tagesliste auf.
  bool giltAm(DateTime tag) {
    if (!aktiv) return false;
    final d = startOfDay(tag);
    if (von != null && d.isBefore(startOfDay(von!))) return false;
    if (bis != null && d.isAfter(startOfDay(bis!))) return false;
    return true;
  }

  static String zeitLabel(int minuten) {
    final h = (minuten ~/ 60).toString().padLeft(2, '0');
    final m = (minuten % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get zeitenLabel => zeiten.isEmpty
      ? 'ohne feste Uhrzeit'
      : zeiten.map(zeitLabel).join(', ');

  Medication copyWith({
    String? name,
    String? dosis,
    List<int>? zeiten,
    DateTime? von,
    bool clearVon = false,
    DateTime? bis,
    bool clearBis = false,
    String? notiz,
    bool? aktiv,
  }) =>
      Medication(
        id: id,
        name: name ?? this.name,
        dosis: dosis ?? this.dosis,
        zeiten: zeiten ?? this.zeiten,
        von: clearVon ? null : (von ?? this.von),
        bis: clearBis ? null : (bis ?? this.bis),
        notiz: notiz ?? this.notiz,
        aktiv: aktiv ?? this.aktiv,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosis': dosis,
        'zeiten': zeiten,
        'von': von?.toIso8601String(),
        'bis': bis?.toIso8601String(),
        'notiz': notiz,
        'aktiv': aktiv,
      };

  static Medication fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        dosis: json['dosis'] as String? ?? '',
        zeiten: (json['zeiten'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        von: DateTime.tryParse(json['von'] as String? ?? ''),
        bis: DateTime.tryParse(json['bis'] as String? ?? ''),
        notiz: json['notiz'] as String? ?? '',
        aktiv: json['aktiv'] as bool? ?? true,
      );
}

/// Quittung für eine einzelne Gabe.
///
/// Die ID setzt sich aus Medikament, Tag und Uhrzeit zusammen. Dadurch
/// kann dieselbe Gabe nicht doppelt entstehen, auch wenn zwei Personen
/// gleichzeitig abhaken – wichtig, weil genau das der Fehler ist, der
/// bei Medikamenten wehtut.
class MedicationLog {
  MedicationLog({
    required this.medikamentId,
    required this.tag,
    required this.minute,
    required this.gegebenUm,
    this.wer = '',
  });

  final String medikamentId;
  final DateTime tag;
  final int minute;
  final DateTime gegebenUm;
  final String wer;

  String get id => buildId(medikamentId, tag, minute);

  static String buildId(String medikamentId, DateTime tag, int minute) {
    final d = startOfDay(tag);
    final tagTeil = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return '$medikamentId|$tagTeil|$minute';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medikamentId': medikamentId,
        'tag': startOfDay(tag).toIso8601String(),
        'minute': minute,
        'gegebenUm': gegebenUm.toIso8601String(),
        'wer': wer,
      };

  static MedicationLog fromJson(Map<String, dynamic> json) => MedicationLog(
        medikamentId: json['medikamentId'] as String? ?? '',
        tag: DateTime.tryParse(json['tag'] as String? ?? '') ?? DateTime.now(),
        minute: (json['minute'] as num?)?.toInt() ?? 0,
        gegebenUm: DateTime.tryParse(json['gegebenUm'] as String? ?? '') ??
            DateTime.now(),
        wer: json['wer'] as String? ?? '',
      );
}
