import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:opa_app/services/report_service.dart';
import 'package:opa_app/presentation/widgets/custom_button.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _selectedEstateId = '';
  String _selectedReportType = 'harvest';
  String _selectedFormat = 'pdf';
  bool _isLoading = false;
  List<Map<String, dynamic>> _previewData = [];

  @override
  void initState() {
    super.initState();
    _loadEstates();
  }

  Future<void> _loadEstates() async {
    final estates = await ref.read(estateRepositoryProvider).getEstates();
    if (estates.isNotEmpty && _selectedEstateId.isEmpty) {
      setState(() {
        _selectedEstateId = estates.first.id;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      await _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await ref.read(reportServiceProvider).getReportPreview(
        _selectedReportType,
        _selectedEstateId,
        _dateRange.start,
        _dateRange.end,
      );
      setState(() {
        _previewData = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat preview: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportReport() async {
    setState(() => _isLoading = true);
    
    try {
      final file = await ref.read(reportServiceProvider).exportReport(
        _selectedReportType,
        _selectedEstateId,
        _dateRange.start,
        _dateRange.end,
        _selectedFormat,
      );
      
      await OpenFile.open(file.path);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Laporan tersimpan di: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Ekspor'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report type
                const Text('Jenis Laporan', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'harvest', label: Text('Panen')),
                    ButtonSegment(value: 'inspection', label: Text('Inspeksi')),
                    ButtonSegment(value: 'fertilization', label: Text('Pemupukan')),
                  ],
                  selected: {_selectedReportType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedReportType = newSelection.first;
                    });
                    _loadPreview();
                  },
                ),
                const SizedBox(height: 16),
                
                // Date range
                const Text('Rentang Tanggal', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '${_dateRange.start.toLocal().toString().split(' ')[0]} - ${_dateRange.end.toLocal().toString().split(' ')[0]}',
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Format selection
                const Text('Format', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('PDF'),
                        selected: _selectedFormat == 'pdf',
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFormat = 'pdf');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('CSV'),
                        selected: _selectedFormat == 'csv',
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFormat = 'csv');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Excel'),
                        selected: _selectedFormat == 'excel',
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFormat = 'excel');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Export button
                CustomButton(
                  onPressed: _exportReport,
                  isLoading: _isLoading,
                  text: 'Ekspor Laporan',
                  icon: Icons.download,
                ),
              ],
            ),
          ),
          
          // Preview section
          Expanded(
            child: _isLoading && _previewData.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _previewData.isEmpty
                    ? const Center(child: Text('Tidak ada data untuk periode ini'))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Preview Laporan (${_previewData.length} data)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _previewData.length,
                              itemBuilder: (context, index) {
                                final item = _previewData[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: ListTile(
                                    title: Text(item['block'] ?? ''),
                                    subtitle: Text(item['date'] ?? ''),
                                    trailing: Text(
                                      item['tonase']?.toString() ?? item['condition'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}