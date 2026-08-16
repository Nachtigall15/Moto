import '../core/format.dart';

/// Eine Messung – Gewicht, optional die Widerristhöhe, optional ein
/// Foto. Alles zum selben Zeitpunkt, damit die Entwicklung nicht auf
/// drei getrennte Listen zerfällt.
class WeightEntry {
  WeightEntry({
    String? id,
    required this.zeitpunkt,
    required this.gewichtKg,
    this.groesseCm,
    this.fotoRef,
    this.notiz = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime zeitpunkt;
  final double gewichtKg;

  /// Widerristhöhe in Zentimetern. Wird selten gemessen, deshalb
  /// optional – eine Messung ohne Größe ist trotzdem eine gültige
  /// Messung.
  final double? groesseCm;

  final String? fotoRef;
  final String notiz;

  bool get hatFoto => fotoRef != null && fotoRef!.isNotEmpty;
  bool get hatGroesse => groesseCm != null && groesseCm! > 0;

  String get gewichtLabel => '${nfWeight.format(gewichtKg)} kg';
  String? get groesseLabel =>
      hatGroesse ? '${nfAmount.format(groesseCm)} cm' : null;

  WeightEntry copyWith({
    DateTime? zeitpunkt,
    double? gewichtKg,
    double? groesseCm,
    bool clearGroesse = false,
    String? fotoRef,
    bool clearFoto = false,
    String? notiz,
  }) =>
      WeightEntry(
        id: id,
        zeitpunkt: zeitpunkt ?? this.zeitpunkt,
        gewichtKg: gewichtKg ?? this.gewichtKg,
        groesseCm: clearGroesse ? null : (groesseCm ?? this.groesseCm),
        fotoRef: clearFoto ? null : (fotoRef ?? this.fotoRef),
        notiz: notiz ?? this.notiz,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'zeitpunkt': zeitpunkt.toIso8601String(),
        'gewichtKg': gewichtKg,
        'groesseCm': groesseCm,
        'fotoRef': fotoRef,
        'notiz': notiz,
      };

  static WeightEntry fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String?,
        zeitpunkt:
            DateTime.tryParse(json['zeitpunkt'] as String? ?? '') ??
                DateTime.now(),
        gewichtKg: (json['gewichtKg'] as num?)?.toDouble() ?? 0,
        groesseCm: (json['groesseCm'] as num?)?.toDouble(),
        fotoRef: json['fotoRef'] as String?,
        notiz: json['notiz'] as String? ?? '',
      );
}
