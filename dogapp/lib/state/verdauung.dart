import '../core/format.dart';
import '../models/feeding_entry.dart';
import '../models/geschaeft.dart';
import 'analyse.dart' show uhrzeitLabel;
import 'stubenreinheit.dart';

/// Fütterung und Geschäfte zusammen ausgewertet: Wie lange nach dem
/// Fressen muss er raus, und zu welchen Uhrzeiten muss er regelmäßig?
///
/// Reine Rechenarbeit ohne Oberfläche, damit sie sich einzeln prüfen
/// lässt. Gerechnet wird mit den letzten [verdauungTage] Tagen – ein
/// Welpe ändert seinen Rhythmus schnell, was vor einem Monat galt,
/// stimmt heute nicht mehr.

const int verdauungTage = 14;

/// Später als das gilt ein Geschäft nicht mehr als Folge der Mahlzeit.
const Duration nachFutterFenster = Duration(hours: 4);

/// Fütterungen, die so dicht beieinanderliegen, sind eine Mahlzeit –
/// etwa Trockenfutter und gleich danach noch etwas obendrauf.
const Duration mahlzeitZusammen = Duration(minutes: 30);

/// Ab so vielen Beispielen wird gerechnet – darunter ist es Zufall.
const int mindestBeispiele = 3;

/// Wie lange nach einer Mahlzeit ein Geschäft kommt.
class NachFutter {
  NachFutter({
    required this.art,
    required this.abstaende,
    required this.mahlzeiten,
  });

  final Geschaeftsart art;

  /// Gefundene Abstände, kürzester zuerst.
  final List<Duration> abstaende;

  /// Mahlzeiten, deren Fenster abgeschlossen ist – die Grundgesamtheit.
  final int mahlzeiten;

  bool get aussagekraeftig => abstaende.length >= mindestBeispiele;

  Duration? _quantil(double p) =>
      aussagekraeftig ? abstaende[((abstaende.length - 1) * p).round()] : null;

  /// Typischer Abstand (Median).
  Duration? get typisch => _quantil(0.5);

  /// Die mittlere Hälfte der Fälle liegt zwischen [frueh] und [spaet].
  Duration? get frueh => _quantil(0.25);
  Duration? get spaet => _quantil(0.75);

  /// Bei wie vielen Mahlzeiten danach überhaupt etwas kam.
  double? get trefferquote =>
      mahlzeiten == 0 ? null : abstaende.length / mahlzeiten;
}

/// Die jüngste Mahlzeit, nach der das Geschäft noch aussteht.
class Erwartung {
  Erwartung({
    required this.mahlzeit,
    required this.art,
    required this.ab,
    required this.um,
    required this.bis,
  });

  final FeedingEntry mahlzeit;
  final Geschaeftsart art;

  /// Frühester üblicher Zeitpunkt – ab hier lohnt es sich rauszugehen.
  final DateTime ab;

  /// Typischer Zeitpunkt.
  final DateTime um;

  /// Spätester üblicher Zeitpunkt.
  final DateTime bis;
}

class Verdauung {
  Verdauung({
    required this.kakki,
    required this.pipi,
    required this.erwartung,
  });

  final NachFutter kakki;
  final NachFutter pipi;

  /// Kakki nach der letzten Mahlzeit, solange es noch aussteht.
  final Erwartung? erwartung;

  NachFutter fuer(Geschaeftsart art) =>
      art == Geschaeftsart.kaki ? kakki : pipi;
}

/// Mahlzeiten zählen, Leckerli nicht: Die fallen beim Training an und
/// würden jede Mahlzeit in viele kleine zerlegen.
bool _zaehlt(FeedingEntry f) => f.mahlzeit != Mahlzeit.leckerli;

