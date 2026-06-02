import 'package:opa_app/data/local/models/sync_queue.dart';
import 'package:opa_app/data/local/database_helper.dart';

class SyncQueueDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addToQueue(SyncQueueItem item) async {
    final db = await _dbHelper.database;
    return await db.insert('sync_queue', item.toMap());
  }

  Future<List<SyncQueueItem>> getPendingItems({int limit = 10}) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sync_queue',
      where: 'status IN (?, ?) AND retry_count < ?',
      whereArgs: ['pending', 'processing', 5],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return result.map((e) => SyncQueueItem.fromMap(e)).toList();
  }

  Future<void> updateStatus(int id, String status, {String? error}) async {
    final db = await _dbHelper.database;
    await db.update(
      'sync_queue',
      {
        'status': status,
        if (error != null) 'sync_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementRetryCount(int id) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> removeFromQueue(int id) async {
    final db = await _dbHelper.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}