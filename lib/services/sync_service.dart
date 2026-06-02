import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:opa_app/data/local/database_helper.dart';
import 'package:opa_app/data/local/sync_queue_dao.dart';
import 'package:opa_app/data/local/models/sync_queue.dart';
import 'package:opa_app/services/connectivity_service.dart';

class SyncService {
  final SyncQueueDao _queueDao = SyncQueueDao();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ConnectivityService _connectivityService = ConnectivityService();
  final Dio _dio = Dio();
  bool _isSyncing = false;

  Future<void> startSync() async {
    if (_isSyncing) return;
    if (!await _connectivityService.hasInternet()) return;

    _isSyncing = true;

    try {
      final pendingItems = await _queueDao.getPendingItems();
      
      for (var item in pendingItems) {
        await _processSyncItem(item);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncItem(SyncQueueItem item) async {
    try {
      // Update status to processing
      await _queueDao.updateStatus(item.id!, 'processing');

      // Send request
      final response = await _dio.request(
        item.endpoint,
        data: jsonDecode(item.payload),
        options: Options(method: item.method),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success: update local entity as synced
        await _markEntitySynced(item.entityType, item.entityId);
        // Remove from queue
        await _queueDao.removeFromQueue(item.id!);
      } else {
        throw Exception('Sync failed: ${response.statusCode}');
      }
    } catch (e) {
      // Increment retry count
      await _queueDao.incrementRetryCount(item.id!);
      
      // If max retries reached, mark as failed
      final updatedItem = (await _queueDao.getPendingItems())
          .firstWhere((i) => i.id == item.id, orElse: () => item);
      
      if (updatedItem.retryCount >= 5) {
        await _queueDao.updateStatus(item.id!, 'failed', error: e.toString());
      }
    }
  }

  Future<void> _markEntitySynced(String entityType, String entityId) async {
    switch (entityType) {
      case 'harvest':
        await _dbHelper.markAsSynced('harvests', entityId);
        break;
      case 'inspection':
        await _dbHelper.markAsSynced('inspections', entityId);
        break;
    }
  }
}