Verdauung werteVerdauungAus(
  Iterable<FeedingEntry> fuetterungen,
  Iterable<Geschaeft> geschaefte,
  DateTime jetzt,
) {
  final seit = DateTime(jetzt.year, jetzt.month, jetzt.day - verdauungTage);

  // Dicht aufeinanderfolgende Fütterungen zu einer Mahlzeit bündeln;
  // es zählt der Beginn.
  final roh = [
    for (final f in fuetterungen)
      if (_zaehlt(f) && !f.zeitpunkt.isBefore(seit)) f,
  ]..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));
  final mahlzeiten = <FeedingEntry>[];
  for (final f in roh) {
    if (mahlzeiten.isNotEmpty &&
        f.zeitpunkt.difference(mahlzeiten.last.zeitpunkt) < mahlzeitZusammen) {
      continue;
    }
    mahlzeiten.add(f);
  }

  final sortiert = [...geschaefte]
    ..sort((a, b) => a.zeitpunkt.compareTo(b.zeitpunkt));

  /// Erstes Geschäft dieser Art nach der Mahlzeit – aber vor der
  /// nächsten. Was danach kommt, lässt sich keiner Mahlzeit mehr
  /// sicher zuordnen.
  Geschaeft? erstesNach(int i, Geschaeftsart art) {
    final start = mahlzeiten[i].zeitpunkt;
    var ende = start.add(nachFutterFenster);
    if (i + 1 < mahlzeiten.length &&
        mahlzeiten[i + 1].zeitpunkt.isBefore(ende)) {
      ende = mahlzeiten[i + 1].zeitpunkt;
    }
    for (final g in sortiert) {
      if (g.art != art || !g.zeitpunkt.isAfter(start)) continue;
      return g.zeitpunkt.isBefore(ende) ? g : null;
    }
    return null;
  }

  NachFutter auswerten(Geschaeftsart art) {
    final abstaende = <Duration>[];
    var gezaehlt = 0;
    for (var i = 0; i < mahlzeiten.length; i++) {
      final treffer = erstesNach(i, art);
      if (treffer != null) {
        abstaende.add(treffer.zeitpunkt.difference(mahlzeiten[i].zeitpunkt));
        gezaehlt++;
        continue;
      }
      // Ein Fenster, das noch offen ist, zählt erst, wenn es vorbei ist –
      // sonst sähe jede frische Mahlzeit wie eine ohne Geschäft aus.
      final fensterZu = i + 1 < mahlzeiten.length ||
          !mahlzeiten[i].zeitpunkt.add(nachFutterFenster).isAfter(jetzt);
      if (fensterZu) gezaehlt++;
    }
    abstaende.sort();
    return NachFutter(art: art, abstaende: abstaende, mahlzeiten: gezaehlt);
  }

  final kakki = auswerten(Geschaeftsart.kaki);
  final pipi = auswerten(Geschaeftsart.pipi);

  Erwartung? erwartung;
  if (mahlzeiten.isNotEmpty && kakki.aussagekraeftig) {
    final letzte = mahlzeiten.last;
    final offen = letzte.zeitpunkt.add(nachFutterFenster).isAfter(jetzt);
    if (offen &&
        erstesNach(mahlzeiten.length - 1, Geschaeftsart.kaki) == null) {
      erwartung = Erwartung(
        mahlzeit: letzte,
        art: Geschaeftsart.kaki,
        ab: letzte.zeitpunkt.add(kakki.frueh!),
        um: letzte.zeitpunkt.add(kakki.typisch!),
        bis: letzte.zeitpunkt.add(kakki.spaet!),
      );
    }
  }

  return Verdauung(kakki: kakki, pipi: pipi, erwartung: erwartung);
}

/// Wann er als Nächstes raus muss – und warum.
///
/// Zwei Uhren laufen nebeneinander: der Pipi-Rhythmus und die
/// Verdauung nach der letzten Mahlzeit. Es gilt die, die zuerst
/// klingelt; für Kakki zählt schon der früheste übliche Zeitpunkt,
/// lieber eine Minute zu früh draußen als eine zu spät drinnen.
({DateTime zeit, String grund})? naechsterGang(
  Stubenbilanz bilanz,
  Verdauung verdauung,
) {
  final rhythmus = bilanz.naechsterGang;
  final kakki = verdauung.erwartung;
  if (kakki != null && (rhythmus == null || kakki.ab.isBefore(rhythmus))) {
    return (
      zeit: kakki.ab,
      grund: 'Kakki nach ${nachDer(kakki.mahlzeit.mahlzeit)}',
    );
  }
  if (rhythmus != null) {
    return (
      zeit: rhythmus,
      grund: 'alle ${formatDuration(bilanz.pipiAbstand!)}',
    );
  }
  return null;
}

/// „dem Frühstück", „der Hauptmahlzeit" …
String nachDer(Mahlzeit m) => switch (m) {
      Mahlzeit.hauptmahlzeit => 'der Hauptmahlzeit',
      _ => 'dem ${m.label}',
    };

// --- Feste Zeiten ------------------------------------------------------

