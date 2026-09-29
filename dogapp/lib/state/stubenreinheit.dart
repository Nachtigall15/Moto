import '../core/format.dart';
import '../models/geschaeft.dart';

/// Auswertung der Stubenreinheit – reine Rechenarbeit ohne Oberfläche,
/// damit sie sich einzeln prüfen lässt.
///
/// Wie die übrige Analyse rechnet sie nur mit dem, was gerade geladen
/// ist. Für die Trainingsübersicht zählen ohnehin nur die letzten zwei
/// Wochen, und die liegen immer im geladenen Ausschnitt.

/// Ein Tag in Zahlen.
class StubenTag {
  const StubenTag({
    this.pipi = 0,
    this.kaki = 0,
    this.draussen = 0,
    this.drinnen = 0,
    this.gemeldet = 0,
  });

  final int pipi;
  final int kaki;
  final int draussen;
  final int drinnen;
  final int gemeldet;

  int get gesamt => draussen + drinnen;

  /// Anteil draußen, 0 bis 1 – null, wenn nichts erfasst ist. Ein Tag
  /// ohne Eintrag ist kein Tag mit 0 %, sondern einer ohne Aufzeichnung.
  double? get quote => gesamt == 0 ? null : draussen / gesamt;

  /// „4× Pipi · 2× Kaki"
  String get zusammenfassung => [
        if (pipi > 0) '$pipi× Pipi',
        if (kaki > 0) '$kaki× Kaki',
      ].join(' · ');
}

StubenTag stubenTag(Iterable<Geschaeft> eintraege) {
  var pipi = 0, kaki = 0, draussen = 0, drinnen = 0, gemeldet = 0;
  for (final g in eintraege) {
    if (g.art == Geschaeftsart.pipi) {
      pipi++;
    } else {
      kaki++;
    }
    if (g.draussen) {
      draussen++;
    } else {
      drinnen++;
    }
    if (g.gemeldet) gemeldet++;
  }
  return StubenTag(
    pipi: pipi,
    kaki: kaki,
    draussen: draussen,
    drinnen: drinnen,
    gemeldet: gemeldet,
  );
}

/// Quote als „85 %" – oder „–", wenn es nichts zu rechnen gibt.
String quoteLabel(double? quote) =>
    quote == null ? '–' : '${(quote * 100).round()} %';

/// Längere Pausen zwischen zwei Pipis gelten als Nachtruhe und zählen
/// nicht zum Rhythmus. Sonst zöge jede Nacht den Schnitt nach oben,
/// und die Vorhersage für den Tag läge Stunden daneben.
const Duration nachtruhe = Duration(hours: 6);

/// Wie viele Tage die Trainingsübersicht zeigt.
const int bilanzTage = 7;

/// Alles, was die Trainingsübersicht braucht, auf einmal gerechnet.
class Stubenbilanz {
  Stubenbilanz({
    required this.tage,
    required this.woche,
    required this.vorwoche,
    required this.letztesPipi,
    required this.letztesKaki,
    required this.letztesMissgeschick,
    required this.pipiAbstand,
    required this.missgeschickStunden,
  });

  /// Die letzten [bilanzTage] Tage, heute zuerst.
  final List<(DateTime, StubenTag)> tage;

  /// Summe der letzten sieben Tage und der sieben davor – für die
  /// Frage, ob es besser wird.
  final StubenTag woche;
  final StubenTag vorwoche;

  final Geschaeft? letztesPipi;
  final Geschaeft? letztesKaki;
  final Geschaeft? letztesMissgeschick;

  /// Typischer Abstand zwischen zwei Pipis tagsüber (Median), null
  /// bei zu wenigen Daten.
  final Duration? pipiAbstand;

  /// Stunden des Tages, in denen es drinnen passiert ist, häufigste
  /// zuerst: (Stunde, Anzahl). Zeigt, wann man besonders aufpassen
  /// muss – meist nach dem Schlafen, Fressen oder Toben.
  final List<(int, int)> missgeschickStunden;

