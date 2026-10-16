import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class PendingSyncs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientRequestId => text()();
  TextColumn get endpoint => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

@DriftDatabase(tables: [PendingSyncs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'payrollpro.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  /// Counts items in PendingSyncs with status == 'pending'
  Future<int> getPendingSyncCount() async {
    final rows = await (select(pendingSyncs)
          ..where((t) => t.status.equals('pending')))
        .get();
    return rows.length;
  }

  /// Checks whether there are unsynced items in the queue
  Future<bool> hasPendingSync() async {
    final count = await getPendingSyncCount();
    return count > 0;
  }

  /// Enqueues an offline attendance write with a clientRequestId UUID
  Future<int> enqueuePendingSync({
    required String clientRequestId,
    required String endpoint,
    required String payload,
  }) async {
    return into(pendingSyncs).insert(
      PendingSyncsCompanion.insert(
        clientRequestId: clientRequestId,
        endpoint: endpoint,
        payload: payload,
        status: const Value('pending'),
      ),
    );
  }

  /// Returns all unsynced items (pending or failed) in FIFO order
  Future<List<PendingSync>> getPendingSyncItems() async {
    final all = await select(pendingSyncs).get();
    return all
        .where((r) => r.status == 'pending' || r.status == 'failed')
        .toList();
  }

  /// Updates the sync status of a specific clientRequestId ('pending', 'syncing', 'synced', 'failed')
  Future<void> updatePendingSyncStatus(String clientRequestId, String status) async {
    await (update(pendingSyncs)
          ..where((t) => t.clientRequestId.equals(clientRequestId)))
        .write(PendingSyncsCompanion(status: Value(status)));
  }

  /// Deletes a synced item by clientRequestId
  Future<void> deleteSyncedItem(String clientRequestId) async {
    await (delete(pendingSyncs)
          ..where((t) => t.clientRequestId.equals(clientRequestId)))
        .go();
  }

  /// Enforces 30-day retention policy on local queue (Planning/01 §10.6)
  Future<int> purgeExpiredPendingSyncs({int retentionDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    return (delete(pendingSyncs)
          ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Wipes all local database tables on logout (Planning/01 §10.2 & §10.6)
  Future<void> clearAllLocalData() async {
    await delete(pendingSyncs).go();
  }
}


