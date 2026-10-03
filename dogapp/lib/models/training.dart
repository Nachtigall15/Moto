import '../core/format.dart';

/// Eine Übung aus dem Trainingsplan.
class TrainingExercise {
  TrainingExercise({
    String? id,
    required this.name,
    this.gruppe = TrainingGruppe.grundlagen,
    this.beschreibung = '',
    this.stand = Trainingsstand.offen,
    this.notiz = '',
    this.reihenfolge = 0,
  }) : id = id ?? newId();

  final String id;
  final String name;
  final TrainingGruppe gruppe;
  final String beschreibung;
  final Trainingsstand stand;
  final String notiz;
  final int reihenfolge;

  TrainingExercise copyWith({
    String? name,
    TrainingGruppe? gruppe,
    String? beschreibung,
    Trainingsstand? stand,
    String? notiz,
    int? reihenfolge,
  }) =>
      TrainingExercise(
        id: id,
        name: name ?? this.name,
        gruppe: gruppe ?? this.gruppe,
        beschreibung: beschreibung ?? this.beschreibung,
        stand: stand ?? this.stand,
        notiz: notiz ?? this.notiz,
        reihenfolge: reihenfolge ?? this.reihenfolge,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gruppe': gruppe.name,
        'beschreibung': beschreibung,
        'stand': stand.name,
        'notiz': notiz,
        'reihenfolge': reihenfolge,
      };

  static TrainingExercise fromJson(Map<String, dynamic> json) =>
      TrainingExercise(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        gruppe: TrainingGruppe.parse(json['gruppe'] as String?),
        beschreibung: json['beschreibung'] as String? ?? '',
        stand: Trainingsstand.parse(json['stand'] as String?),
        notiz: json['notiz'] as String? ?? '',
        reihenfolge: (json['reihenfolge'] as num?)?.toInt() ?? 0,
      );
}

enum TrainingGruppe {
  grundlagen('Grundlagen'),
  leine('Leine & Führen'),
  alltag('Alltag & Umwelt'),
  spiel('Suchen & Tricks');

  const TrainingGruppe(this.label);

  final String label;

  static TrainingGruppe parse(String? raw) =>
      TrainingGruppe.values.firstWhere(
        (g) => g.name == raw,
        orElse: () => TrainingGruppe.grundlagen,
      );
}

enum Trainingsstand {
  offen('Noch offen'),
  inArbeit('In Arbeit'),
  sitzt('Sitzt');

  const Trainingsstand(this.label);

  final String label;

  static Trainingsstand parse(String? raw) =>
      Trainingsstand.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => Trainingsstand.offen,
      );
}

/// Abhaken, dass eine Übung an einem Tag geübt wurde.
///
/// Wie bei den Medikamenten ergibt sich die ID aus Übung und Tag –
/// zwei Personen können denselben Haken nicht doppelt setzen.
class TrainingLog {
  TrainingLog({
    required this.uebungId,
    required this.tag,
    required this.erledigtUm,
    this.wer = '',
  });

  final String uebungId;
  final DateTime tag;
  final DateTime erledigtUm;
  final String wer;

  String get id => buildId(uebungId, tag);

  static String buildId(String uebungId, DateTime tag) {
    final d = startOfDay(tag);
    return '$uebungId|${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uebungId': uebungId,
        'tag': startOfDay(tag).toIso8601String(),
        'erledigtUm': erledigtUm.toIso8601String(),
        'wer': wer,
      };

  static TrainingLog fromJson(Map<String, dynamic> json) => TrainingLog(
        uebungId: json['uebungId'] as String? ?? '',
        tag: DateTime.tryParse(json['tag'] as String? ?? '') ?? DateTime.now(),
        erledigtUm: DateTime.tryParse(json['erledigtUm'] as String? ?? '') ??
            DateTime.now(),
        wer: json['wer'] as String? ?? '',
      );
}

/// Trainingsplan: eine Auswahl von Übungen, die gerade dran sind.
class TrainingPlan {
  TrainingPlan({
    String? id,
    required this.titel,
    this.beschreibung = '',
    List<String>? uebungIds,
    this.aktiv = true,
  })  : id = id ?? newId(),
        uebungIds = uebungIds == null
            ? const []
            : List<String>.unmodifiable(uebungIds);

  final String id;
  final String titel;
  final String beschreibung;
  final List<String> uebungIds;
  final bool aktiv;

  TrainingPlan copyWith({
    String? titel,
    String? beschreibung,
    List<String>? uebungIds,
    bool? aktiv,
  }) =>
      TrainingPlan(
        id: id,
        titel: titel ?? this.titel,
        beschreibung: beschreibung ?? this.beschreibung,
        uebungIds: uebungIds ?? this.uebungIds,
        aktiv: aktiv ?? this.aktiv,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titel': titel,
        'beschreibung': beschreibung,
        'uebungIds': uebungIds,
        'aktiv': aktiv,
      };

