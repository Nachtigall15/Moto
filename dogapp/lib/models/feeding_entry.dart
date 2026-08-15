import '../core/format.dart';

/// Eine einzelne Fütterung: was, wann, wie viel.
class FeedingEntry {
  FeedingEntry({
    String? id,
    required this.zeitpunkt,
    required this.futter,
    required this.menge,
    this.einheit = Einheit.gramm,
    this.mahlzeit = Mahlzeit.hauptmahlzeit,
    this.notiz = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime zeitpunkt;
  final String futter;
  final double menge;
  final Einheit einheit;
  final Mahlzeit mahlzeit;
  final String notiz;

  String get mengeLabel => '${nfAmount.format(menge)} ${einheit.label}';

  FeedingEntry copyWith({
    DateTime? zeitpunkt,
    String? futter,
    double? menge,
    Einheit? einheit,
    Mahlzeit? mahlzeit,
    String? notiz,
  }) =>
      FeedingEntry(
        id: id,
        zeitpunkt: zeitpunkt ?? this.zeitpunkt,
        futter: futter ?? this.futter,
        menge: menge ?? this.menge,
        einheit: einheit ?? this.einheit,
        mahlzeit: mahlzeit ?? this.mahlzeit,
        notiz: notiz ?? this.notiz,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'zeitpunkt': zeitpunkt.toIso8601String(),
        'futter': futter,
        'menge': menge,
        'einheit': einheit.name,
        'mahlzeit': mahlzeit.name,
        'notiz': notiz,
      };

  static FeedingEntry fromJson(Map<String, dynamic> json) => FeedingEntry(
        id: json['id'] as String?,
        zeitpunkt:
            DateTime.tryParse(json['zeitpunkt'] as String? ?? '') ??
                DateTime.now(),
        futter: json['futter'] as String? ?? '',
        menge: (json['menge'] as num?)?.toDouble() ?? 0,
        einheit: Einheit.parse(json['einheit'] as String?),
        mahlzeit: Mahlzeit.parse(json['mahlzeit'] as String?),
        notiz: json['notiz'] as String? ?? '',
      );
}

enum Einheit {
  gramm('g'),
  milliliter('ml'),
  stueck('Stück');

  const Einheit(this.label);

  final String label;

  static Einheit parse(String? raw) => Einheit.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => Einheit.gramm,
      );
}

enum Mahlzeit {
  fruehstueck('Frühstück'),
  hauptmahlzeit('Hauptmahlzeit'),
  abendessen('Abendessen'),
  snack('Snack'),
  leckerli('Leckerli');

  const Mahlzeit(this.label);

  final String label;

  static Mahlzeit parse(String? raw) => Mahlzeit.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => Mahlzeit.hauptmahlzeit,
      );
}
