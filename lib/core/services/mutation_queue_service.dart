import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/local_database.dart';
import '../utils/logger.dart';

class MutationQueueService {
  MutationQueueService._();
  static final MutationQueueService instance = MutationQueueService._();

  final _db = LocalDatabase();

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    await _db.into(_db.pendingMutations).insert(
          PendingMutationsCompanion.insert(
            type: type,
            payload: jsonEncode(payload),
          ),
        );
  }

  Future<void> replayAll() async {
    final pending = await (_db.select(_db.pendingMutations)
          ..where((t) => t.synced.equals(false)))
        .get();

    for (final mutation in pending) {
      try {
        await _replayMutation(mutation);
        await (_db.update(_db.pendingMutations)
              ..where((t) => t.id.equals(mutation.id)))
            .write(PendingMutationsCompanion(synced: const Value(true)));
      } catch (e) {
        Logger.d('⚠️ MutationQueue: failed to replay ${mutation.type}: $e');
        // Leave in queue to retry on next connectivity restore
      }
    }
  }

  Future<void> _replayMutation(PendingMutation m) async {
    final payload = jsonDecode(m.payload) as Map<String, dynamic>;
    if (m.type == 'status_update') {
      // TODO: wire to ApiClient / order repository status update
      Logger.d('🔄 Replaying status_update: $payload');
    } else if (m.type == 'location_update') {
      // TODO: wire to ApiClient / location repository update
      Logger.d('🔄 Replaying location_update: $payload');
    }
  }
}
