import 'package:dogapp/models/feeding_entry.dart';
import 'package:dogapp/models/geschaeft.dart';
import 'package:dogapp/state/stubenreinheit.dart';
import 'package:dogapp/state/verdauung.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fester Bezugspunkt: Freitag, 2. Oktober 2026, 12 Uhr.
  final jetzt = DateTime(2026, 10, 2, 12);
  DateTime tag(int vorTagen, int h, [int m = 0]) =>
      DateTime(2026, 10, 2 - vorTagen, h, m);

  FeedingEntry futter(DateTime t, {Mahlzeit m = Mahlzeit.fruehstueck}) =>
      FeedingEntry(zeitpunkt: t, futter: 'Trocken', menge: 100, mahlzeit: m);
  Geschaeft kakki(DateTime t) =>
      Geschaeft(zeitpunkt: t, art: Geschaeftsart.kaki);
  Geschaeft pipi(DateTime t) =>
      Geschaeft(zeitpunkt: t, art: Geschaeftsart.pipi);

  group('Nach dem Fressen', () {
    test('Median und Spanne aus dem ersten Kakki nach jeder Mahlzeit', () {
      final minuten = [20, 30, 35, 40, 60];
      final v = werteVerdauungAus(
        [for (var i = 1; i <= 5; i++) futter(tag(i, 7))],
        [
          for (var i = 1; i <= 5; i++) ...[
            kakki(tag(i, 7, minuten[i - 1])),
            // Ein zweites Kakki später zählt nicht mehr.
            kakki(tag(i, 9)),
          ],
        ],
        jetzt,
      );

      expect(v.kakki.mahlzeiten, 5);
      expect(v.kakki.typisch, const Duration(minutes: 35));
      expect(v.kakki.frueh, const Duration(minutes: 30));
      expect(v.kakki.spaet, const Duration(minutes: 40));
      expect(v.kakki.trefferquote, 1.0);
    });

    test('nach der nächsten Mahlzeit wird nichts mehr zugeordnet', () {
      final v = werteVerdauungAus(
        [futter(tag(1, 7)), futter(tag(1, 8), m: Mahlzeit.hauptmahlzeit)],
        [kakki(tag(1, 8, 20))],
        jetzt,
      );
      // Das Kakki gehört zur zweiten Mahlzeit, nicht zur ersten.
      expect(v.kakki.abstaende, [const Duration(minutes: 20)]);
      expect(v.kakki.mahlzeiten, 2);
    });

    test('dicht aufeinanderfolgende Fütterungen sind eine Mahlzeit', () {
      final v = werteVerdauungAus(
        [futter(tag(1, 7)), futter(tag(1, 7, 10))],
        [kakki(tag(1, 7, 40))],
        jetzt,
      );
      expect(v.kakki.mahlzeiten, 1);
      expect(v.kakki.abstaende, [const Duration(minutes: 40)]);
    });

    test('Leckerli zählen nicht als Mahlzeit', () {
      final v = werteVerdauungAus(
        [
          futter(tag(1, 7)),
          futter(tag(1, 7, 45), m: Mahlzeit.leckerli),
        ],
        [kakki(tag(1, 8))],
        jetzt,
      );
      expect(v.kakki.abstaende, [const Duration(hours: 1)]);
    });

    test('eine frische Mahlzeit ohne Kakki zählt noch nicht als Fehlschlag',
        () {
      final v = werteVerdauungAus(
        [
          for (var i = 1; i <= 3; i++) futter(tag(i, 7)),
          futter(tag(0, 11, 50)),
        ],
        [for (var i = 1; i <= 3; i++) kakki(tag(i, 7, 30))],
        jetzt,
      );
      expect(v.kakki.mahlzeiten, 3);

      // … aber sie erzeugt eine Erwartung.
      final e = v.erwartung!;
      expect(e.um, tag(0, 12, 20));
      expect(e.ab, tag(0, 12, 20));
    });

    test('nach erledigtem Kakki gibt es keine Erwartung mehr', () {
      final v = werteVerdauungAus(
        [
          for (var i = 1; i <= 3; i++) futter(tag(i, 7)),
          futter(tag(0, 11)),
        ],
        [
          for (var i = 1; i <= 3; i++) kakki(tag(i, 7, 30)),
          kakki(tag(0, 11, 30)),
        ],
        jetzt,
      );
      expect(v.erwartung, isNull);
    });

    test('mit zu wenigen Beispielen wird nichts behauptet', () {
      final v = werteVerdauungAus(
        [futter(tag(1, 7)), futter(tag(2, 7))],
        [kakki(tag(1, 7, 30)), kakki(tag(2, 7, 30))],
        jetzt,
      );
      expect(v.kakki.aussagekraeftig, isFalse);
      expect(v.kakki.typisch, isNull);
    });

    test('der nächste Gang nimmt die Uhr, die zuerst klingelt', () {
      final fuetterungen = [
        for (var i = 1; i <= 3; i++) futter(tag(i, 7)),
        futter(tag(0, 11, 50)),
      ];
      final geschaefte = [
        for (var i = 1; i <= 3; i++) kakki(tag(i, 7, 30)),
        // Pipi-Rhythmus: alle 2 h, zuletzt 11:00 → 13:00
        pipi(tag(0, 5)),
        pipi(tag(0, 7)),
        pipi(tag(0, 9)),
        pipi(tag(0, 11)),
      ];
      final gang = naechsterGang(
        stubenBilanz(geschaefte, jetzt),
        werteVerdauungAus(fuetterungen, geschaefte, jetzt),
      )!;
      expect(gang.zeit, tag(0, 12, 20));
      expect(gang.grund, 'Kakki nach dem Frühstück');
    });
  });

  group('Feste Zeiten', () {
    test('findet die Fenster, die an den meisten Tagen treffen', () {
      final geschaefte = [
        for (var i = 0; i < 6; i++) ...[
          pipi(tag(i, 7, i * 3)), // 07:00 – 07:15, jeden Tag
          kakki(tag(i, 7, 20)),
          if (i.isEven) pipi(tag(i, 12, 30)), // jeden zweiten Tag
          if (i < 2) pipi(tag(i, 18)), // nur an zwei Tagen
        ],
      ];
      final slots = findeZeitslots(geschaefte, jetzt);

      expect(slots, hasLength(2));
      expect(slots.first.von, 7 * 60);
      expect(slots.first.tage, 6);
      expect(slots.first.erfassteTage, 6);
      expect(slots.first.arten, 'Pipi + Kakki');
      expect(slots[1].label, '12:30');
      expect(slots[1].tage, 3);
      expect(slots[1].arten, 'Pipi');
    });

    test('mehrere Geschäfte an einem Vormittag sind noch keine feste Zeit', () {
      final geschaefte = [
        for (var m = 0; m < 50; m += 10) pipi(tag(0, 9, m)),
        pipi(tag(1, 15)),
        pipi(tag(2, 20)),
      ];
      expect(findeZeitslots(geschaefte, jetzt), isEmpty);
    });

    test('unter drei erfassten Tagen gibt es keine festen Zeiten', () {
      expect(
        findeZeitslots([pipi(tag(0, 7)), pipi(tag(1, 7))], jetzt),
        isEmpty,
      );
    });
  });
}
