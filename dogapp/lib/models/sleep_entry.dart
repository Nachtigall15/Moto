import '../core/format.dart';

/// Eine Schlafphase. [ende] ist null, solange der Hund noch schläft –
/// so kann man den Schlaf per Knopfdruck starten und später beenden.
class SleepEntry {
  SleepEntry({
    String? id,
    required this.start,
    this.ende,
    this.ort = '',
    this.notiz = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime start;
  final DateTime? ende;
  final String ort;
  final String notiz;

  bool get laeuft => ende == null;

  Duration get dauer => (ende ?? DateTime.now()).difference(start);

  String get dauerLabel => formatDuration(dauer);

  SleepEntry copyWith({
    DateTime? start,
    DateTime? ende,
    bool clearEnde = false,
    String? ort,
    String? notiz,
  }) =>
      SleepEntry(
        id: id,
        start: start ?? this.start,
        ende: clearEnde ? null : (ende ?? this.ende),
        ort: ort ?? this.ort,
        notiz: notiz ?? this.notiz,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'ende': ende?.toIso8601String(),
        'ort': ort,
        'notiz': notiz,
      };

  static SleepEntry fromJson(Map<String, dynamic> json) => SleepEntry(
        id: json['id'] as String?,
        start: DateTime.tryParse(json['start'] as String? ?? '') ??
            DateTime.now(),
        ende: DateTime.tryParse(json['ende'] as String? ?? ''),
        ort: json['ort'] as String? ?? '',
        notiz: json['notiz'] as String? ?? '',
      );
}

/// Der Teil einer Schlafphase, der auf einen bestimmten Tag fällt.
///
/// Eine Nacht von 22:00 bis 6:00 gehört zur Hälfte zu dem einen und zur
/// Hälfte zu dem anderen Tag. Ohne diese Zerlegung landet die ganze
/// Nacht auf dem Tag, an dem sie begonnen hat – und der Morgen fehlt
/// dort, wo er tatsächlich stattgefunden hat.
///
/// Gespeichert bleibt trotzdem eine einzige Phase: Der Schnitt ist
/// reine Anzeige- und Rechensache, und beim Bearbeiten hat man wieder
/// die ganze Nacht vor sich statt zweier Bruchstücke.
class Schlafabschnitt {
  const Schlafabschnitt({
    required this.phase,
    required this.tag,
    required this.von,
    required this.bis,
    required this.kommtVonGestern,
    required this.gehtWeiter,
  });

  final SleepEntry phase;

  /// Tagesbeginn des Tages, auf den dieser Abschnitt fällt.
  final DateTime tag;

  final DateTime von;
  final DateTime bis;

  /// Die Phase hat schon vor diesem Tag begonnen.
  final bool kommtVonGestern;

  /// Die Phase reicht über diesen Tag hinaus.
  final bool gehtWeiter;

  /// Ein noch laufender Abschnitt: Der Hund schläft gerade und dieser
  /// Tag ist der letzte der Phase. Solche Abschnitte zählen nicht in
  /// die Tagessumme, weil sie im Sekundentakt weiterwachsen.
  bool get offen => phase.laeuft && !gehtWeiter;

  Duration get dauer => bis.difference(von);

  String get dauerLabel => formatDuration(dauer);

  /// Zeitspanne dieses Tages. Mitternacht steht als „24:00" am
  /// Tagesende und als „00:00" am Tagesanfang – so liest sich die
  /// Nacht in beiden Zeilen richtig herum.
  String get zeitLabel {
    final beginn = kommtVonGestern ? '00:00' : dfTime.format(von);
    if (offen) return 'seit $beginn Uhr';
    final schluss = gehtWeiter ? '24:00' : dfTime.format(bis);
    return '$beginn – $schluss Uhr';
  }

  /// Hinweis auf den Teil, der auf dem Nachbartag liegt.
  String? get uebergang {
    if (kommtVonGestern && gehtWeiter) return 'durchgehend';
    if (kommtVonGestern) {
      return 'seit ${dfTime.format(phase.start)} Uhr am Vortag';
    }
    if (gehtWeiter) {
      final ende = phase.ende;
      return ende == null
          ? 'läuft über Mitternacht'
          : 'bis ${dfTime.format(ende)} Uhr am Folgetag';
    }
    return null;
  }
}

/// Zerlegt eine Phase an den Tagesgrenzen – eine Phase innerhalb eines
/// Tages ergibt genau einen Abschnitt.
///
/// [jetzt] ist nur für Tests da; sonst zählt eine laufende Phase bis
/// zur aktuellen Uhrzeit.
List<Schlafabschnitt> zerlegeNachTagen(SleepEntry phase, {DateTime? jetzt}) {
  final ende = phase.ende ?? (jetzt ?? DateTime.now());
  final abschnitte = <Schlafabschnitt>[];

  var tag = startOfDay(phase.start);
  // Notbremse gegen kaputte Daten: Ein Eintrag über Jahre hinweg würde
  // sonst tausende Abschnitte erzeugen und die Liste lahmlegen.
  for (var i = 0; i < 366; i++) {
    // Über DateTime statt add(Duration(days: 1)): An den Tagen der
    // Zeitumstellung hat ein Tag 23 oder 25 Stunden.
    final naechsterTag = DateTime(tag.year, tag.month, tag.day + 1);
    final von = phase.start.isAfter(tag) ? phase.start : tag;
    final bis = ende.isBefore(naechsterTag) ? ende : naechsterTag;

    abschnitte.add(Schlafabschnitt(
      phase: phase,
      tag: tag,
      von: von,
      bis: bis.isBefore(von) ? von : bis,
      kommtVonGestern: phase.start.isBefore(tag),
      gehtWeiter: ende.isAfter(naechsterTag),
    ));

    if (!ende.isAfter(naechsterTag)) break;
    tag = naechsterTag;
  }
  return abschnitte;
}
