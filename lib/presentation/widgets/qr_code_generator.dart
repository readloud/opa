import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:opa_app/services/qr_service.dart';

class QrCodeGenerator extends StatefulWidget {
  final String treeId;
  final String treeCode;

  const QrCodeGenerator({
    super.key,
    required this.treeId,
    required this.treeCode,
  });

  @override
  State<QrCodeGenerator> createState() => _QrCodeGeneratorState();
}

class _QrCodeGeneratorState extends State<QrCodeGenerator> {
  final QrService _qrService = QrService();
  String? _qrCodeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    final qrData = await _qrService.getTreeQrCode(widget.treeId);
    setState(() {
      _qrCodeData = qrData;
      _isLoading = false;
    });
  }

  Future<void> _printQrCode() async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = await _qrService.generateQrCodePdf(widget.treeId);
        return pdf;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_qrCodeData != null)
              QrImageView(
                data: _qrCodeData!,
                version: QrVersions.auto,
                size: 200,
                gapless: false,
                foregroundColor: const Color(0xFF2E7D32),
              )
            else
              Container(
                width: 200,
                height: 200,
                color: Colors.grey.shade200,
                child: const Icon(Icons.qr_code, size: 100, color: Colors.grey),
              ),
            
            const SizedBox(height: 16),
            
            Text(
              widget.treeCode,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _printQrCode,
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // Share QR code
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Bagikan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}