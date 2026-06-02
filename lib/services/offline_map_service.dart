import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class OfflineMapService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';
  Database? _database;
  
  String? _currentEstateId;
  List<Map<String, dynamic>> _cachedBlocks = [];

  Future<void> initialize() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = '${directory.path}/offline_map.db';
    
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE map_tiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            z INTEGER,
            x INTEGER,
            y INTEGER,
            data BLOB,
            created_at TEXT
          )
        ''');
        
        await db.execute('''
          CREATE TABLE blocks (
            id TEXT PRIMARY KEY,
            name TEXT,
            geometry TEXT,
            area REAL,
            estate_id TEXT
          )
        ''');
      },
    );
  }

  Future<void> downloadOfflineMap(String estateId, MapBounds bounds) async {
    _currentEstateId = estateId;
    
    try {
      final response = await _dio.get(
        '$_baseUrl/map/offline-package',
        queryParameters: {
          'estateId': estateId,
          'minLat': bounds.southwest.latitude,
          'minLng': bounds.southwest.longitude,
          'maxLat': bounds.northeast.latitude,
          'maxLng': bounds.northeast.longitude,
        },
        options: Options(headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        }),
      );
      
      final package = response.data;
      
      // Save blocks to local database
      await _saveBlocks(package['geojson']['features']);
      
      // Save tiles (would need actual tile downloads)
      // This is simplified - in production, you'd download Mapbox tiles
      
      return package;
    } catch (e) {
      throw Exception('Failed to download offline map: $e');
    }
  }

  Future<void> _saveBlocks(List<dynamic> features) async {
    if (_database == null) return;
    
    for (var feature in features) {
      final props = feature['properties'];
      await _database!.insert(
        'blocks',
        {
          'id': props['id'],
          'name': props['name'],
          'geometry': jsonEncode(feature['geometry']),
          'area': props['area'],
          'estate_id': _currentEstateId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCachedBlocks() async {
    if (_database == null) return [];
    
    if (_cachedBlocks.isEmpty) {
      final result = await _database!.query('blocks');
      _cachedBlocks = result;
    }
    
    return _cachedBlocks;
  }

  Future<String?> getCachedGeometry(String blockId) async {
    if (_database == null) return null;
    
    final result = await _database!.query(
      'blocks',
      where: 'id = ?',
      whereArgs: [blockId],
    );
    
    if (result.isNotEmpty) {
      return result.first['geometry'] as String;
    }
    return null;
  }

  Future<bool> hasOfflineData() async {
    if (_database == null) return false;
    
    final count = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM blocks'),
    );
    
    return count != null && count > 0;
  }

  Future<void> clearOfflineData() async {
    if (_database == null) return;
    
    await _database!.delete('blocks');
    await _database!.delete('map_tiles');
    _cachedBlocks.clear();
  }

  Future<String?> _getToken() async {
    // Implement token retrieval
    return '';
  }
}