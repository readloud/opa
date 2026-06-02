import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opa_app/services/qr_service.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final QrService _qrService = QrService();
  
  bool _isScanning = true;
  String? _scannedData;
  Map<String, dynamic>? _treeData;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (!_isScanning) return;
    
    final String? code = capture.barcodes.first.rawValue;
    if (code == null) return;
    
    setState(() {
      _isScanning = false;
      _scannedData = code;
    });
    
    try {
      final result = await _qrService.scanQrCode(code);
      setState(() {
        _treeData = result;
      });
      
      if (result['type'] == 'tree') {
        _showTreeDetailDialog(result['data']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses QR Code: $e')),
      );
      setState(() {
        _isScanning = true;
      });
    }
  }

  void _showTreeDetailDialog(Map<String, dynamic> tree) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TreeDetailSheet(tree: tree),
    ).then((_) {
      setState(() {
        _isScanning = true;
        _scannedData = null;
        _treeData = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code Pohon'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_scannerController.torchState == TorchState.off
                ? Icons.flash_off
                : Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: Icon(_scannerController.cameraDirection == CameraDirection.back
                ? Icons.camera_front
                : Icons.camera_rear),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleScan,
          ),
          
          // Scanning overlay
          if (_isScanning)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(50),
              child: const Center(
                child: Text(
                  'Arahkan kamera ke QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          
          // Loading indicator
          if (!_isScanning && _treeData == null)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

class TreeDetailSheet extends StatelessWidget {
  final Map<String, dynamic> tree;

  const TreeDetailSheet({super.key, required this.tree});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.park, color: Colors.green.shade800),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tree['treeCode'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      tree['block']['name'] ?? 'Unknown Block',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tree info
          _buildInfoRow('Varietas', tree['variety'] ?? '-'),
          _buildInfoRow('Tanggal Tanam', tree['plantingDate'] != null
              ? DateTime.parse(tree['plantingDate']).toLocal().toString().split(' ')[0]
              : '-'),
          _buildInfoRow('Lokasi', 
              tree['latitude'] != null && tree['longitude'] != null
                  ? '${tree['latitude'].toStringAsFixed(6)}, ${tree['longitude'].toStringAsFixed(6)}'
                  : 'Tidak tersedia'),
          
          const Divider(),
          
          // Quick actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.visibility,
                label: 'Inspeksi',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/inspection-form', arguments: {
                    'treeId': tree['id'],
                    'treeCode': tree['treeCode'],
                  });
                },
              ),
              _buildActionButton(
                icon: Icons.agriculture,
                label: 'Panen',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/harvest-form', arguments: {
                    'treeId': tree['id'],
                    'treeCode': tree['treeCode'],
                  });
                },
              ),
              _buildActionButton(
                icon: Icons.history,
                label: 'Riwayat',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/tree-history', arguments: tree['id']);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}