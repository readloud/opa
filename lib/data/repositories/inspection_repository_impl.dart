import 'dart:convert';
import 'package:opa_app/data/local/database_helper.dart';
import 'package:opa_app/data/local/sync_queue_dao.dart';
import 'package:opa_app/data/local/models/sync_queue.dart';
import 'package:opa_app/domain/entities/inspection.dart';

class InspectionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SyncQueueDao _syncQueueDao = SyncQueueDao();

  Future<void> saveInspection(Inspection inspection) async {
    // 1. Save to local database first
    await _dbHelper.insert('inspections', inspection.toMap());

    // 2. Add to sync queue
    final syncItem = SyncQueueItem(
      endpoint: '/api/inspections',
      method: 'POST',
      payload: jsonEncode({
        'block_id': inspection.blockId,
        'tree_id': inspection.treeId,
        'condition': inspection.condition.name,
        'notes': inspection.notes,
        'photo_url': inspection.photoUrl,
        'latitude': inspection.latitude,
        'longitude': inspection.longitude,
        'created_by': inspection.createdBy,
        'created_at': inspection.createdAt.toIso8601String(),
      }),
      entityType: 'inspection',
      entityId: inspection.id!,
      createdAt: DateTime.now(),
    );

    await _syncQueueDao.addToQueue(syncItem);
  }

  Future<List<Inspection>> getInspectionsByBlock(String blockId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'inspections',
      where: 'block_id = ?',
      whereArgs: [blockId],
      orderBy: 'created_at DESC',
    );
    return result.map((e) => Inspection.fromMap(e)).toList();
  }

  Future<List<Inspection>> getUnsyncedInspections() async {
    final result = await _dbHelper.query('inspections', isSynced: false);
    return result.map((e) => Inspection.fromMap(e)).toList();
  }
}