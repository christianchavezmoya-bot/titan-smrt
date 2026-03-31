import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class SyncService {
  SyncService({required this.apiClient, required this.store});

  final ApiClient apiClient;
  final LocalStore store;

  Future<SyncResult> sync() async {
    final payload = {
      'last_sync_at': store.lastSyncAt?.toIso8601String() ?? '',
      'entities': await store.dumpDirtyEntities(),
    };

    final response = await apiClient.postJson('/v1/sync', payload);
    if (response.statusCode != 200) {
      return SyncResult.failure('Sync failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final conflicts = (decoded['conflicts'] as List<dynamic>)
        .map((item) => SyncConflict.fromJson(item as Map<String, dynamic>))
        .toList();
    final updates = (decoded['updated_entities'] as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList();

    await store.resolveConflicts(conflicts);
    await store.applyServerUpdates(updates);
    await store.markSynced();
    await _flushPendingReorders();

    return SyncResult.success(conflicts);
  }

  Future<void> _flushPendingReorders() async {
    final pending = await store.listPendingReorders();
    for (final item in pending) {
      final routineId = item['routine_id'] as String?;
      final payload = item['payload'] as String?;
      if (routineId == null || payload == null) {
        continue;
      }
      final response = await apiClient.postJson(
        '/v1/routines/$routineId/reorder',
        jsonDecode(payload) as List<dynamic>,
      );
      if (response.statusCode == 200) {
        await store.clearPendingReorder(item['id'] as String);
      }
    }
  }
}

class SyncResult {
  SyncResult._(this.ok, this.message, this.conflicts);

  final bool ok;
  final String? message;
  final List<SyncConflict> conflicts;

  factory SyncResult.success(List<SyncConflict> conflicts) =>
      SyncResult._(true, null, conflicts);

  factory SyncResult.failure(String message) =>
      SyncResult._(false, message, const []);
}

class SyncConflict {
  SyncConflict({required this.entity, required this.id, required this.server, required this.client});

  final String entity;
  final String id;
  final Map<String, dynamic> server;
  final Map<String, dynamic> client;

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      entity: json['entity'] as String,
      id: json['id'] as String,
      server: Map<String, dynamic>.from(json['server'] as Map),
      client: Map<String, dynamic>.from(json['client'] as Map),
    );
  }
}

abstract class LocalStore {
  DateTime? get lastSyncAt;

  Future<Map<String, List<Map<String, dynamic>>>> dumpDirtyEntities();

  Future<void> resolveConflicts(List<SyncConflict> conflicts);

  Future<void> keepLocal(SyncConflict conflict);

  Future<void> keepServer(SyncConflict conflict);

  Future<List<Map<String, dynamic>>> listPendingReorders();

  Future<void> clearPendingReorder(String id);

  Future<void> applyServerUpdates(List<Map<String, dynamic>> updates);

  Future<void> markSynced();
}
