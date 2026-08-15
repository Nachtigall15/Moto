import 'package:flutter/material.dart';

import '../core/format.dart';

/// Ein Termin im Kalender – Tierarzt, Hundeschule, Pflege, alles was
/// an einem festen Zeitpunkt hängt.
class Appointment {
  Appointment({
    String? id,
    required this.zeitpunkt,
    required this.titel,
    this.kategorie = TerminArt.tierarzt,
    this.dauerMinuten,
    this.ort = '',
    this.notiz = '',
    this.erledigt = false,
  }) : id = id ?? newId();

  final String id;
  final DateTime zeitpunkt;
  final String titel;
  final TerminArt kategorie;
  final int? dauerMinuten;
  final String ort;
  final String notiz;
  final bool erledigt;

  bool get istVergangen => zeitpunkt.isBefore(DateTime.now());

  DateTime? get ende => dauerMinuten == null
      ? null
      : zeitpunkt.add(Duration(minutes: dauerMinuten!));

  String get zeitLabel {
    final e = ende;
    if (e == null) return '${dfTime.format(zeitpunkt)} Uhr';
    return '${dfTime.format(zeitpunkt)} – ${dfTime.format(e)} Uhr';
  }

  Appointment copyWith({
    DateTime? zeitpunkt,
    String? titel,
    TerminArt? kategorie,
    int? dauerMinuten,
    bool clearDauer = false,
    String? ort,
    String? notiz,
    bool? erledigt,
  }) =>
      Appointment(
        id: id,
        zeitpunkt: zeitpunkt ?? this.zeitpunkt,
        titel: titel ?? this.titel,
        kategorie: kategorie ?? this.kategorie,
        dauerMinuten:
            clearDauer ? null : (dauerMinuten ?? this.dauerMinuten),
        ort: ort ?? this.ort,
        notiz: notiz ?? this.notiz,
        erledigt: erledigt ?? this.erledigt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'zeitpunkt': zeitpunkt.toIso8601String(),
        'titel': titel,
        'kategorie': kategorie.name,
        'dauerMinuten': dauerMinuten,
        'ort': ort,
        'notiz': notiz,
        'erledigt': erledigt,
      };

  static Appointment fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String?,
        zeitpunkt:
            DateTime.tryParse(json['zeitpunkt'] as String? ?? '') ??
                DateTime.now(),
        titel: json['titel'] as String? ?? '',
        kategorie: TerminArt.parse(json['kategorie'] as String?),
        dauerMinuten: (json['dauerMinuten'] as num?)?.toInt(),
        ort: json['ort'] as String? ?? '',
        notiz: json['notiz'] as String? ?? '',
        erledigt: json['erledigt'] as bool? ?? false,
      );
}

enum TerminArt {
  tierarzt('Tierarzt', Icons.local_hospital_outlined),
  impfung('Impfung', Icons.vaccines_outlined),
  medikament('Medikament', Icons.medication_outlined),
  hundeschule('Hundeschule', Icons.school_outlined),
  pflege('Pflege', Icons.content_cut),
  sonstiges('Sonstiges', Icons.event_outlined);

  const TerminArt(this.label, this.icon);

  final String label;
  final IconData icon;

  static TerminArt parse(String? raw) => TerminArt.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => TerminArt.sonstiges,
      );
}
