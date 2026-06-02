import 'dart:convert';
import 'package:opa_app/domain/entities/harvest.dart';
import 'package:opa_app/data/local/database_helper.dart';
import 'package:opa_app/data/local/sync_queue_dao.dart';
import 'package:opa_app/data/local/models/sync_queue.dart';

class HarvestRepositoryImpl {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncQueueDao _syncQueueDao = SyncQueueDao();

  Future<void> saveHarvest(Harvest harvest) async {
    // 1. Save to local database first
    await _dbHelper.insert('harvests', harvest.toMap());

    // 2. Add to sync queue
    final syncItem = SyncQueueItem(
      endpoint: '/api/harvests',
      method: 'POST',
      payload: jsonEncode({
        'block_id': harvest.blockId,
        'tonase': harvest.tonase,
        'harvest_date': harvest.harvestDate.toIso8601String(),
        'photo_url': harvest.photoUrl,
        'created_by': harvest.createdBy,
      }),
      entityType: 'harvest',
      entityId: harvest.id!,
      createdAt: DateTime.now(),
    );

    await _syncQueueDao.addToQueue(syncItem);
  }

  Future<List<Harvest>> getUnsyncedHarvests() async {
    final result = await _dbHelper.query('harvests', isSynced: false);
    return result.map((e) => Harvest.fromMap(e)).toList();
  }

  Future<List<Harvest>> getHarvestsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'harvests',
      where: 'harvest_date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'harvest_date DESC',
    );
    return result.map((e) => Harvest.fromMap(e)).toList();
  }
}