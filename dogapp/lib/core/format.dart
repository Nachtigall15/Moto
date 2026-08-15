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

/// Menschenlesbares Alter, z. B. „1 Jahr, 3 Monate".
String formatAge(DateTime birthday, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  var years = ref.year - birthday.year;
  var months = ref.month - birthday.month;
  if (ref.day < birthday.day) months--;
  if (months < 0) {
    years--;
    months += 12;
  }
  if (years < 0) return 'noch nicht geboren';
  if (years == 0 && months == 0) {
    final days = ref.difference(birthday).inDays;
    return '$days Tage';
  }
  final parts = <String>[];
  if (years > 0) parts.add(years == 1 ? '1 Jahr' : '$years Jahre');
  if (months > 0) parts.add(months == 1 ? '1 Monat' : '$months Monate');
  return parts.join(', ');
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
