import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opa_app/domain/entities/inspection.dart';
import 'package:opa_app/domain/entities/user.dart';
import 'package:opa_app/presentation/providers/auth_provider.dart';
import 'package:opa_app/presentation/providers/inspection_provider.dart';
import 'package:opa_app/services/image_picker_service.dart';

class InspectionFormScreen extends ConsumerStatefulWidget {
  final String blockId;
  final String blockName;

  const InspectionFormScreen({
    super.key,
    required this.blockId,
    required this.blockName,
  });

  @override
  ConsumerState<InspectionFormScreen> createState() =>
      _InspectionFormScreenState();
}

class _InspectionFormScreenState extends ConsumerState<InspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _treeIdController = TextEditingController();
  final _notesController = TextEditingController();

  TreeCondition? _selectedCondition;
  File? _imageFile;
  String? _localImagePath;
  bool _isLoading = false;

  final ImagePickerService _imagePicker = ImagePickerService();

  @override
  void dispose() {
    _treeIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    await _imagePicker.showImageSourceDialog(context, (image) {
      setState(() {
        _imageFile = image;
        _localImagePath = image.path;
      });
    });
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _localImagePath = null;
    });
  }

  Future<void> _submitInspection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kondisi pohon')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = ref.read(userProvider);
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login kembali')),
      );
      return;
    }

    // Upload image if exists (simplified - actual upload to backend)
    String? uploadedImageUrl;
    if (_imageFile != null) {
      // TODO: Implement image upload to S3/storage
      // uploadedImageUrl = await _uploadImage(_imageFile!);
      uploadedImageUrl = _localImagePath; // Placeholder
    }

    final inspection = Inspection(
      blockId: widget.blockId,
      blockName: widget.blockName,
      treeId: _treeIdController.text.trim().isEmpty
          ? null
          : _treeIdController.text.trim(),
      condition: _selectedCondition!,
      notes: _notesController.text.trim(),
      photoUrl: uploadedImageUrl,
      latitude: null, // TODO: Get current location
      longitude: null,
      createdBy: user.id,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(inspectionRepositoryProvider).saveInspection(inspection);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspeksi berhasil disimpan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inspeksi Pohon - ${widget.blockName}'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Block info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.blockName} (${widget.blockId})',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tree ID (optional)
            TextFormField(
              controller: _treeIdController,
              decoration: const InputDecoration(
                labelText: 'ID Pohon',
                hintText: 'Contoh: TREE-001 (opsional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.park),
              ),
            ),

            const SizedBox(height: 16),

            // Tree condition radio buttons
            const Text(
              'Kondisi Pohon *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TreeCondition.values.map((condition) {
                final isSelected = _selectedCondition == condition;
                return FilterChip(
                  label: Text(condition.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCondition = condition;
                      }
                    });
                  },
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: condition.color.withOpacity(0.2),
                  checkmarkColor: condition.color,
                  labelStyle: TextStyle(
                    color: isSelected ? condition.color : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Photo picker
            const Text(
              'Foto',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _imageFile != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: _removeImage,
                            ),
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: _pickImage,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap untuk mengambil foto',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                hintText: 'Tuliskan catatan tambahan...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitInspection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Inspeksi'),
            ),
          ],
        ),
      ),
    );
  }
}