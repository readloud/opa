import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:opa_app/services/import_service.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final ImportService _importService = ImportService();
  
  String _importType = 'harvest';
  FilePickerResult? _selectedFile;
  bool _isUploading = false;
  ImportResult? _importResult;
  double _uploadProgress = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      type: FileType.custom,
    );
    
    if (result != null) {
      setState(() {
        _selectedFile = result;
        _importResult = null;
      });
    }
  }

  Future<void> _downloadTemplate() async {
    await _importService.downloadTemplate(_importType);
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    
    try {
      final result = await _importService.importFile(
        _selectedFile!.files.first,
        _importType,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );
      
      setState(() {
        _importResult = result;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import selesai: ${result.success} berhasil, ${result.failed} gagal',
          ),
          backgroundColor: result.failed > 0 ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal import: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Data'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Import type selection
            const Text(
              'Jenis Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'harvest', label: Text('Data Panen')),
                ButtonSegment(value: 'blocks', label: Text('Data Blok')),
                ButtonSegment(value: 'trees', label: Text('Data Pohon')),
              ],
              selected: {_importType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _importType = newSelection.first;
                  _importResult = null;
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Template download
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.download, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unduh Template',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Gunakan template Excel untuk format yang benar',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _downloadTemplate,
                      child: const Text('Download'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // File picker
            const Text(
              'Pilih File',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickFile,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _selectedFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Tap untuk pilih file',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Format: XLSX, XLS, CSV',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description, size: 40, color: Colors.green),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFile!.files.first.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(_selectedFile!.files.first.size / 1024).toStringAsFixed(2)} KB',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Upload button
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Mengupload... ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                ],
              )
            else
              ElevatedButton(
                onPressed: _selectedFile == null ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Upload & Import'),
              ),
            
            const SizedBox(height: 24),
            
            // Import result
            if (_importResult != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hasil Import',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildResultRow('Total Data', _importResult!.total),
                      _buildResultRow('Berhasil', _importResult!.success, color: Colors.green),
                      _buildResultRow('Gagal', _importResult!.failed, color: Colors.red),
                      
                      if (_importResult!.errors.isNotEmpty) ...[
                        const Divider(),
                        const Text(
                          'Error Details:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          child: ListView.builder(
                            itemCount: _importResult!.errors.length,
                            itemBuilder: (context, index) {
                              final error = _importResult!.errors[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Row ${index + 1}: ${error['error']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, int value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}