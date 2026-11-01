import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contract/contract.dart';
import 'db/database.dart';
import 'store.dart';

final fixturesProvider = Provider<Fixtures>(
  (ref) => throw UnimplementedError(),
);

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(),
);

final meProvider = Provider<String>(
  (ref) => ref.watch(fixturesProvider).me,
);

final entrancesProvider = StreamProvider<List<Entrance>>(
  (ref) => ref.watch(databaseProvider).watchEntrances(),
);

final entranceProvider = StreamProvider.family<Entrance?, String>(
  (ref, id) => ref.watch(databaseProvider).watchEntrance(id),
);

final buildingProvider = StreamProvider.family<Building?, String>(
  (ref, id) => ref.watch(databaseProvider).watchBuilding(id),
);