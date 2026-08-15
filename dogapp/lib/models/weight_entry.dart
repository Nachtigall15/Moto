import '../core/format.dart';

/// Ein Wiegevorgang – optional mit Foto, damit neben der Zahl auch die
/// äußerliche Entwicklung dokumentiert ist.
class WeightEntry {
  WeightEntry({
    String? id,
    required this.zeitpunkt,
    required this.gewichtKg,
    this.fotoRef,
    this.notiz = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime zeitpunkt;
  final double gewichtKg;
  final String? fotoRef;
  final String notiz;

  bool get hatFoto => fotoRef != null && fotoRef!.isNotEmpty;

  String get gewichtLabel => '${nfWeight.format(gewichtKg)} kg';

  WeightEntry copyWith({
    DateTime? zeitpunkt,
    double? gewichtKg,
    String? fotoRef,
    bool clearFoto = false,
    String? notiz,
  }) =>
      WeightEntry(
        id: id,
        zeitpunkt: zeitpunkt ?? this.zeitpunkt,
        gewichtKg: gewichtKg ?? this.gewichtKg,
        fotoRef: clearFoto ? null : (fotoRef ?? this.fotoRef),
        notiz: notiz ?? this.notiz,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'zeitpunkt': zeitpunkt.toIso8601String(),
        'gewichtKg': gewichtKg,
        'fotoRef': fotoRef,
        'notiz': notiz,
      };

  static WeightEntry fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String?,
        zeitpunkt:
            DateTime.tryParse(json['zeitpunkt'] as String? ?? '') ??
                DateTime.now(),
        gewichtKg: (json['gewichtKg'] as num?)?.toDouble() ?? 0,
        fotoRef: json['fotoRef'] as String?,
        notiz: json['notiz'] as String? ?? '',
      );
}
