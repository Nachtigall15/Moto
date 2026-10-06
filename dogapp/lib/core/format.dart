import 'dart:math';

import 'package:intl/intl.dart';

/// Zeit-/Zahlformate an einer Stelle, damit die App überall gleich
/// aussieht (deutsches Format, 24-Stunden-Uhr).
final DateFormat dfDate = DateFormat('dd.MM.yyyy', 'de_DE');
final DateFormat dfTime = DateFormat('HH:mm', 'de_DE');
final DateFormat dfDateTime = DateFormat('dd.MM.yyyy, HH:mm', 'de_DE');
final DateFormat dfWeekday = DateFormat('EEEE, d. MMMM', 'de_DE');
final DateFormat dfShortDay = DateFormat('dd.MM.', 'de_DE');

final NumberFormat nfWeight = NumberFormat('#,##0.00', 'de_DE');
final NumberFormat nfAmount = NumberFormat('#,##0.#', 'de_DE');

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// Tagesgenauer Vergleich – für „heute"-Filter und Gruppierung.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Menschenlesbares Alter, z. B. „1 Jahr, 3 Monate, 2 Wochen".
///
/// Nullwerte fallen weg: Ein halbjähriger Welpe ist „5 Monate,
/// 2 Wochen", kein „0 Jahre, 5 Monate". Ist noch keine Woche vorbei,
/// bleiben die Tage stehen – in der Welpenzeit zählt jeder einzelne.
///
/// [kompakt] lässt die Wochen weg, wo nur wenig Platz ist.
String formatAge(DateTime birthday, {DateTime? now, bool kompakt = false}) {
  final ref = now ?? DateTime.now();
  var jahre = ref.year - birthday.year;
  var monate = ref.month - birthday.month;
  if (ref.day < birthday.day) monate--;
  if (monate < 0) {
    jahre--;
    monate += 12;
  }
  if (jahre < 0) return 'noch nicht geboren';

  // Tage seit dem letzten „Monatsgeburtstag" – daraus die Wochen. Über
  // den Umweg des Jubiläumsdatums, weil Monate unterschiedlich lang
  // sind und eine Rechnung mit 30 Tagen daneben läge.
  final jubilaeum = _plusMonate(birthday, jahre * 12 + monate);
  final tage = startOfDay(ref).difference(startOfDay(jubilaeum)).inDays;
  final wochen = tage ~/ 7;

  final teile = <String>[];
  if (jahre > 0) teile.add(jahre == 1 ? '1 Jahr' : '$jahre Jahre');
  if (monate > 0) teile.add(monate == 1 ? '1 Monat' : '$monate Monate');
  if (wochen > 0 && !kompakt) {
    teile.add(wochen == 1 ? '1 Woche' : '$wochen Wochen');
  }
  if (teile.isEmpty) {
    final seitGeburt = startOfDay(ref).difference(startOfDay(birthday)).inDays;
    return seitGeburt == 1 ? '1 Tag' : '$seitGeburt Tage';
  }
  return teile.join(', ');
}

/// Datum um [monate] Monate weiter, ohne in den Folgemonat zu rutschen:
/// Der 31. Januar plus einen Monat ist der 28. oder 29. Februar.
DateTime _plusMonate(DateTime d, int monate) {
  final gesamt = d.month - 1 + monate;
  final jahr = d.year + gesamt ~/ 12;
  final monat = gesamt % 12 + 1;
  final letzterTag = DateTime(jahr, monat + 1, 0).day;
  return DateTime(jahr, monat, d.day < letzterTag ? d.day : letzterTag);
}

final _rnd = Random();

/// Zeitsortierte ID: der Zeitstempel vorne sorgt dafür, dass IDs auch
/// ohne Server monoton wachsen; der Zufallsteil verhindert Kollisionen,
/// wenn zwei Geräte gleichzeitig offline etwas anlegen.
String newId() {
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rand = List.generate(6, (_) => _rnd.nextInt(36).toRadixString(36))
      .join();
  return '$ts-$rand';
}
