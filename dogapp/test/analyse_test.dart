import 'package:dogapp/models/feeding_entry.dart';
import 'package:dogapp/models/sleep_entry.dart';
import 'package:dogapp/state/analyse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fester Bezugspunkt: Montag, 3. August 2026, 12:00.
  final jetzt = DateTime(2026, 8, 3, 12);
  DateTime tag(int tagImAugust, [int stunde = 0, int minute = 0]) =>
      DateTime(2026, 8, tagImAugust, stunde, minute);

  FeedingEntry mahlzeit(
    DateTime zeitpunkt, {
    double menge = 150,
    Einheit einheit = Einheit.gramm,
    Mahlzeit art = Mahlzeit.fruehstueck,
  }) =>
      FeedingEntry(
        zeitpunkt: zeitpunkt,
        futter: 'Trockenfutter',
        menge: menge,
        einheit: einheit,
        mahlzeit: art,
      );

  group('Fütterungszeiten', () {
    test('Uhrzeiten landen beim richtigen Wochentag', () {
      final analyse = werteFutterAus(
        [
          // Montag, 3. August
          mahlzeit(tag(3, 7, 15)),
          mahlzeit(tag(3, 18, 0), art: Mahlzeit.abendessen),
          // Sonntag, 2. August
          mahlzeit(tag(2, 8, 30)),
        ],
        zeitraum: Zeitraum.woche,
        jetzt: jetzt,
      );

      final montag = analyse.wochentage[DateTime.monday - 1];
      expect(montag.kurz, 'Mo');
      expect(montag.zeiten, [7 * 60 + 15, 18 * 60]);
      expect(montag.erfassteTage, 1);
      expect(montag.mahlzeitenProTag, 2);

      final sonntag = analyse.wochentage[DateTime.sunday - 1];
      expect(sonntag.zeiten, [8 * 60 + 30]);

      // Tage ohne Eintrag stehen leer da, statt zu fehlen.
      expect(analyse.wochentage, hasLength(7));
      expect(analyse.wochentage[DateTime.wednesday - 1].anzahl, 0);
      expect(analyse.wochentage[DateTime.wednesday - 1].mahlzeitenProTag, 0);
    });

    test('Leckerli zählen nicht als Mahlzeit', () {
      final analyse = werteFutterAus(
        [
          mahlzeit(tag(3, 7, 0)),
          mahlzeit(tag(3, 15, 0),
              menge: 2, einheit: Einheit.stueck, art: Mahlzeit.leckerli),
        ],
        zeitraum: Zeitraum.woche,
        jetzt: jetzt,
      );

      expect(analyse.anzahl, 1);
      expect(analyse.menge[Einheit.stueck], isNull);
      expect(analyse.menge[Einheit.gramm], 150);
    });

    test('der Zeitraum schneidet Älteres ab', () {
      final eintraege = [
        mahlzeit(tag(3, 7, 0)),
        mahlzeit(tag(1, 7, 0)), // Samstag, 1. August
        mahlzeit(DateTime(2026, 7, 1, 7, 0)), // gut einen Monat her
      ];

      expect(
        werteFutterAus(eintraege, zeitraum: Zeitraum.woche, jetzt: jetzt)
            .anzahl,
        2,
      );
      expect(
        werteFutterAus(eintraege, zeitraum: Zeitraum.alles, jetzt: jetzt)
            .anzahl,
        3,
      );
      // Genau am Rand: Sieben Tage schließen den heutigen Tag mit ein,
      // reichen also bis zum 28. Juli.
      expect(Zeitraum.woche.ab(jetzt), DateTime(2026, 7, 28));
      expect(Zeitraum.alles.ab(jetzt), isNull);
    });

    test('nahe beieinanderliegende Zeiten werden zusammengefasst', () {
      final analyse = werteFutterAus(
        [
          mahlzeit(tag(1, 7, 0)),
          mahlzeit(tag(2, 7, 20)),
          mahlzeit(tag(3, 6, 50)),
          mahlzeit(tag(1, 18, 0), art: Mahlzeit.abendessen),
          mahlzeit(tag(2, 18, 30), art: Mahlzeit.abendessen),
        ],
        zeitraum: Zeitraum.woche,
        jetzt: jetzt,
      );

      expect(analyse.typischeZeiten, hasLength(2));
      // Häufigstes Fenster zuerst: dreimal morgens.
      expect(analyse.typischeZeiten.first.anzahl, 3);
      expect(uhrzeitLabel(analyse.typischeZeiten.first.mittel), '07:00');
      expect(analyse.typischeZeiten.first.label, '06:50 – 07:20');
      expect(analyse.typischeZeiten.last.anzahl, 2);
      expect(uhrzeitLabel(analyse.typischeZeiten.last.mittel), '18:30');
    });

    test('ohne Fütterungen bleibt die Auswertung leer', () {
      final analyse =
          werteFutterAus(const [], zeitraum: Zeitraum.monat, jetzt: jetzt);
      expect(analyse.leer, isTrue);
      expect(analyse.wochentage, hasLength(7));
      expect(analyse.typischeZeiten, isEmpty);
      expect(analyse.mahlzeitenProTag, 0);
    });
  });

  group('Schlafauswertung', () {
    test('Dauer je Wochentag, Zyklus am Tag seines Beginns', () {
      // Nacht von Sonntag 22:00 bis Montag 6:00 – acht Stunden am
      // Stück, aufgeteilt auf zwei Tage.
      final analyse = werteSchlafAus(
        [
          SleepEntry(start: tag(2, 22, 0), ende: tag(3, 6, 0)),
          SleepEntry(start: tag(3, 13, 0), ende: tag(3, 14, 30)),
        ],
        zeitraum: Zeitraum.woche,
        jetzt: jetzt,
      );

      final sonntag = analyse.wochentage[DateTime.sunday - 1];
      final montag = analyse.wochentage[DateTime.monday - 1];

      // Die Nacht zählt anteilig auf beide Tage …
      expect(sonntag.gesamt, const Duration(hours: 2));
      expect(montag.gesamt, const Duration(hours: 7, minutes: 30));

      // … als Zyklus gehört sie aber ungeteilt zum Sonntag.
      expect(sonntag.zyklen, [const Duration(hours: 8)]);
      expect(montag.zyklen, [const Duration(hours: 1, minutes: 30)]);

      expect(analyse.gesamt, const Duration(hours: 9, minutes: 30));
      expect(analyse.laengsterZyklus, const Duration(hours: 8));
      expect(analyse.zyklusSchnitt, const Duration(hours: 4, minutes: 45));
    });

    test('das Stundenraster verteilt die Minuten auf die Stunden', () {
      final analyse = werteSchlafAus(
        [SleepEntry(start: tag(3, 13, 30), ende: tag(3, 15, 0))],
        zeitraum: Zeitraum.woche,
        jetzt: jetzt,
      );

      final montag = analyse.wochentage[DateTime.monday - 1];
      expect(montag.minutenJeStunde[12], 0);
      expect(montag.minutenJeStunde[13], 30);
      expect(montag.minutenJeStunde[14], 60);
      expect(montag.minutenJeStunde[15], 0);
      expect(analyse.stundenSpitze, 60);
    });

    test('eine laufende Phase zählt nicht mit', () {
      final analyse = werteSchlafAus(
        [
          SleepEntry(start: tag(3, 9, 0), ende: tag(3, 10, 0)),
          SleepEntry(start: tag(3, 11, 0)),
        ],
        zeitraum: Zeitraum.woche,
        jetzt: jetzt,
      );

      expect(analyse.gesamt, const Duration(hours: 1));
      expect(analyse.zyklen, [const Duration(hours: 1)]);
    });

    test('Zyklen fallen in ihre Größenklasse', () {
      final analyse = werteSchlafAus(
        [
          SleepEntry(start: tag(3, 8, 0), ende: tag(3, 8, 20)), // 20 min
          SleepEntry(start: tag(3, 9, 0), ende: tag(3, 9, 45)), // 45 min
          SleepEntry(start: tag(3, 10, 0), ende: tag(3, 11, 30)), // 1,5 h
          SleepEntry(start: tag(2, 20, 0), ende: tag(3, 1, 0)), // 5 h
        ],
        zeitraum: Zeitraum.woche,
        jetzt: jetzt,
      );

      // bis 30 min · 30–60 min · 1–2 h · 2–4 h · über 4 h
      expect(analyse.klassenVerteilung, [1, 1, 1, 0, 1]);
      expect(zyklusklassen, hasLength(5));
    });

    test('Mittelwerte beziehen sich auf erfasste Tage', () {
      final analyse = werteSchlafAus(
        [
          SleepEntry(start: tag(3, 9, 0), ende: tag(3, 11, 0)),
          // Nächster Montag gibt es im Zeitraum nicht – geteilt wird
          // also durch einen Tag, nicht durch sieben.
        ],
        zeitraum: Zeitraum.monat,
        jetzt: jetzt,
      );

      final montag = analyse.wochentage[DateTime.monday - 1];
      expect(montag.erfassteTage, 1);
      expect(montag.proTag, const Duration(hours: 2));
      expect(analyse.proTag, const Duration(hours: 2));
      expect(analyse.zyklenProTag, 1);
    });

    test('ohne Schlafdaten bleibt die Auswertung leer', () {
      final analyse =
          werteSchlafAus(const [], zeitraum: Zeitraum.monat, jetzt: jetzt);
      expect(analyse.leer, isTrue);
      expect(analyse.wochentage, hasLength(7));
      expect(analyse.stundenSpitze, 0);
      expect(analyse.proTag, Duration.zero);
    });
  });
}
