import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'local_database.g.dart';

class PendingMutations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 'status_update' | 'location_update'
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

class CachedOrders extends Table {
  TextColumn get orderId => text().withLength(max: 36)();
  TextColumn get orderJson => text()();
  DateTimeColumn get syncedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {orderId};
}

@DriftDatabase(tables: [PendingMutations, CachedOrders])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(driftDatabase(name: 'hur_delivery.db'));
  @override
  int get schemaVersion => 1;
}
