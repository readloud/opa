import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opa_app/services/ml_service.dart';

class PestDetectionScreen extends ConsumerStatefulWidget {
  const PestDetectionScreen({super.key});

  @override
  ConsumerState<PestDetectionScreen> createState() => _PestDetectionScreenState();
}

class _PestDetectionScreenState extends ConsumerState<PestDetectionScreen> {
  final MlService _mlService = MlService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  PestDetectionResult? _detectionResult;
  bool _isDetecting = false;
  String? _errorMessage;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _detectionResult = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _detectionResult = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _detectPest() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isDetecting = true;
      _errorMessage = null;
    });
    
    try {
      final result = await _mlService.detectPest(_selectedImage!);
      setState(() {
        _detectionResult = result;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deteksi selesai: ${result.detections[0].pestName}'),
          backgroundColor: result.detections[0].pestName.contains('Healthy') 
              ? Colors.green 
              : Colors.orange,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mendeteksi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deteksi Hama Sawit'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker
            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Tap untuk mengambil foto',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'foto daun atau batang yang terserang',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedImage == null || _isDetecting ? null : _detectPest,
                    icon: _isDetecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics),
                    label: Text(_isDetecting ? 'Mendeteksi...' : 'Deteksi Hama'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedImage != null && !_isDetecting
                        ? () {
                            setState(() {
                              _selectedImage = null;
                              _detectionResult = null;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.clear),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
            
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!)),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Detection results
            if (_detectionResult != null)
              _buildDetectionResult(_detectionResult!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionResult(PestDetectionResult result) {
    final topDetection = result.detections[0];
    final isHealthy = topDetection.pestName == 'Healthy - No Pest';
    
    return Column(
      children: [
        const SizedBox(height: 24),
        Card(
          color: isHealthy ? Colors.green.shade50 : Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isHealthy ? Icons.health_and_safety : Icons.bug_report,
                      size: 40,
                      color: isHealthy ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topDetection.pestName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isHealthy ? Colors.green : Colors.orange.shade800,
                            ),
                          ),
                          Text(
                            'Confidence: ${(topDetection.confidence * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(topDetection.severity),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        topDetection.severity,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                
                if (!isHealthy) ...[
                  const Divider(),
                  _buildRecommendation(result.recommendation),
                ],
              ],
            ),
          ),
        ),
        
        // All detections list
        const SizedBox(height: 16),
        const Text(
          'Semua Deteksi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...result.detections
            .where((d) => d.confidence > 0.1)
            .map((detection) => Card(
                child: ListTile(
                  leading: Icon(
                    detection.pestName.contains('Healthy') 
                        ? Icons.health_and_safety 
                        : Icons.bug_report,
                    color: _getConfidenceColor(detection.confidence),
                  ),
                  title: Text(detection.pestName),
                  trailing: Text(
                    '${(detection.confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getConfidenceColor(detection.confidence),
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildRecommendation(Recommendation rec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rekomendasi Tindakan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildRecommendationItem(Icons.build, 'Tindakan', rec.action),
        const SizedBox(height: 8),
        _buildRecommendationItem(Icons.science, 'Pestisida', rec.pesticide),
        const SizedBox(height: 8),
        _buildRecommendationItem(Icons.note_alt, 'Catatan', rec.note),
      ],
    );
  }

  Widget _buildRecommendationItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'HIGH': return Colors.red;
      case 'MEDIUM': return Colors.orange;
      default: return Colors.green;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.4) return Colors.orange;
    return Colors.red;
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }
}