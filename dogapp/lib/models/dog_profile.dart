/// Stammdaten des Hundes – inhaltlich am EU-Heimtierausweis
/// orientiert (Abschnitte: Tierhalter, Beschreibung des Tieres,
/// Kennzeichnung/Transponder, behandelnder Tierarzt).
class DogProfile {
  const DogProfile({
    this.name = '',
    this.rasse = '',
    this.geschlecht = Geschlecht.unbekannt,
    this.kastriert = false,
    this.geburtsdatum,
    this.fellfarbe = '',
    this.besondereKennzeichen = '',
    this.zielgewichtKg,
    this.zielgroesseCm,
    // Kennzeichnung
    this.chipNummer = '',
    this.chipDatum,
    this.chipStelle = '',
    this.taetowierung = '',
    // Ausweis
    this.passNummer = '',
    this.passAusstellendeStelle = '',
    this.passAusstellungsdatum,
    // Halter
    this.halterName = '',
    this.halterAnschrift = '',
    this.halterTelefon = '',
    // Tierarzt
    this.tierarztPraxis = '',
    this.tierarztName = '',
    this.tierarztAnschrift = '',
    this.tierarztTelefon = '',
    this.tierarztNotfallTelefon = '',
    this.tierarztEmail = '',
    this.tierarztSprechzeiten = '',
    this.notizen = '',
  });

  final String name;
  final String rasse;
  final Geschlecht geschlecht;
  final bool kastriert;
  final DateTime? geburtsdatum;
  final String fellfarbe;
  final String besondereKennzeichen;

  /// Optionales Zielgewicht – wird im Verlauf als Linie eingezeichnet.
  final double? zielgewichtKg;

  /// Erwartete Widerristhöhe im ausgewachsenen Zustand. Bei einer
  /// Rasse mit bekanntem Standard eine gute Orientierung, ob die
  /// Entwicklung im Rahmen liegt.
  final double? zielgroesseCm;

  final String chipNummer;
  final DateTime? chipDatum;
  final String chipStelle;
  final String taetowierung;

  final String passNummer;
  final String passAusstellendeStelle;
  final DateTime? passAusstellungsdatum;

  final String halterName;
  final String halterAnschrift;
  final String halterTelefon;

  final String tierarztPraxis;
  final String tierarztName;
  final String tierarztAnschrift;
  final String tierarztTelefon;
  final String tierarztNotfallTelefon;
  final String tierarztEmail;
  final String tierarztSprechzeiten;

  final String notizen;

  bool get isEmpty => name.trim().isEmpty;

