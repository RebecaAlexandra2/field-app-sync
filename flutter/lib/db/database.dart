import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../contract/contract.dart';

part 'database.g.dart';

mixin RowColumns on Table {
  TextColumn get id => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

mixin LocalColumns on Table {
  TextColumn get syncState =>
      textEnum<SyncState>().withDefault(const Constant('pending'))();

  TextColumn get lastError => text().nullable()();
}

@DataClassName('BuildingRow')
class Buildings extends Table with RowColumns, LocalColumns {
  TextColumn get label => text()();
  TextColumn get comment => text().nullable()();
}

@DataClassName('EntranceRow')
class Entrances extends Table with RowColumns, LocalColumns {
  TextColumn get buildingId => text().references(Buildings, #id)();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  TextColumn get street => text()();
  TextColumn get number => text()();
  TextColumn get entranceName => text()();
  BoolColumn get coordsConfirmed => boolean()();
  RealColumn get correctedLat => real().nullable()();
  RealColumn get correctedLng => real().nullable()();
  BoolColumn get addressConfirmed => boolean()();
  IntColumn get stories => integer().nullable()();
  IntColumn get flats => integer().nullable()();
  IntColumn get elevators => integer().nullable()();
  IntColumn get yearBuilt => integer().nullable()();
  BoolColumn get groundFloorCommercial => boolean().nullable()();
  TextColumn get comment => text().nullable()();
  TextColumn get surveyStatus => textEnum<SurveyStatus>()();
  TextColumn get surveyedBy => text().nullable()();
  TextColumn get surveyedAt => text().nullable()();
}

@DataClassName('PhotoRow')
class Photos extends Table with RowColumns, LocalColumns {
  TextColumn get entranceId => text().references(Entrances, #id)();
  TextColumn get fileName => text()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get takenAt => text()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get heading => real().nullable()();

  TextColumn get uploadState =>
      textEnum<UploadState>().withDefault(const Constant('pending'))();

  TextColumn get reviewStatus =>
      textEnum<ReviewStatus>().withDefault(const Constant('pending'))();

  TextColumn get reviewNote => text().nullable()();
  TextColumn get reviewedBy => text().nullable()();
  TextColumn get replacesPhotoId => text().nullable()();
  TextColumn get localUri => text()();
}

@DriftDatabase(tables: [Buildings, Entrances, Photos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'field',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  Future<void> seedIfEmpty(
    List<Building> fromOffice,
    List<Entrance> entrancesFromOffice,
  ) async {
    final n = await entrances.count().getSingle();
    if (n > 0) return;

    const synced = {'syncState': 'synced', 'lastError': null};

    await batch((b) {
      b.insertAll(buildings, [
        for (final x in fromOffice)
          BuildingRow.fromJson({...x.toJson(), ...synced}),
      ]);

      b.insertAll(entrances, [
        for (final x in entrancesFromOffice)
          EntranceRow.fromJson({...x.toJson(), ...synced}),
      ]);
    });
  }

  Stream<List<Entrance>> watchEntrances() => select(entrances)
      .watch()
      .map((rows) => [for (final row in rows) Entrance.fromJson(row.toJson())]);

  Stream<Entrance?> watchEntrance(String id) =>
      (select(entrances)..where((e) => e.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : Entrance.fromJson(row.toJson()));

  Stream<Building?> watchBuilding(String id) =>
      (select(buildings)..where((b) => b.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : Building.fromJson(row.toJson()));

  Future<void> submitSurvey(Entrance surveyed, String me) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final row = surveyed.copyWith(
      surveyStatus: SurveyStatus.submitted,
      surveyedBy: me,
      surveyedAt: now,
      updatedAt: now,
    );

    await into(entrances).insertOnConflictUpdate(
      EntranceRow.fromJson({
        ...row.toJson(),
        'syncState': 'pending',
        'lastError': null,
      }),
    );
  }

  Stream<List<PhotoRow>> watchPhotos(String entranceId) =>
      (select(photos)..where((p) => p.entranceId.equals(entranceId))).watch();
}
