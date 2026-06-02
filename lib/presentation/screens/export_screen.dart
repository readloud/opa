import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_file/open_file.dart';
import 'package:opa_app/services/export_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final ExportService _exportService = ExportService();
  
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  String _exportType = 'harvest';
  bool _isExporting = false;
  double _exportProgress = 0;

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0;
    });
    
    try {
      final file = await _exportService.exportToExcel(
        _exportType,
        _dateRange.start,
        _dateRange.end,
        onProgress: (progress) {
          setState(() {
            _exportProgress = progress;
          });
        },
      );
      
      await OpenFile.open(file.path);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File tersimpan di: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekspor Data'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export type selection
            const Text(
              'Jenis Laporan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'harvest', label: Text('Panen')),
                ButtonSegment(value: 'complete', label: Text('Lengkap')),
              ],
              selected: {_exportType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _exportType = newSelection.first;
                });
              },
            ),
            
            const SizedBox(height: 24),
            
            // Date range
            const Text(
              'Periode Laporan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      '${_formatDate(_dateRange.start)} - ${_formatDate(_dateRange.end)}',
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Format info
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File akan diekspor dalam format Excel (.xlsx) dengan 6 sheet: Ringkasan, Data Harian, Per Blok, Detail Lengkap, Grafik, dan Info',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Preview section
            const Text(
              'Preview Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildPreview(),
            ),
            
            const SizedBox(height: 32),
            
            // Export button with progress
            if (_isExporting)
              Column(
                children: [
                  LinearProgressIndicator(value: _exportProgress),
                  const SizedBox(height: 8),
                  Text('Mengekspor... ${(_exportProgress * 100).toStringAsFixed(0)}%'),
                ],
              )
            else
              ElevatedButton(
                onPressed: _exportData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Ekspor ke Excel'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // Show preview based on export type
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.preview, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Preview akan muncul setelah filter dipilih'),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}