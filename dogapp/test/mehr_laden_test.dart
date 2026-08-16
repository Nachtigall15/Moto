import 'package:dogapp/data/local_repository.dart';
import 'package:dogapp/models/feeding_entry.dart';
import 'package:dogapp/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// „Ältere laden" aus Sicht des Anwendungszustands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('mehrLaden vergrößert das Fenster und behält alles Geladene',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(LocalRepository());
    await state.init();

    // Mehr Einträge, als ein Schritt lädt.
    final schritt = Bereich.fuetterung.schritt;
    final gesamt = schritt + 25;
    for (var i = 0; i < gesamt; i++) {
      await state.saveFeeding(FeedingEntry(
        zeitpunkt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
        futter: 'Mahlzeit $i',
        menge: 100,
      ));
    }
    await settle();

    expect(state.feedings, hasLength(schritt));
    expect(state.amRand(Bereich.fuetterung), isTrue);
    final vorher = state.feedings.map((f) => f.id).toList();

    await state.mehrLaden(Bereich.fuetterung);
    await settle();

    expect(state.feedings, hasLength(gesamt));
    // Das bereits Geladene bleibt drin – es wird nur ergänzt.
    expect(state.feedings.map((f) => f.id), containsAll(vorher));
    // Jetzt ist alles da, der Knopf verschwindet.
    expect(state.amRand(Bereich.fuetterung), isFalse);

    // Der älteste Eintrag war vorher nicht dabei und ist es jetzt.
    expect(vorher.contains(state.feedings.last.id), isFalse);
    expect(state.feedings.last.futter, 'Mahlzeit ${gesamt - 1}');
  });
}
