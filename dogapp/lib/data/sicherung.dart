import 'dart:convert';
import 'dart:typed_data';

import 'dog_repository.dart';
import 'sammlungen.dart';

/// Format der Sicherungsdatei. Steht mit in der Datei, damit ein
/// späteres Einspielen weiß, womit es zu tun hat.
const String sicherungsKennung = 'hunde-app';
const int sicherungsVersion = 1;

/// Was beim Einspielen passiert ist.
class Sicherungsbericht {
  const Sicherungsbericht({
    required this.eintraege,
    required this.fotos,
    required this.profilUebernommen,
  });

  final int eintraege;
  final int fotos;
  final bool profilUebernommen;

  String get zusammenfassung {
    final teile = <String>[
      '$eintraege ${eintraege == 1 ? 'Eintrag' : 'Einträge'}',
      if (fotos > 0) '$fotos ${fotos == 1 ? 'Foto' : 'Fotos'}',
      if (profilUebernommen) 'Heimtierausweis',
    ];
    return teile.join(', ');
  }
}

class SicherungsFehler implements Exception {
  const SicherungsFehler(this.nachricht);

  final String nachricht;

  @override
  String toString() => nachricht;
}

/// Erstellt eine vollständige Sicherung.
///
/// Bewusst als lesbares JSON und in einer einzigen Datei: Wer in zehn
/// Jahren wissen will, wann Bheki was gefressen hat, soll das mit
/// einem Texteditor herausfinden können – auch wenn es diese App dann
/// nicht mehr gibt. Die Fotos stecken als Base64 mit drin, damit die
/// Sicherung ein einzelnes Stück bleibt, das man nicht versehentlich
/// halb kopiert.
Future<Uint8List> erstelleSicherung(DogRepository repo) async {
  final sammlungen = <String, List<Map<String, dynamic>>>{};
  for (final name in Sammlungen.alle) {
    sammlungen[name] = await repo.alleEintraege(name);
  }

  final profil = await repo.watchDoc(Sammlungen.profil).first;
  final fotos = await repo.alleFotos();

  final inhalt = <String, dynamic>{
    'app': sicherungsKennung,
    'version': sicherungsVersion,
    'erstellt': DateTime.now().toIso8601String(),
    'profil': profil,
    'sammlungen': sammlungen,
    'fotos': fotos,
  };

  // Eingerückt, damit die Datei von Hand lesbar bleibt. Der Aufschlag
  // fällt neben den Fotodaten nicht ins Gewicht.
  final text = const JsonEncoder.withIndent('  ').convert(inhalt);
  return Uint8List.fromList(utf8.encode(text));
}

/// Spielt eine Sicherung ein.
///
/// Zusammenführen statt ersetzen: Vorhandene Einträge werden anhand
/// ihrer Kennung überschrieben, alles andere bleibt stehen. Ein
/// Import kann damit nichts wegwerfen, was nicht in der Datei steht –
/// wichtig, weil sonst ein versehentlich gewähltes altes Backup den
/// aktuellen Stand vernichten würde.
Future<Sicherungsbericht> spieleSicherungEin(
  DogRepository repo,
  Uint8List daten,
) async {
  final Map<String, dynamic> inhalt;
  try {
    inhalt = jsonDecode(utf8.decode(daten)) as Map<String, dynamic>;
  } catch (_) {
    throw const SicherungsFehler(
      'Diese Datei lässt sich nicht lesen. Erwartet wird eine '
      'Sicherungsdatei dieser App (Endung .json).',
    );
  }

  if (inhalt['app'] != sicherungsKennung) {
    throw const SicherungsFehler(
      'Diese Datei stammt nicht aus der Hunde-App.',
    );
  }

  final version = (inhalt['version'] as num?)?.toInt() ?? 0;
  if (version > sicherungsVersion) {
    throw SicherungsFehler(
      'Die Datei wurde mit einer neueren Fassung der App erstellt '
      '(Format $version, unterstützt wird $sicherungsVersion). Bitte '
      'zuerst die App aktualisieren.',
    );
  }

  var eintraege = 0;
  final sammlungen = inhalt['sammlungen'] as Map<String, dynamic>? ?? {};
  for (final eintrag in sammlungen.entries) {
    // Unbekannte Sammlungen überspringen statt abzubrechen: Eine
    // ältere App soll eine neuere Datei wenigstens teilweise lesen
    // können.
    if (!Sammlungen.alle.contains(eintrag.key)) continue;

    for (final zeile in (eintrag.value as List? ?? [])) {
      final daten = Map<String, dynamic>.from(zeile as Map);
      final id = daten['id'] as String?;
      if (id == null || id.isEmpty) continue;
      await repo.upsert(eintrag.key, id, daten);
      eintraege++;
    }
  }

  var fotos = 0;
  final fotoDaten = inhalt['fotos'] as Map<String, dynamic>? ?? {};
  for (final foto in fotoDaten.entries) {
    final base64Daten = foto.value as String? ?? '';
    if (base64Daten.isEmpty) continue;
    // Die Referenz enthält das Präfix des Ursprungsspeichers; für die
    // Ablage zählt nur die Kennung dahinter.
    final id = foto.key.contains(':')
        ? foto.key.split(':').last
        : foto.key;
    await repo.putPhoto(id, base64Decode(base64Daten));
    fotos++;
  }

  final profil = inhalt['profil'] as Map<String, dynamic>?;
  if (profil != null && profil.isNotEmpty) {
    await repo.setDoc(Sammlungen.profil, profil);
  }

  return Sicherungsbericht(
    eintraege: eintraege,
    fotos: fotos,
    profilUebernommen: profil != null && profil.isNotEmpty,
  );
}

/// Dateiname mit Datum, damit sich mehrere Sicherungen im
/// Download-Ordner nicht gegenseitig überschreiben.
String sicherungsDateiname(String hundename, DateTime jetzt) {
  final name = hundename.trim().isEmpty
      ? 'hund'
      : hundename
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
  final datum = '${jetzt.year}-'
      '${jetzt.month.toString().padLeft(2, '0')}-'
      '${jetzt.day.toString().padLeft(2, '0')}';
  return '$name-sicherung-$datum.json';
}
