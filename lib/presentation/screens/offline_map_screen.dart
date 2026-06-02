import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:opa_app/services/offline_map_service.dart';

class OfflineMapScreen extends ConsumerStatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  ConsumerState<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends ConsumerState<OfflineMapScreen> {
  MapboxMap? _mapboxMap;
  final OfflineMapService _offlineService = OfflineMapService();
  
  bool _isLoading = true;
  bool _hasOfflineData = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  
  List<Map<String, dynamic>> _blocks = [];
  Set<String> _addedSources = {};

  @override
  void initState() {
    super.initState();
    _initOfflineMap();
  }

  Future<void> _initOfflineMap() async {
    await _offlineService.initialize();
    
    final hasData = await _offlineService.hasOfflineData();
    setState(() {
      _hasOfflineData = hasData;
    });
    
    if (hasData) {
      await _loadCachedBlocks();
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCachedBlocks() async {
    final blocks = await _offlineService.getCachedBlocks();
    setState(() {
      _blocks = blocks;
    });
    
    _addPolygonsToMap();
  }

  Future<void> _downloadOfflineArea() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });
    
    try {
      // Get current map bounds
      if (_mapboxMap == null) return;
      
      final cameraState = await _mapboxMap!.getCameraState();
      final bounds = cameraState.bounds;
      
      await _offlineService.downloadOfflineMap(
        'current-estate-id', // Replace with actual estate ID
        bounds!,
      );
      
      await _loadCachedBlocks();
      
      setState(() {
        _hasOfflineData = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peta offline berhasil diunduh')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _addPolygonsToMap() async {
    if (_mapboxMap == null) return;
    
    for (var block in _blocks) {
      if (_addedSources.contains(block['id'])) continue;
      
      final geometryJson = jsonDecode(block['geometry']);
      
      // Add source
      final sourceId = 'source_${block['id']}';
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: sourceId, data: geometryJson),
      );
      
      // Add polygon layer
      final layerId = 'layer_${block['id']}';
      await _mapboxMap!.style.addPolygonLayer(
        layerId,
        sourceId,
        PolygonLayerSettings(
          fillColor: 0x334CAF50,
          fillOutlineColor: 0xFF2E7D32,
          fillOpacity: 0.5,
        ),
      );
      
      _addedSources.add(block['id']);
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    
    mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );
    
    if (_hasOfflineData) {
      _addPolygonsToMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Offline'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (!_hasOfflineData && !_isDownloading)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadOfflineArea,
              tooltip: 'Download peta offline',
            ),
          if (_hasOfflineData)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await _offlineService.clearOfflineData();
                setState(() {
                  _hasOfflineData = false;
                  _blocks.clear();
                  _addedSources.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data offline dihapus')),
                );
              },
              tooltip: 'Hapus data offline',
            ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: 'mapbox://styles/mapbox/outdoors-v12',
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          
          if (_isDownloading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Mengunduh peta offline...'),
                        const SizedBox(height: 8),
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          if (!_hasOfflineData && !_isDownloading && !_isLoading)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.orange.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_off, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Belum ada data offline. Download peta untuk penggunaan offline.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _downloadOfflineArea,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                        child: const Text('Download Sekarang'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          if (_hasOfflineData)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.offline_bolt, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Offline Mode', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}