  DogProfile copyWith({
    String? name,
    String? rasse,
    Geschlecht? geschlecht,
    bool? kastriert,
    DateTime? geburtsdatum,
    bool clearGeburtsdatum = false,
    String? fellfarbe,
    String? besondereKennzeichen,
    double? zielgewichtKg,
    bool clearZielgewicht = false,
    double? zielgroesseCm,
    bool clearZielgroesse = false,
    String? chipNummer,
    DateTime? chipDatum,
    bool clearChipDatum = false,
    String? chipStelle,
    String? taetowierung,
    String? passNummer,
    String? passAusstellendeStelle,
    DateTime? passAusstellungsdatum,
    bool clearPassAusstellungsdatum = false,
    String? halterName,
    String? halterAnschrift,
    String? halterTelefon,
    String? tierarztPraxis,
    String? tierarztName,
    String? tierarztAnschrift,
    String? tierarztTelefon,
    String? tierarztNotfallTelefon,
    String? tierarztEmail,
    String? tierarztSprechzeiten,
    String? notizen,
  }) {
    return DogProfile(
      name: name ?? this.name,
      rasse: rasse ?? this.rasse,
      geschlecht: geschlecht ?? this.geschlecht,
      kastriert: kastriert ?? this.kastriert,
      geburtsdatum:
          clearGeburtsdatum ? null : (geburtsdatum ?? this.geburtsdatum),
      fellfarbe: fellfarbe ?? this.fellfarbe,
      besondereKennzeichen: besondereKennzeichen ?? this.besondereKennzeichen,
      zielgewichtKg:
          clearZielgewicht ? null : (zielgewichtKg ?? this.zielgewichtKg),
      zielgroesseCm:
          clearZielgroesse ? null : (zielgroesseCm ?? this.zielgroesseCm),
      chipNummer: chipNummer ?? this.chipNummer,
      chipDatum: clearChipDatum ? null : (chipDatum ?? this.chipDatum),
      chipStelle: chipStelle ?? this.chipStelle,
      taetowierung: taetowierung ?? this.taetowierung,
      passNummer: passNummer ?? this.passNummer,
      passAusstellendeStelle:
          passAusstellendeStelle ?? this.passAusstellendeStelle,
      passAusstellungsdatum: clearPassAusstellungsdatum
          ? null
          : (passAusstellungsdatum ?? this.passAusstellungsdatum),
      halterName: halterName ?? this.halterName,
      halterAnschrift: halterAnschrift ?? this.halterAnschrift,
      halterTelefon: halterTelefon ?? this.halterTelefon,
      tierarztPraxis: tierarztPraxis ?? this.tierarztPraxis,
      tierarztName: tierarztName ?? this.tierarztName,
      tierarztAnschrift: tierarztAnschrift ?? this.tierarztAnschrift,
      tierarztTelefon: tierarztTelefon ?? this.tierarztTelefon,
      tierarztNotfallTelefon:
          tierarztNotfallTelefon ?? this.tierarztNotfallTelefon,
      tierarztEmail: tierarztEmail ?? this.tierarztEmail,
      tierarztSprechzeiten: tierarztSprechzeiten ?? this.tierarztSprechzeiten,
      notizen: notizen ?? this.notizen,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'rasse': rasse,
        'geschlecht': geschlecht.name,
        'kastriert': kastriert,
        'geburtsdatum': geburtsdatum?.toIso8601String(),
        'fellfarbe': fellfarbe,
        'besondereKennzeichen': besondereKennzeichen,
        'zielgewichtKg': zielgewichtKg,
        'zielgroesseCm': zielgroesseCm,
        'chipNummer': chipNummer,
        'chipDatum': chipDatum?.toIso8601String(),
        'chipStelle': chipStelle,
        'taetowierung': taetowierung,
        'passNummer': passNummer,
        'passAusstellendeStelle': passAusstellendeStelle,
        'passAusstellungsdatum': passAusstellungsdatum?.toIso8601String(),
        'halterName': halterName,
        'halterAnschrift': halterAnschrift,
        'halterTelefon': halterTelefon,
        'tierarztPraxis': tierarztPraxis,
        'tierarztName': tierarztName,
        'tierarztAnschrift': tierarztAnschrift,
        'tierarztTelefon': tierarztTelefon,
        'tierarztNotfallTelefon': tierarztNotfallTelefon,
        'tierarztEmail': tierarztEmail,
        'tierarztSprechzeiten': tierarztSprechzeiten,
        'notizen': notizen,
      };

  static DogProfile fromJson(Map<String, dynamic> json) => DogProfile(
        name: json['name'] as String? ?? '',
        rasse: json['rasse'] as String? ?? '',
        geschlecht: Geschlecht.parse(json['geschlecht'] as String?),
        kastriert: json['kastriert'] as bool? ?? false,
        geburtsdatum: _date(json['geburtsdatum']),
        fellfarbe: json['fellfarbe'] as String? ?? '',
        besondereKennzeichen: json['besondereKennzeichen'] as String? ?? '',
        zielgewichtKg: (json['zielgewichtKg'] as num?)?.toDouble(),
        zielgroesseCm: (json['zielgroesseCm'] as num?)?.toDouble(),
        chipNummer: json['chipNummer'] as String? ?? '',
        chipDatum: _date(json['chipDatum']),
        chipStelle: json['chipStelle'] as String? ?? '',
        taetowierung: json['taetowierung'] as String? ?? '',
        passNummer: json['passNummer'] as String? ?? '',
        passAusstellendeStelle:
            json['passAusstellendeStelle'] as String? ?? '',
        passAusstellungsdatum: _date(json['passAusstellungsdatum']),
        halterName: json['halterName'] as String? ?? '',
        halterAnschrift: json['halterAnschrift'] as String? ?? '',
        halterTelefon: json['halterTelefon'] as String? ?? '',
        tierarztPraxis: json['tierarztPraxis'] as String? ?? '',
        tierarztName: json['tierarztName'] as String? ?? '',
        tierarztAnschrift: json['tierarztAnschrift'] as String? ?? '',
        tierarztTelefon: json['tierarztTelefon'] as String? ?? '',
        tierarztNotfallTelefon:
            json['tierarztNotfallTelefon'] as String? ?? '',
        tierarztEmail: json['tierarztEmail'] as String? ?? '',
        tierarztSprechzeiten: json['tierarztSprechzeiten'] as String? ?? '',
        notizen: json['notizen'] as String? ?? '',
      );

  static DateTime? _date(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

enum Geschlecht {
  ruede('Rüde'),
  huendin('Hündin'),
  unbekannt('Keine Angabe');

  const Geschlecht(this.label);

  final String label;

  static Geschlecht parse(String? raw) => Geschlecht.values.firstWhere(
        (g) => g.name == raw,
        orElse: () => Geschlecht.unbekannt,
      );
}
