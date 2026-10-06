import 'dart:convert';
import 'dart:typed_data';

import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/data/sammlungen.dart';
import 'package:dogapp/data/sicherung.dart';
import 'package:dogapp/models/dog_profile.dart';
import 'package:dogapp/models/feeding_entry.dart';
import 'package:dogapp/models/weight_entry.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Legt einen kleinen, aber vollständigen Bestand an: Profil,
  /// Einträge und ein Foto.
  Future<AppState> mitDaten() async {
    final state = AppState(LocalRepository());
    await state.init();

    await state.saveProfile(const DogProfile().copyWith(
      name: 'Bheki Shujaa',
      rasse: 'Rhodesian Ridgeback',
      fellfarbe: 'red wheaten',
    ));

    for (var i = 0; i < 3; i++) {
      await state.saveFeeding(FeedingEntry(
        zeitpunkt: DateTime(2026, 3, 10 - i, 8),
        futter: 'Mahlzeit $i',
        menge: 200,
      ));
    }

    final messung = WeightEntry(
      zeitpunkt: DateTime(2026, 3, 10),
      gewichtKg: 18.5,
      groesseCm: 52,
    );
    final ref = await state.storePhoto(
      messung.id,
      Uint8List.fromList([9, 8, 7, 6, 5]),
    );
    await state.saveWeight(messung.copyWith(fotoRef: ref));

    await settle();
    return state;
  }

  test('Sicherung enthält alles und ist lesbarer Text', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await mitDaten();

    final daten = await state.sicherungErstellen();
    final inhalt =
        jsonDecode(utf8.decode(daten)) as Map<String, dynamic>;

    expect(inhalt['app'], 'hunde-app');
    expect(inhalt['version'], 1);
    expect((inhalt['profil'] as Map)['name'], 'Bheki Shujaa');

    final sammlungen = inhalt['sammlungen'] as Map<String, dynamic>;
    // Jede bekannte Sammlung taucht auf, auch die leeren – sonst fällt
    // beim Zurückspielen erst auf, dass eine fehlt.
    expect(sammlungen.keys, containsAll(Sammlungen.alle));
    expect(sammlungen[Sammlungen.fuetterungen], hasLength(3));
    expect(sammlungen[Sammlungen.gewicht], hasLength(1));

    // Fotos stecken mit drin, sonst wäre es keine vollständige
    // Sicherung.
    final fotos = inhalt['fotos'] as Map<String, dynamic>;
    expect(fotos, hasLength(1));
    expect(base64Decode(fotos.values.first as String), [9, 8, 7, 6, 5]);
  });

  test('Sicherung überlebt den Weg in einen leeren Bestand', () async {
    SharedPreferences.setMockInitialValues({});
    final quelle = await mitDaten();
    final daten = await quelle.sicherungErstellen();
    final fotoRef = quelle.weights.single.fotoRef!;

    // Anderer Namensraum = anderer Bestand, so wie ein neues Gerät.
    final ziel = AppState(LocalRepository(namespace: 'neu'));
    await ziel.init();
    await settle();
    expect(ziel.feedings, isEmpty);

    final bericht = await ziel.sicherungEinspielen(daten);
    await settle();

    expect(bericht.eintraege, 4);
    expect(bericht.fotos, 1);
    expect(bericht.profilUebernommen, isTrue);

    expect(ziel.profile.name, 'Bheki Shujaa');
    expect(ziel.feedings, hasLength(3));
    expect(ziel.weights.single.gewichtKg, 18.5);
    expect(ziel.weights.single.groesseCm, 52);
    expect(await ziel.loadPhoto(fotoRef), [9, 8, 7, 6, 5]);
  });

  test('Einspielen ergänzt und wirft nichts weg', () async {
    SharedPreferences.setMockInitialValues({});
    final quelle = await mitDaten();
    final daten = await quelle.sicherungErstellen();

    final ziel = AppState(LocalRepository(namespace: 'neu'));
    await ziel.init();
    // Ein Eintrag, der nur hier steht und nicht in der Datei.
    final eigener = FeedingEntry(
      zeitpunkt: DateTime(2026, 5, 1, 12),
      futter: 'Nur hier',
      menge: 50,
    );
    await ziel.saveFeeding(eigener);
    await settle();

    await ziel.sicherungEinspielen(daten);
    await settle();

    expect(ziel.feedings, hasLength(4));
    expect(
      ziel.feedings.map((f) => f.futter),
      contains('Nur hier'),
    );
  });

  test('fremde und kaputte Dateien werden verständlich abgelehnt',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(LocalRepository());
    await state.init();

    Future<String> fehlerBei(List<int> bytes) async {
      try {
        await state.sicherungEinspielen(Uint8List.fromList(bytes));
        return 'kein Fehler';
      } on SicherungsFehler catch (e) {
        return e.nachricht;
      }
    }

    expect(await fehlerBei(utf8.encode('kein json')),
        contains('lässt sich nicht lesen'));
    expect(await fehlerBei(utf8.encode('{"app":"etwas-anderes"}')),
        contains('nicht aus der Hunde-App'));
    expect(
      await fehlerBei(utf8.encode('{"app":"hunde-app","version":99}')),
      contains('neueren Fassung'),
    );
  });

  test('Dateiname trägt Hundename und Datum', () {
    expect(
      sicherungsDateiname('Bheki Shujaa', DateTime(2026, 8, 5)),
      'bheki-shujaa-sicherung-2026-08-05.json',
    );
    // Ohne Namen trotzdem ein brauchbarer Dateiname.
    expect(
      sicherungsDateiname('', DateTime(2026, 12, 24)),
      'hund-sicherung-2026-12-24.json',
    );
  });
}
