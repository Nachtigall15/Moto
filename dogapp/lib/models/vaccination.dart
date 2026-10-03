import '../core/format.dart';

/// Eine Impfung, wie sie auch im Heimtierausweis steht.
class Vaccination {
  Vaccination({
    String? id,
    required this.bezeichnung,
    required this.datum,
    this.gueltigBis,
    this.impfstoff = '',
    this.chargennummer = '',
    this.tierarzt = '',
    this.notiz = '',
    this.erinnerungErledigt = false,
  }) : id = id ?? newId();

  final String id;
  final String bezeichnung;
  final DateTime datum;
  final DateTime? gueltigBis;
  final String impfstoff;
  final String chargennummer;
  final String tierarzt;
  final String notiz;

  /// Die Erinnerung an die Auffrischung ist abgehakt.
  ///
  /// Ohne das blieben fällige Impfungen für immer im Kalender stehen:
  /// Der Termin ist gemacht, die Auffrischung erledigt oder bewusst
  /// verschoben – die Warnung bleibt trotzdem. Der Haken sagt „gesehen
  /// und geregelt" und lässt sich jederzeit wieder lösen.
  final bool erinnerungErledigt;

  /// Tage bis zur Auffrischung; negativ heißt überfällig.
  int? get tageBisFaellig => gueltigBis == null
      ? null
      : startOfDay(gueltigBis!).difference(startOfDay(DateTime.now())).inDays;

  bool get istAbgelaufen => (tageBisFaellig ?? 1) < 0;

  /// Ab acht Wochen vorher lohnt es sich, einen Termin zu machen.
  bool get wirdBaldFaellig {
    final tage = tageBisFaellig;
    return tage != null && tage >= 0 && tage <= 56;
  }

  Vaccination copyWith({
    String? bezeichnung,
    DateTime? datum,
    DateTime? gueltigBis,
    bool clearGueltigBis = false,
    String? impfstoff,
    String? chargennummer,
    String? tierarzt,
    String? notiz,
    bool? erinnerungErledigt,
  }) =>
      Vaccination(
        id: id,
        bezeichnung: bezeichnung ?? this.bezeichnung,
        datum: datum ?? this.datum,
        gueltigBis:
            clearGueltigBis ? null : (gueltigBis ?? this.gueltigBis),
        impfstoff: impfstoff ?? this.impfstoff,
        chargennummer: chargennummer ?? this.chargennummer,
        tierarzt: tierarzt ?? this.tierarzt,
        notiz: notiz ?? this.notiz,
        erinnerungErledigt: erinnerungErledigt ?? this.erinnerungErledigt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bezeichnung': bezeichnung,
        'datum': datum.toIso8601String(),
        'gueltigBis': gueltigBis?.toIso8601String(),
        'impfstoff': impfstoff,
        'chargennummer': chargennummer,
        'tierarzt': tierarzt,
        'notiz': notiz,
        'erinnerungErledigt': erinnerungErledigt,
      };

  static Vaccination fromJson(Map<String, dynamic> json) => Vaccination(
        id: json['id'] as String?,
        bezeichnung: json['bezeichnung'] as String? ?? '',
        datum: DateTime.tryParse(json['datum'] as String? ?? '') ??
            DateTime.now(),
        gueltigBis: DateTime.tryParse(json['gueltigBis'] as String? ?? ''),
        impfstoff: json['impfstoff'] as String? ?? '',
        chargennummer: json['chargennummer'] as String? ?? '',
        tierarzt: json['tierarzt'] as String? ?? '',
        notiz: json['notiz'] as String? ?? '',
        erinnerungErledigt: json['erinnerungErledigt'] as bool? ?? false,
      );

  /// Übliche Hundeimpfungen als Auswahl – mit dem Intervall, das in
  /// Deutschland gängig ist. Die Vorgabe ist nur ein Vorschlag; das
  /// tatsächliche Datum steht im Impfausweis und ist änderbar.
  static const List<(String bezeichnung, int monate)> standards = [
    ('Tollwut', 36),
    ('Staupe (S)', 36),
    ('Hepatitis / H.c.c. (H)', 36),
    ('Parvovirose (P)', 36),
    ('Leptospirose (L)', 12),
    ('Zwingerhusten (Bordetella/Pi)', 12),
    ('Borreliose', 12),
  ];
}
