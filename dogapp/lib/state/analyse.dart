import '../core/format.dart';
import '../models/feeding_entry.dart';
import '../models/sleep_entry.dart';

/// Auswertung von Fütterung und Schlaf – reine Rechenarbeit ohne
/// Oberfläche, damit sie sich einzeln prüfen lässt.
///
/// Alles hier rechnet nur mit dem, was gerade geladen ist. Die App
/// lädt aus Geschwindigkeitsgründen einen Ausschnitt der jüngsten
/// Vergangenheit; wer weiter zurückschauen will, muss erst „Ältere
/// laden". Der Bildschirm sagt das auch dazu.

/// Zeitfenster der Auswertung.
enum Zeitraum {
  woche('7 Tage', 7),
  monat('30 Tage', 30),
  quartal('90 Tage', 90),
  alles('Alles', null);

  const Zeitraum(this.label, this.tage);

  final String label;

  /// null heißt: keine Grenze.
  final int? tage;

  /// Frühester Tag, der noch zählt. Über das Datum gerechnet, nicht
  /// über 24-Stunden-Schritte – an den Tagen der Zeitumstellung wäre
  /// das sonst um eine Stunde daneben.
  DateTime? ab(DateTime jetzt) => tage == null
      ? null
      : DateTime(jetzt.year, jetzt.month, jetzt.day - (tage! - 1));
}

/// Wochentagskürzel, Index = `DateTime.weekday - 1`.
const List<String> wochentagKurz = [
  'Mo',
  'Di',
  'Mi',
  'Do',
  'Fr',
  'Sa',
  'So',
];

const List<String> wochentagLang = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

