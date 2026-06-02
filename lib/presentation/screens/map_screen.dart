import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:opa_app/domain/entities/map_block.dart';
import 'package:opa_app/services/map_service.dart';
import 'package:opa_app/presentation/providers/map_provider.dart';
import 'package:opa_app/presentation/widgets/block_detail_bottom_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? _mapboxMap;
  final MapService _mapService = MapService();
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  List<MapBlock> _blocks = [];
  MapBlock? _selectedBlock;
  bool _isLoading = true;
  bool _isFollowingUser = true;

  // Camera state
  CameraState? _cameraState;
  PointAnnotationManager? _pointAnnotationManager;
  PolygonAnnotationManager? _polygonAnnotationManager;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadBlocks();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      
      if (_isFollowingUser && _mapboxMap != null) {
        _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                position.longitude,
                position.latitude,
              ),
            ),
            zoom: 16,
          ),
          MapAnimation(duration: 500),
        );
      }
    });

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _loadBlocks() async {
    setState(() => _isLoading = true);
    
    try {
      final blocks = await ref.read(blockRepositoryProvider).getAllBlocks();
      setState(() {
        _blocks = blocks;
        _isLoading = false;
      });
      
      if (_mapboxMap != null) {
        _addPolygonsToMap();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat blok: $e')),
      );
    }
  }

  Future<void> _addPolygonsToMap() async {
    if (_polygonAnnotationManager == null) {
      _polygonAnnotationManager =
          await _mapboxMap!.annotations.createPolygonAnnotationManager();
    }

    // Clear existing polygons
    _polygonAnnotationManager!.deleteAll();

    for (var block in _blocks) {
      for (var polygon in block.polygonCoordinates) {
        final coordinates = polygon
            .map((point) => Point(
                  coordinates: Position(point.longitude, point.latitude),
                ))
            .toList();

        final polygonAnnotation = PolygonAnnotationOptions(
          fillColor: _getFillColor(block),
          fillOpacity: block.isSelected ? 0.6 : 0.3,
          strokeColor: _getStrokeColor(block),
          strokeWidth: 2.0,
          geometry: Polygon(
            coordinates: [coordinates],
          ),
        );

        await _polygonAnnotationManager!.create(polygonAnnotation);
      }
    }
  }

  int _getFillColor(MapBlock block) {
    if (block.isSelected) return 0x884CAF50;
    return block.color.value & 0x44FFFFFF;
  }

  int _getStrokeColor(MapBlock block) {
    if (block.isSelected) return 0xFF2E7D32;
    return block.color.value;
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    
    // Add user location
    mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingMaxRadius: 20.0,
      ),
    );

    // Listen to tap on map
    mapboxMap.onTap.add(_handleMapTap);

    // Add polygons after map is created
    _addPolygonsToMap();
    
    // Add markers for blocks center
    _addBlockMarkers();
  }

  Future<void> _addBlockMarkers() async {
    if (_pointAnnotationManager == null) {
      _pointAnnotationManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();
    }

    for (var block in _blocks) {
      final centroid = _mapService.getPolygonCentroid(block.polygonCoordinates.first);
      
      final annotation = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(centroid.longitude, centroid.latitude),
        ),
        iconImage: 'marker-icon', // Register image first
        iconSize: 1.5,
        textField: block.name,
        textOffset: [0, -1.5],
        textColor: 0xFF2E7D32,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 2,
        textSize: 14,
      );
      
      await _pointAnnotationManager!.create(annotation);
    }
  }

  void _handleMapTap(TapEvent event) async {
    final screenCoordinate = event.point;
    
    // Query for polygons
    final queriedFeatures = await _mapboxMap!.queryRenderedFeatures(
      screenCoordinate,
      RenderedQueryOptions(layerIds: ['polygon-layer']),
    );

    if (queriedFeatures.features.isNotEmpty) {
      final feature = queriedFeatures.features.first;
      final blockId = feature.properties?['id']?.value as String?;
      
      if (blockId != null) {
        final block = _blocks.firstWhere((b) => b.id == blockId);
        setState(() {
          _selectedBlock = block;
          _blocks = _blocks.map((b) {
            b.isSelected = b.id == blockId;
            return b;
          }).toList();
        });
        
        _addPolygonsToMap();
        _showBlockDetail(block);
      }
    } else {
      setState(() {
        _selectedBlock = null;
        _blocks = _blocks.map((b) {
          b.isSelected = false;
          return b;
        }).toList();
      });
      _addPolygonsToMap();
    }
  }

  void _showBlockDetail(MapBlock block) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BlockDetailBottomSheet(block: block),
    );
  }

  void _centerToUser() {
    if (_currentPosition != null && _mapboxMap != null) {
      setState(() => _isFollowingUser = true);
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 16,
        ),
        MapAnimation(duration: 500),
      );
    }
  }

  void _zoomToAllBlocks() {
    if (_blocks.isEmpty || _mapboxMap == null) return;
    
    // Calculate bounds of all blocks
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    
    for (var block in _blocks) {
      for (var polygon in block.polygonCoordinates) {
        for (var point in polygon) {
          minLat = min(minLat, point.latitude);
          maxLat = max(maxLat, point.latitude);
          minLng = min(minLng, point.longitude);
          maxLng = max(maxLng, point.longitude);
        }
      }
    }
    
    final bounds = CoordinateBounds(
      southwest: Position(minLng, minLat),
      northeast: Position(maxLng, maxLat),
    );
    
    _mapboxMap!.cameraManager.flyToBounds(
      bounds,
      EdgeInsets.all(50),
      MapAnimation(duration: 800),
    );
    
    setState(() => _isFollowingUser = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Kebun'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerToUser,
            tooltip: 'Posisi saya',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _zoomToAllBlocks,
            tooltip: 'Semua blok',
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              // Show layer selector
              _showLayerSelector();
            },
            tooltip: 'Layer peta',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_mapboxMap == null)
            const Center(child: Text('Memuat peta...'))
          else
            MapWidget(
              onMapCreated: _onMapCreated,
              styleUri: _mapService.getMapStyle(),
            ),
          
          // Floating action button for adding inspection
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _selectedBlock != null
                  ? () {
                      Navigator.pushNamed(
                        context,
                        '/inspection-form',
                        arguments: {
                          'blockId': _selectedBlock!.id,
                          'blockName': _selectedBlock!.name,
                        },
                      );
                    }
                  : null,
              icon: const Icon(Icons.add_location),
              label: const Text('Inspeksi di sini'),
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
          ),
          
          // Following user indicator
          if (_isFollowingUser)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Mengikuti', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLayerSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.map),
              title: Text('Pilih tampilan peta'),
              enabled: false,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.satellite),
              title: const Text('Satelit'),
              onTap: () {
                _mapboxMap?.loadStyleUri('mapbox://styles/mapbox/satellite-streets-v12');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.terrain),
              title: const Text('Medan'),
              onTap: () {
                _mapboxMap?.loadStyleUri('mapbox://styles/mapbox/outdoors-v12');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.streetview),
              title: const Text('Jalan'),
              onTap: () {
                _mapboxMap?.loadStyleUri('mapbox://styles/mapbox/streets-v12');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}