  /// Wann der nächste Gang fällig ist: letztes Pipi plus der übliche
  /// Abstand. Ohne Rhythmus keine Vorhersage.
  DateTime? get naechsterGang {
    final letztes = letztesPipi;
    final abstand = pipiAbstand;
    if (letztes == null || abstand == null) return null;
    return letztes.zeitpunkt.add(abstand);
  }

  /// Ganze Tage ohne Missgeschick – heute zählt erst, wenn er vorbei
  /// ist. Null, wenn es noch nie eins gab.
  int? tageOhneMissgeschick(DateTime jetzt) {
    final m = letztesMissgeschick;
    if (m == null) return null;
    return startOfDay(jetzt).difference(startOfDay(m.zeitpunkt)).inDays;
  }
}

/// [alle] in beliebiger Reihenfolge.
Stubenbilanz stubenBilanz(List<Geschaeft> alle, DateTime jetzt) {
  final heute = startOfDay(jetzt);
  // Über das Datum gerechnet, nicht über 24-Stunden-Schritte – an den
  // Tagen der Zeitumstellung läge man sonst eine Stunde daneben.
  DateTime tagZurueck(int n) =>
      DateTime(heute.year, heute.month, heute.day - n);

  final nachTag = <DateTime, List<Geschaeft>>{};
  for (final g in alle) {
    nachTag.putIfAbsent(startOfDay(g.zeitpunkt), () => []).add(g);
  }

  StubenTag spanne(int vonTagen, int bisTagen) => stubenTag([
        for (var i = vonTagen; i < bisTagen; i++) ...?nachTag[tagZurueck(i)],
      ]);

  final sortiert = [...alle]
    ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
  Geschaeft? juengstes(bool Function(Geschaeft) passt) {
    for (final g in sortiert.reversed) {
      if (passt(g)) return g;
    }
    return null;
  }

  // Rhythmus aus den letzten zwei Wochen: Welpen werden schnell
  // größer, was vor einem Monat galt, stimmt heute nicht mehr.
  final seit = tagZurueck(2 * bilanzTage - 1);
  final pipis = [
    for (final g in sortiert)
      if (g.art == Geschaeftsart.pipi && !g.zeitpunkt.isBefore(seit)) g,
  ];
  final abstaende = <Duration>[
    for (var i = 1; i < pipis.length; i++)
      pipis[i].zeitpunkt.difference(pipis[i - 1].zeitpunkt),
  ].where((d) => d > Duration.zero && d < nachtruhe).toList()
    ..sort();

  final stunden = <int, int>{};
  for (final g in alle) {
    if (!g.draussen && !g.zeitpunkt.isBefore(seit)) {
      stunden.update(g.zeitpunkt.hour, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final missgeschickStunden = [
    for (final e in stunden.entries) (e.key, e.value),
  ]..sort((a, b) {
      final n = b.$2.compareTo(a.$2);
      return n != 0 ? n : a.$1.compareTo(b.$1);
    });

  return Stubenbilanz(
    tage: [
      for (var i = 0; i < bilanzTage; i++)
        (tagZurueck(i), stubenTag(nachTag[tagZurueck(i)] ?? const [])),
    ],
    woche: spanne(0, bilanzTage),
    vorwoche: spanne(bilanzTage, 2 * bilanzTage),
    letztesPipi: juengstes((g) => g.art == Geschaeftsart.pipi),
    letztesKaki: juengstes((g) => g.art == Geschaeftsart.kaki),
    letztesMissgeschick: juengstes((g) => !g.draussen),
    // Mindestens drei Abstände, sonst ist es Zufall und kein Rhythmus.
    pipiAbstand: abstaende.length < 3 ? null : abstaende[abstaende.length ~/ 2],
    missgeschickStunden: missgeschickStunden,
  );
}