/// Minuten seit Mitternacht als „07:30".
String uhrzeitLabel(int minuten) {
  final h = (minuten ~/ 60) % 24;
  final m = minuten % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

// --- Fütterung --------------------------------------------------------

/// Ein Wochentag in der Fütterungsauswertung.
class FutterWochentag {
  FutterWochentag({
    required this.wochentag,
    required this.zeiten,
    required this.erfassteTage,
    required this.menge,
  });

  /// `DateTime.monday` … `DateTime.sunday`.
  final int wochentag;

  /// Uhrzeiten der Mahlzeiten als Minuten seit Mitternacht, aufsteigend.
  final List<int> zeiten;

  /// Kalendertage dieses Wochentags, an denen überhaupt etwas erfasst
  /// wurde. Nur durch die wird geteilt: Tage ohne Eintrag könnten
  /// ebenso gut Tage ohne App-Benutzung sein.
  final int erfassteTage;

  final Map<Einheit, double> menge;

  String get kurz => wochentagKurz[wochentag - 1];
  String get lang => wochentagLang[wochentag - 1];

  int get anzahl => zeiten.length;

  double get mahlzeitenProTag => erfassteTage == 0 ? 0 : anzahl / erfassteTage;

  Map<Einheit, double> get mengeProTag => erfassteTage == 0
      ? const {}
      : {
          for (final e in menge.entries) e.key: e.value / erfassteTage,
        };
}

/// Eine wiederkehrende Fütterungszeit, z. B. „07:10, 12 Mal".
class Zeitfenster {
  Zeitfenster({
    required this.von,
    required this.bis,
    required this.mittel,
    required this.anzahl,
  });

  /// Alles in Minuten seit Mitternacht.
  final int von;
  final int bis;
  final int mittel;
  final int anzahl;

  /// „07:10" bei einem Punkt, sonst „06:55 – 07:25".
  String get label =>
      von == bis ? uhrzeitLabel(mittel) : '${uhrzeitLabel(von)} – ${uhrzeitLabel(bis)}';
}

class FutterAnalyse {
  FutterAnalyse({
    required this.wochentage,
    required this.typischeZeiten,
    required this.erfassteTage,
    required this.menge,
  });

  /// Immer sieben Einträge, Montag zuerst.
  final List<FutterWochentag> wochentage;

  /// Zeitfenster über alle Tage hinweg, häufigstes zuerst.
  final List<Zeitfenster> typischeZeiten;

  final int erfassteTage;
  final Map<Einheit, double> menge;

  int get anzahl =>
      wochentage.fold(0, (summe, w) => summe + w.anzahl);

  bool get leer => anzahl == 0;

  double get mahlzeitenProTag => erfassteTage == 0 ? 0 : anzahl / erfassteTage;

  Map<Einheit, double> get mengeProTag => erfassteTage == 0
      ? const {}
      : {for (final e in menge.entries) e.key: e.value / erfassteTage};
}

/// Fütterungszeiten auswerten.
///
/// Leckerli bleiben außen vor: Sie fallen beim Training an und würden
/// das Bild der Mahlzeiten verwischen.
FutterAnalyse werteFutterAus(
  Iterable<FeedingEntry> eintraege, {
  Zeitraum zeitraum = Zeitraum.monat,
  DateTime? jetzt,
}) {
  final grenze = zeitraum.ab(jetzt ?? DateTime.now());
  final mahlzeiten = [
    for (final f in eintraege)
      if (f.mahlzeit != Mahlzeit.leckerli &&
          (grenze == null || !startOfDay(f.zeitpunkt).isBefore(grenze)))
        f,
  ];

  final zeitenJeTag = {for (var w = 1; w <= 7; w++) w: <int>[]};
  final mengeJeTag = {for (var w = 1; w <= 7; w++) w: <Einheit, double>{}};
  final tageJeWochentag = {for (var w = 1; w <= 7; w++) w: <DateTime>{}};
  final alleTage = <DateTime>{};
  final gesamtmenge = <Einheit, double>{};

  for (final f in mahlzeiten) {
    final tag = startOfDay(f.zeitpunkt);
    final w = f.zeitpunkt.weekday;
    zeitenJeTag[w]!.add(f.zeitpunkt.hour * 60 + f.zeitpunkt.minute);
    tageJeWochentag[w]!.add(tag);
    alleTage.add(tag);
    if (f.menge > 0) {
      mengeJeTag[w]![f.einheit] = (mengeJeTag[w]![f.einheit] ?? 0) + f.menge;
      gesamtmenge[f.einheit] = (gesamtmenge[f.einheit] ?? 0) + f.menge;
    }
  }

  return FutterAnalyse(
    wochentage: [
      for (var w = 1; w <= 7; w++)
        FutterWochentag(
          wochentag: w,
          zeiten: zeitenJeTag[w]!..sort(),
          erfassteTage: tageJeWochentag[w]!.length,
          menge: _sortiereEinheiten(mengeJeTag[w]!),
        ),
    ],
    typischeZeiten: _fasseZeitenZusammen(
      [for (final f in mahlzeiten) f.zeitpunkt.hour * 60 + f.zeitpunkt.minute],
    ),
    erfassteTage: alleTage.length,
    menge: _sortiereEinheiten(gesamtmenge),
  );
}

Map<Einheit, double> _sortiereEinheiten(Map<Einheit, double> roh) => {
      for (final e in Einheit.values)
        if (roh.containsKey(e)) e: roh[e]!,
    };

/// Abstand, ab dem zwei Uhrzeiten als verschiedene Mahlzeiten gelten.
const int _zeitfensterAbstand = 90;

/// Uhrzeiten zu Fenstern bündeln: Was dichter als [_zeitfensterAbstand]
/// beieinanderliegt, ist dieselbe Mahlzeit an verschiedenen Tagen.
List<Zeitfenster> _fasseZeitenZusammen(List<int> minuten) {
  if (minuten.isEmpty) return const [];
  final sortiert = [...minuten]..sort();

  final gruppen = <List<int>>[
    [sortiert.first]
  ];
  for (final m in sortiert.skip(1)) {
    if (m - gruppen.last.last <= _zeitfensterAbstand) {
      gruppen.last.add(m);
    } else {
      gruppen.add([m]);
    }
  }

  final fenster = [
    for (final g in gruppen)
      Zeitfenster(
        von: g.first,
        bis: g.last,
        // Median statt Mittelwert: Ein einzelnes spätes Abendessen
        // soll die typische Zeit nicht verschieben.
        mittel: g[g.length ~/ 2],
        anzahl: g.length,
      ),
  ]..sort((a, b) {
      final nachAnzahl = b.anzahl.compareTo(a.anzahl);
      return nachAnzahl != 0 ? nachAnzahl : a.mittel.compareTo(b.mittel);
    });
  return fenster;
}

// --- Schlaf -----------------------------------------------------------

/// Ein Wochentag in der Schlafauswertung.
class SchlafWochentag {
  SchlafWochentag({
    required this.wochentag,
    required this.gesamt,
    required this.zyklen,
    required this.minutenJeStunde,
    required this.erfassteTage,
  });

  final int wochentag;

  /// Summe der Zeit, die an diesem Wochentag geschlafen wurde – Nächte
  /// über Mitternacht anteilig, wie in der Schlafliste auch.
  final Duration gesamt;

  /// Länge der Phasen, die an diesem Wochentag begonnen haben. Ein
  /// Zyklus gehört zu dem Tag, an dem er anfing; sonst zerfiele die
  /// Nacht in zwei kurze Zyklen, die es nie gab.
  final List<Duration> zyklen;

  /// 24 Werte: Minuten Schlaf in dieser Stunde des Tages, summiert über
  /// alle Kalendertage dieses Wochentags.
  final List<double> minutenJeStunde;

  final int erfassteTage;

  String get kurz => wochentagKurz[wochentag - 1];
  String get lang => wochentagLang[wochentag - 1];

  Duration get proTag => erfassteTage == 0
      ? Duration.zero
      : Duration(minutes: gesamt.inMinutes ~/ erfassteTage);

  Duration get zyklusSchnitt => zyklen.isEmpty
      ? Duration.zero
      : Duration(
          minutes: zyklen.fold(0, (s, d) => s + d.inMinutes) ~/ zyklen.length,
        );

  double get zyklenProTag =>
      erfassteTage == 0 ? 0 : zyklen.length / erfassteTage;
}

/// Eine Größenklasse von Schlafzyklen, z. B. „1–2 h: 7 Zyklen".
class Zyklusklasse {
  const Zyklusklasse(this.label, this.bis);

  final String label;

  /// Obergrenze in Minuten; null für „alles darüber".
  final int? bis;
}

const List<Zyklusklasse> zyklusklassen = [
  Zyklusklasse('bis 30 min', 30),
  Zyklusklasse('30–60 min', 60),
  Zyklusklasse('1–2 h', 120),
  Zyklusklasse('2–4 h', 240),
  Zyklusklasse('über 4 h', null),
];

class SchlafAnalyse {
  SchlafAnalyse({
    required this.wochentage,
    required this.zyklen,
    required this.gesamt,
    required this.erfassteTage,
  });

  /// Immer sieben Einträge, Montag zuerst.
  final List<SchlafWochentag> wochentage;

  /// Alle Zyklen im Zeitraum, längster zuerst.
  final List<Duration> zyklen;

  final Duration gesamt;
  final int erfassteTage;

  bool get leer => gesamt == Duration.zero && zyklen.isEmpty;

  Duration get proTag => erfassteTage == 0
      ? Duration.zero
      : Duration(minutes: gesamt.inMinutes ~/ erfassteTage);

  Duration get zyklusSchnitt => zyklen.isEmpty
      ? Duration.zero
      : Duration(
          minutes: zyklen.fold(0, (s, d) => s + d.inMinutes) ~/ zyklen.length,
        );

  Duration get laengsterZyklus => zyklen.isEmpty ? Duration.zero : zyklen.first;

  double get zyklenProTag =>
      erfassteTage == 0 ? 0 : zyklen.length / erfassteTage;

  /// Wie viele Zyklen in welche Größenklasse fallen – die Klassen sind
  /// aufsteigend sortiert, jeder Zyklus landet in der ersten, in die er
  /// passt.
  List<int> get klassenVerteilung {
    final zaehler = List<int>.filled(zyklusklassen.length, 0);
    for (final d in zyklen) {
      for (var i = 0; i < zyklusklassen.length; i++) {
        final bis = zyklusklassen[i].bis;
        if (bis == null || d.inMinutes <= bis) {
          zaehler[i]++;
          break;
        }
      }
    }
    return zaehler;
  }

  /// Höchster Stundenwert – Maßstab für die Einfärbung des Rasters.
  double get stundenSpitze {
    var spitze = 0.0;
    for (final w in wochentage) {
      for (final m in w.minutenJeStunde) {
        if (m > spitze) spitze = m;
      }
    }
    return spitze;
  }
}

/// Schlafzeiten auswerten.
SchlafAnalyse werteSchlafAus(
  Iterable<SleepEntry> phasen, {
  Zeitraum zeitraum = Zeitraum.monat,
  DateTime? jetzt,
}) {
  final referenz = jetzt ?? DateTime.now();
  final grenze = zeitraum.ab(referenz);

  final dauerJeTag = {for (var w = 1; w <= 7; w++) w: 0};
  final zyklenJeTag = {for (var w = 1; w <= 7; w++) w: <Duration>[]};
  final stundenJeTag = {
    for (var w = 1; w <= 7; w++) w: List<double>.filled(24, 0),
  };
  final tageJeWochentag = {for (var w = 1; w <= 7; w++) w: <DateTime>{}};
  final alleTage = <DateTime>{};
  final alleZyklen = <Duration>[];
  var gesamt = 0;

  for (final phase in phasen) {
    // Ganze Phase als Zyklus – am Tag ihres Beginns.
    if (!phase.laeuft &&
        (grenze == null || !startOfDay(phase.start).isBefore(grenze))) {
      zyklenJeTag[phase.start.weekday]!.add(phase.dauer);
      alleZyklen.add(phase.dauer);
    }

    for (final a in zerlegeNachTagen(phase, jetzt: referenz)) {
      // Der noch laufende Teil wächst im Sekundentakt – der bleibt
      // draußen, wie überall in der App.
      if (a.offen) continue;
      if (grenze != null && a.tag.isBefore(grenze)) continue;

      final w = a.tag.weekday;
      final minuten = a.dauer.inMinutes;
      dauerJeTag[w] = dauerJeTag[w]! + minuten;
      gesamt += minuten;
      tageJeWochentag[w]!.add(a.tag);
      alleTage.add(a.tag);

      final von = a.von.difference(a.tag).inMinutes.clamp(0, 1440);
      final bis = a.bis.difference(a.tag).inMinutes.clamp(0, 1440);
      for (var stunde = 0; stunde < 24; stunde++) {
        final anfang = stunde * 60;
        final ende = anfang + 60;
        final ueberschneidung =
            (bis < ende ? bis : ende) - (von > anfang ? von : anfang);
        if (ueberschneidung > 0) {
          stundenJeTag[w]![stunde] += ueberschneidung;
        }
      }
    }
  }

  return SchlafAnalyse(
    wochentage: [
      for (var w = 1; w <= 7; w++)
        SchlafWochentag(
          wochentag: w,
          gesamt: Duration(minutes: dauerJeTag[w]!),
          zyklen: zyklenJeTag[w]!..sort((a, b) => b.compareTo(a)),
          minutenJeStunde: stundenJeTag[w]!,
          erfassteTage: tageJeWochentag[w]!.length,
        ),
    ],
    zyklen: alleZyklen..sort((a, b) => b.compareTo(a)),
    gesamt: Duration(minutes: gesamt),
    erfassteTage: alleTage.length,
  );
}