/// Breite eines Zeitfensters in Minuten.
const int slotBreite = 60;

/// Schrittweite, in der die Fenster über den Tag geschoben werden.
const int _slotSchritt = 15;

/// An mindestens diesem Anteil der erfassten Tage muss er im Fenster
/// raus gewesen sein, damit es als feste Zeit gilt.
const double slotMindestanteil = 0.5;

/// Eine Uhrzeit, zu der er regelmäßig raus muss.
class Zeitslot {
  Zeitslot({
    required this.von,
    required this.bis,
    required this.typisch,
    required this.tage,
    required this.erfassteTage,
    required this.pipiTage,
    required this.kakkiTage,
  });

  /// Minuten seit Mitternacht: frühestes und spätestes Geschäft im
  /// Fenster, dazu der Median.
  final int von;
  final int bis;
  final int typisch;

  /// An wie vielen Tagen er in diesem Fenster musste.
  final int tage;
  final int erfassteTage;
  final int pipiTage;
  final int kakkiTage;

  double get anteil => tage / erfassteTage;

  String get label => von == bis
      ? uhrzeitLabel(von)
      : '${uhrzeitLabel(von)} – ${uhrzeitLabel(bis)}';

  /// „Pipi + Kakki", „Pipi" oder „Kakki" – je nachdem, was an
  /// mindestens der Hälfte dieser Tage dabei war.
  String get arten {
    final teile = [
      if (pipiTage * 2 >= tage) 'Pipi',
      if (kakkiTage * 2 >= tage) 'Kakki',
    ];
    return teile.isEmpty ? 'mal so, mal so' : teile.join(' + ');
  }
}

/// Sucht die Uhrzeiten, zu denen er an den meisten Tagen raus musste.
///
/// Ein Fenster von einer Stunde wird in Viertelstunden-Schritten über
/// den Tag geschoben. Das Fenster, das an den meisten Tagen etwas
/// enthält, wird zur festen Zeit; seine Geschäfte scheiden aus, dann
/// beginnt die Suche von vorn. Schluss ist, sobald kein Fenster mehr
/// an mindestens der Hälfte der Tage trifft.
///
/// Gezählt werden Tage, nicht Geschäfte: Dreimal Pipi an einem
/// Vormittag macht noch keine feste Zeit.
List<Zeitslot> findeZeitslots(Iterable<Geschaeft> geschaefte, DateTime jetzt) {
  final seit = DateTime(jetzt.year, jetzt.month, jetzt.day - verdauungTage);
  final rest = [
    for (final g in geschaefte)
      if (!g.zeitpunkt.isBefore(seit)) g,
  ];
  final erfassteTage = {for (final g in rest) startOfDay(g.zeitpunkt)}.length;
  if (erfassteTage < mindestBeispiele) return const [];

  final mindestTage =
      (erfassteTage * slotMindestanteil).ceil() < mindestBeispiele
          ? mindestBeispiele
          : (erfassteTage * slotMindestanteil).ceil();

  int minute(Geschaeft g) => g.zeitpunkt.hour * 60 + g.zeitpunkt.minute;

  final slots = <Zeitslot>[];
  while (true) {
    var besterStart = -1;
    var besteTage = 0;
    for (var s = 0; s + slotBreite <= 24 * 60; s += _slotSchritt) {
      final tage = {
        for (final g in rest)
          if (minute(g) >= s && minute(g) < s + slotBreite)
            startOfDay(g.zeitpunkt),
      }.length;
      if (tage > besteTage) {
        besteTage = tage;
        besterStart = s;
      }
    }
    if (besteTage < mindestTage) break;

    final drin = [
      for (final g in rest)
        if (minute(g) >= besterStart && minute(g) < besterStart + slotBreite) g,
    ];
    final minuten = drin.map(minute).toList()..sort();
    Set<DateTime> tageMit(Geschaeftsart art) => {
          for (final g in drin)
            if (g.art == art) startOfDay(g.zeitpunkt),
        };

    slots.add(Zeitslot(
      von: minuten.first,
      bis: minuten.last,
      typisch: minuten[minuten.length ~/ 2],
      tage: besteTage,
      erfassteTage: erfassteTage,
      pipiTage: tageMit(Geschaeftsart.pipi).length,
      kakkiTage: tageMit(Geschaeftsart.kaki).length,
    ));
    rest.removeWhere(drin.contains);
  }

  return slots..sort((a, b) => a.von.compareTo(b.von));
}
