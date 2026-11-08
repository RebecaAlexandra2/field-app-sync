import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_app/db/database.dart';
import 'package:field_app/contract/contract.dart';

void main() {
  late AppDatabase db;
  late Entrance pin;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final building = Building.fromJson({
      'id': 'b', 'label': 'Building', 'comment': null,
      'createdAt': '2026-01-01T00:00:00Z', 'updatedAt': '2026-01-01T00:00:00Z',
    });
    await db.seedIfEmpty([building]);
    pin = Entrance.fromJson({
      'id': 'e', 'buildingId': 'b', 'lat': 44.4, 'lng': 26.1,
      'street': 'Street', 'number': '1', 'entranceName': 'A',
      'coordsConfirmed': false, 'correctedLat': null, 'correctedLng': null,
      'addressConfirmed': false, 'stories': 4, 'flats': 20, 'elevators': 1,
      'yearBuilt': 1980, 'groundFloorCommercial': false, 'comment': null,
      'surveyStatus': 'not_started', 'surveyedBy': null, 'surveyedAt': null,
      'createdAt': '2026-01-01T00:00:00Z', 'updatedAt': '2026-01-01T00:00:00Z',
    });
  });
  tearDown(() => db.close());

  test('seed stores buildings only; cloud pins arrive separately', () async {
    expect(await db.watchEntrances().first, isEmpty);
    await db.savePins([pin]);
    expect((await db.watchEntrances().first).single.id, 'e');
  });

  test('reassignment removes synced pins', () async {
    await db.savePins([pin]);
    await db.savePins([]);
    expect(await db.watchEntrances().first, isEmpty);
  });

  test('pull preserves unsent survey and refusal preserves local data', () async {
    await db.savePins([pin]);
    await db.submitSurvey(pin.copyWith(comment: 'local survey'), 'worker-a');
    await db.savePins([]);
    final pending = (await db.outbox()).single;
    expect(pending.comment, 'local survey');
    await db.markSent(pending.id, pending.updatedAt, 'permission-denied');
    expect((await db.watchOutbox().first).failed, 1);
    expect((await db.outbox()).single.comment, 'local survey');
  });

  test('stale acknowledgement cannot mark a newer edit as sent', () async {
    await db.savePins([pin]);
    await db.submitSurvey(pin, 'worker-a');
    await db.markSent('e', pin.updatedAt, null);
    expect(await db.outbox(), hasLength(1));
    final row = (await db.outbox()).single;
    await db.markSent('e', row.updatedAt, null);
    expect(await db.outbox(), isEmpty);
  });

  test('missed building stays local until supported by cloud', () async {
    await db.addMissedEntrance(44.4, 26.1, 'new-b', 'new-e');
    final entrance = await db.watchEntrance('new-e').first;
    await db.submitSurvey(entrance!, 'worker-a');
    expect(await db.outbox(), isEmpty);
    expect(await db.watchBuilding('new-b').first, isNotNull);
  });
}