  static TrainingPlan fromJson(Map<String, dynamic> json) => TrainingPlan(
        id: json['id'] as String?,
        titel: json['titel'] as String? ?? '',
        beschreibung: json['beschreibung'] as String? ?? '',
        uebungIds: (json['uebungIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        aktiv: json['aktiv'] as bool? ?? true,
      );
}

/// Startkatalog der Übungen.
///
/// Aufbau und Reihenfolge orientieren sich an der Arbeit von Anton
/// Fichtlmeier: erst Ruhe, Aufmerksamkeit und Körpersprache, dann die
/// Signale, dann Ablenkung und Alltag. Die Beschreibungen sind kurze
/// eigene Merksätze – ersetzen also kein Buch und keine Hundeschule,
/// sondern erinnern beim Üben an den Kern.
const List<(String name, TrainingGruppe gruppe, String hinweis)>
    standardUebungen = [
  (
    'Name / Aufmerksamkeit',
    TrainingGruppe.grundlagen,
    'Name nur einmal, freundlich. Blickkontakt sofort belohnen – der '
        'Name ist keine Ansage, sondern eine Einladung.',
  ),
  (
    'Loben',
    TrainingGruppe.grundlagen,
    'Ruhig und im richtigen Moment: direkt beim gewünschten Verhalten, '
        'nicht erst hinterher. Stimme tief und freundlich.',
  ),
  (
    'Sitz',
    TrainingGruppe.grundlagen,
    'Aus der Bewegung heraus anbieten lassen, Signal erst benennen, '
        'wenn das Verhalten zuverlässig kommt.',
  ),
  (
    'Platz',
    TrainingGruppe.grundlagen,
    'Ruhig ablegen, Körperspannung rausnehmen. Erst Dauer aufbauen, '
        'dann Entfernung, dann Ablenkung – nie alles gleichzeitig.',
  ),
  (
    'Bleib',
    TrainingGruppe.grundlagen,
    'Kurz anfangen, immer selbst zurückkommen und auflösen. Lieber '
        'zehnmal drei Sekunden als einmal dreißig.',
  ),
  (
    'Aus / Hergeben',
    TrainingGruppe.grundlagen,
    'Tausch statt Kampf: etwas Gleichwertiges anbieten, ruhig bleiben, '
        'Hergeben belohnen.',
  ),
  (
    'Verbieten / Unterbinden',
    TrainingGruppe.grundlagen,
    'Klar, kurz und ohne Lautstärke. Danach eine Alternative anbieten, '
        'damit der Hund weiß, was stattdessen geht.',
  ),
  (
    'Auf den Platz gehen',
    TrainingGruppe.grundlagen,
    'Fester Liegeplatz als Ruheort. Hinschicken, Ruhe belohnen, '
        'Auflösen deutlich machen.',
  ),
  (
    'Rückruf / Hier',
    TrainingGruppe.leine,
    'Nur rufen, wenn die Chance gut steht. Ankommen immer lohnend '
        'machen – nie zum Rückruf schimpfen.',
  ),
  (
    'Leinenführigkeit',
    TrainingGruppe.leine,
    'Lockere Leine ist die Belohnung. Bei Zug stehen bleiben oder die '
        'Richtung wechseln, statt gegenzuziehen.',
  ),
  (
    'Bei mir / Fuß',
    TrainingGruppe.leine,
    'Kurze Strecken mit Blickkontakt, dann auflösen. Körpersprache '
        'führt, das Signal begleitet nur.',
  ),
  (
    'Straße überqueren',
    TrainingGruppe.alltag,
    'Am Bordstein automatisch anhalten und sitzen, erst auf Freigabe '
        'los. Jedes Mal gleich ablaufen lassen.',
  ),
  (
    'Autofahren',
    TrainingGruppe.alltag,
    'Ein- und Aussteigen auf Signal, im Auto liegen und ruhen. Kurze '
        'Fahrten mit gutem Ende.',
  ),
  (
    'Alleine bleiben',
    TrainingGruppe.alltag,
    'In Sekunden beginnen und ohne Verabschiedungsdrama. Zurückkommen, '
        'bevor Unruhe entsteht.',
  ),
  (
    'Begegnungen (Hunde, Menschen)',
    TrainingGruppe.alltag,
    'Genug Abstand wählen, dass der Hund noch ansprechbar ist, und '
        'Aufmerksamkeit belohnen.',
  ),
  (
    'Pfote geben',
    TrainingGruppe.spiel,
    'Kleiner Trick zum Auflockern – gut geeignet, um zwischendurch '
        'Erfolgserlebnisse einzustreuen.',
  ),
  (
    'Such / Verlorensuche',
    TrainingGruppe.spiel,
    'Nasenarbeit macht müder als Rennen. Einfach anfangen: sichtbar '
        'ausgelegt, dann versteckt.',
  ),
  (
    'Apportieren',
    TrainingGruppe.spiel,
    'Bringen und Hergeben getrennt üben und erst am Ende zusammen-'
        'setzen.',
  ),
];
