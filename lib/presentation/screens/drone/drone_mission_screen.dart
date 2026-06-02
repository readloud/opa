import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:opa_app/services/drone_service.dart';

class DroneMissionScreen extends ConsumerStatefulWidget {
  const DroneMissionScreen({super.key});

  @override
  ConsumerState<DroneMissionScreen> createState() => _DroneMissionScreenState();
}

class _DroneMissionScreenState extends ConsumerState<DroneMissionScreen> {
  final DroneService _droneService = DroneService();
  final ImagePicker _picker = ImagePicker();
  
  List<File> _selectedImages = [];
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _connectionStatus;
  
  // Flight parameters
  final _altitudeController = TextEditingController(text: '50');
  final _speedController = TextEditingController(text: '8');
  final _overlapController = TextEditingController(text: '75');
  bool _isThermal = false;

  @override
  void initState() {
    super.initState();
    _connectDrone();
  }

  @override
  void dispose() {
    _droneService.disconnect();
    _altitudeController.dispose();
    _speedController.dispose();
    _overlapController.dispose();
    super.dispose();
  }

  Future<void> _connectDrone() async {
    setState(() => _connectionStatus = 'Connecting...');
    
    try {
      await _droneService.connectDrone('drone_001');
      setState(() => _connectionStatus = 'Connected');
      
      // Listen to telemetry
      _droneService.telemetryStream.listen((telemetry) {
        setState(() {
          _connectionStatus = 'Flying';
        });
      });
    } catch (e) {
      setState(() => _connectionStatus = 'Disconnected');
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    setState(() {
      _selectedImages = images.map((xfile) => File(xfile.path)).toList();
    });
  }

  Future<void> _startMission() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gambar terlebih dahulu')),
      );
      return;
    }
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    
    try {
      final flightData = {
        'flightDate': DateTime.now().toIso8601String(),
        'altitude': double.parse(_altitudeController.text),
        'speed': double.parse(_speedController.text),
        'areaCovered': _calculateArea(),
        'overlap': double.parse(_overlapController.text),
        'isThermal': _isThermal,
        'metadata': {
          'deviceType': 'DJI Phantom 4',
          'pilot': 'Field Operator',
        },
      };
      
      final result = await _droneService.uploadDroneImages(
        _selectedImages,
        flightData,
        onProgress: (sent, total) {
          setState(() {
            _uploadProgress = sent / total;
          });
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Misi berhasil diupload: ${result['id']}')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  double _calculateArea() {
    // Simplified area calculation based on image count
    return _selectedImages.length * 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Misi Drone Baru'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _connectionStatus == 'Connected' || _connectionStatus == 'Flying'
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectionStatus == 'Connected' || _connectionStatus == 'Flying'
                        ? Icons.flight
                        : Icons.flight_off,
                    color: _connectionStatus == 'Connected' || _connectionStatus == 'Flying'
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Drone Status: $_connectionStatus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _connectionStatus == 'Connected' || _connectionStatus == 'Flying'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Flight parameters
            const Text(
              'Parameter Penerbangan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _altitudeController,
              decoration: const InputDecoration(
                labelText: 'Ketinggian (m)',
                border: OutlineInputBorder(),
                suffixText: 'm',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _speedController,
              decoration: const InputDecoration(
                labelText: 'Kecepatan (m/s)',
                border: OutlineInputBorder(),
                suffixText: 'm/s',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _overlapController,
              decoration: const InputDecoration(
                labelText: 'Overlap Gambar (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            
            SwitchListTile(
              title: const Text('Mode Thermal'),
              subtitle: const Text('Aktifkan untuk deteksi water stress'),
              value: _isThermal,
              onChanged: (value) {
                setState(() {
                  _isThermal = value;
                });
              },
              activeColor: const Color(0xFF2E7D32),
            ),
            
            const SizedBox(height: 24),
            
            // Image selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gambar Drone',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Pilih Gambar'),
                ),
              ],
            ),
            
            if (_selectedImages.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(top: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 12),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Upload progress
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Mengupload... ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            
            const SizedBox(height: 24),
            
            // Start mission button
            ElevatedButton(
              onPressed: _isUploading ? null : _startMission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Mulai Misi & Upload'),
            ),
          ],
        ),
      ),
    );
  }
}