import '../core/format.dart';

/// Ein Geschäft: was, wann, wo – das Rohmaterial der Stubenreinheit.
///
/// Jedes Geschäft ist ein eigener Eintrag, auch wenn Pipi und Kaki im
/// selben Gang passieren. Nur so lassen sich die Abstände zwischen
/// zwei Pipis sauber ausrechnen – und genau die bestimmen, wann der
/// nächste Gang fällig ist.
class Geschaeft {
  Geschaeft({
    String? id,
    required this.zeitpunkt,
    required this.art,
    this.ort = Ort.draussen,
    this.gemeldet = false,
    this.notiz = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime zeitpunkt;
  final Geschaeftsart art;
  final Ort ort;

  /// Hat er sich vorher gemeldet (an der Tür gewartet, gefiept …)?
  /// Der eigentliche Fortschritt im Training: Draußen erledigt ist
  /// gut, von selbst angezeigt ist das Ziel.
  final bool gemeldet;
  final String notiz;

  bool get draussen => ort == Ort.draussen;

  /// „Pipi draußen", „Kaki drinnen" …
  String get label => '${art.label} ${ort.label}';

  Geschaeft copyWith({
    DateTime? zeitpunkt,
    Geschaeftsart? art,
    Ort? ort,
    bool? gemeldet,
    String? notiz,
  }) =>
      Geschaeft(
        id: id,
        zeitpunkt: zeitpunkt ?? this.zeitpunkt,
        art: art ?? this.art,
        ort: ort ?? this.ort,
        gemeldet: gemeldet ?? this.gemeldet,
        notiz: notiz ?? this.notiz,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'zeitpunkt': zeitpunkt.toIso8601String(),
        'art': art.name,
        'ort': ort.name,
        'gemeldet': gemeldet,
        'notiz': notiz,
      };

  static Geschaeft fromJson(Map<String, dynamic> json) => Geschaeft(
        id: json['id'] as String?,
        zeitpunkt: DateTime.tryParse(json['zeitpunkt'] as String? ?? '') ??
            DateTime.now(),
        art: Geschaeftsart.parse(json['art'] as String?),
        ort: Ort.parse(json['ort'] as String?),
        gemeldet: json['gemeldet'] as bool? ?? false,
        notiz: json['notiz'] as String? ?? '',
      );
}

enum Geschaeftsart {
  pipi('Pipi'),
  kaki('Kaki');

  const Geschaeftsart(this.label);

  final String label;

  static Geschaeftsart parse(String? raw) => Geschaeftsart.values.firstWhere(
        (a) => a.name == raw,
        orElse: () => Geschaeftsart.pipi,
      );
}

enum Ort {
  draussen('draußen'),
  drinnen('drinnen');

  const Ort(this.label);

  final String label;

  static Ort parse(String? raw) => Ort.values.firstWhere(
        (o) => o.name == raw,
        orElse: () => Ort.draussen,
      );
}
