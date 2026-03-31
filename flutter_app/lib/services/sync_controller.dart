import 'package:flutter/material.dart';
import 'api_client.dart';
import 'local_store.dart';
import 'sync_service.dart';

enum SyncState { idle, syncing, ok, error }

class SyncController extends ChangeNotifier {
  SyncController({required ApiClient apiClient, required LocalStoreSqlite store})
      : _service = SyncService(apiClient: apiClient, store: store),
        _store = store;

  final SyncService _service;
  final LocalStoreSqlite _store;

  SyncState state = SyncState.idle;
  String? message;
  List<SyncConflict> conflicts = [];

  DateTime? get lastSyncAt => _store.lastSyncAt;

  Future<void> sync() async {
    state = SyncState.syncing;
    message = null;
    conflicts = [];
    notifyListeners();

    final result = await _service.sync();
    if (result.ok) {
      state = SyncState.ok;
      conflicts = result.conflicts;
    } else {
      state = SyncState.error;
      message = result.message;
    }
    notifyListeners();
  }
}
