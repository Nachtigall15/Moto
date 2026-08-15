import '../core/format.dart';

/// Ein Leckerli in der Übersicht: darf er es, und mag er es?
///
/// Die beiden Fragen sind bewusst getrennt – vieles, was er mag, ist
/// nicht erlaubt, und manches Erlaubte rührt er nicht an.
class Treat {
  Treat({
    String? id,
    required this.name,
    this.erlaubt = Erlaubnis.ja,
    this.beliebtheit = 2,
    this.notiz = '',
  }) : id = id ?? newId();

  final String id;
  final String name;
  final Erlaubnis erlaubt;

  /// 0 = mag er nicht … 3 = Lieblingsleckerli.
  final int beliebtheit;
  final String notiz;

  Treat copyWith({
    String? name,
    Erlaubnis? erlaubt,
    int? beliebtheit,
    String? notiz,
  }) =>
      Treat(
        id: id,
        name: name ?? this.name,
        erlaubt: erlaubt ?? this.erlaubt,
        beliebtheit: beliebtheit ?? this.beliebtheit,
        notiz: notiz ?? this.notiz,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'erlaubt': erlaubt.name,
        'beliebtheit': beliebtheit,
        'notiz': notiz,
      };

  static Treat fromJson(Map<String, dynamic> json) => Treat(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        erlaubt: Erlaubnis.parse(json['erlaubt'] as String?),
        beliebtheit: (json['beliebtheit'] as num?)?.toInt() ?? 2,
        notiz: json['notiz'] as String? ?? '',
      );
}

enum Erlaubnis {
  ja('Darf er'),
  inMassen('In Maßen'),
  nein('Darf er nicht');

  const Erlaubnis(this.label);

  final String label;

  static Erlaubnis parse(String? raw) => Erlaubnis.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => Erlaubnis.ja,
      );
}

/// Startliste für die Leckerli-Übersicht.
///
/// Die „Darf er nicht"-Einträge sind die bekannten Klassiker, bei denen
/// es für Hunde wirklich gefährlich wird – die stehen bewusst mit drin,
/// damit sie sichtbar sind, bevor jemand sie verfüttert.
const List<(String name, Erlaubnis erlaubt, String hinweis)>
    standardLeckerli = [
  ('Trockenfleisch / Kausnack', Erlaubnis.ja, ''),
  ('Käsewürfel', Erlaubnis.inMassen, 'Salzig und fett – nur kleine Stücke.'),
  ('Möhre (roh)', Erlaubnis.ja, 'Kalorienarm, gut für zwischendurch.'),
  ('Apfel (ohne Kerngehäuse)', Erlaubnis.ja, 'Kerne entfernen.'),
  ('Gurke', Erlaubnis.ja, ''),
  ('Banane', Erlaubnis.inMassen, 'Viel Zucker.'),
  ('Hüttenkäse / Quark', Erlaubnis.inMassen, ''),
  ('Schokolade', Erlaubnis.nein, 'Theobromin – für Hunde giftig.'),
  ('Weintrauben & Rosinen', Erlaubnis.nein, 'Können die Nieren schädigen.'),
  ('Zwiebeln & Knoblauch', Erlaubnis.nein, 'Schädigen die roten Blutkörperchen.'),
  ('Avocado', Erlaubnis.nein, 'Persin – nicht verfüttern.'),
  ('Xylit (Birkenzucker)', Erlaubnis.nein, 'Schon in kleinen Mengen '
      'lebensgefährlich – auch in zuckerfreiem Kaugummi.'),
  ('Rohes Schweinefleisch', Erlaubnis.nein, 'Risiko Aujeszky-Virus.'),
  ('Gekochte Knochen', Erlaubnis.nein, 'Splittern und können verletzen.'),
];
