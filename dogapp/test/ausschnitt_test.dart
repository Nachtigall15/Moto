import 'package:dogapp/data/local_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Die App lädt nicht das ganze Archiv, sondern ein Fenster der
/// jüngsten Einträge. Diese Tests halten fest, dass das Fenster
/// wirklich greift – und zwar am jüngeren Ende.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalRepository repo;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalRepository();
    await repo.init();
  });

  /// Legt [anzahl] Einträge an, einen pro Tag rückwärts ab dem
  /// 1. Januar 2026.
  Future<void> lege(String sammlung, int anzahl) async {
    for (var i = 0; i < anzahl; i++) {
      final tag = DateTime(2026, 1, 1).subtract(Duration(days: i));
      await repo.upsert(sammlung, 'e$i', {
        'id': 'e$i',
        'zeitpunkt': tag.toIso8601String(),
      });
    }
  }

  test('ohne Grenze kommt alles', () async {
    await lege('test', 12);

    final rows = await repo.watchCollection('test').first;
    expect(rows, hasLength(12));
  });

  test('die Grenze schneidet die ältesten Einträge ab', () async {
    await lege('test', 50);

    final rows = await repo
        .watchCollection('test', sortierFeld: 'zeitpunkt', limit: 10)
        .first;

    expect(rows, hasLength(10));
    // Der jüngste Eintrag ist der 1. Januar, der zehntjüngste der
    // 23. Dezember – was davor liegt, bleibt draußen.
    expect(rows.first['zeitpunkt'], startsWith('2026-01-01'));
    expect(rows.last['zeitpunkt'], startsWith('2025-12-23'));
  });

  test('weniger Einträge als die Grenze bleiben vollständig', () async {
    await lege('test', 3);

    final rows = await repo
        .watchCollection('test', sortierFeld: 'zeitpunkt', limit: 10)
        .first;

    expect(rows, hasLength(3));
  });

  test('ein neuer Eintrag verdrängt den ältesten aus dem Fenster',
      () async {
    await lege('test', 10);

    final stream = repo
        .watchCollection('test', sortierFeld: 'zeitpunkt', limit: 5)
        .asBroadcastStream();
    final ersteZustellung = await stream.first;
    expect(ersteZustellung.first['zeitpunkt'], startsWith('2026-01-01'));

    // Etwas Jüngeres kommt dazu – der Ausschnitt muss nachrutschen,
    // nicht bei der alten Auswahl kleben bleiben.
    final naechste = stream.first;
    await repo.upsert('test', 'neu', {
      'id': 'neu',
      'zeitpunkt': DateTime(2026, 2, 1).toIso8601String(),
    });
    await settle();

    final rows = await naechste;
    expect(rows, hasLength(5));
    expect(rows.first['zeitpunkt'], startsWith('2026-02-01'));
    expect(rows.map((r) => r['id']), isNot(contains('e4')));
  });
}
