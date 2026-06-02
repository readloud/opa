import 'package:flutter/material.dart';
import 'package:opa_app/services/image_upload_service.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(List<String> imageUrls) onImagesUploaded;
  final int maxImages;
  final String folder;
  final List<String> initialImages;

  const ImagePickerWidget({
    super.key,
    required this.onImagesUploaded,
    this.maxImages = 5,
    this.folder = 'inspections',
    this.initialImages = const [],
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImageUploadService _uploadService = ImageUploadService();
  List<String> _imageUrls = [];
  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _imageUrls = List.from(widget.initialImages);
  }

  Future<void> _pickAndUploadImages() async {
    if (_imageUrls.length >= widget.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maksimal ${widget.maxImages} gambar')),
      );
      return;
    }

    final remainingSlots = widget.maxImages - _imageUrls.length;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () async {
                Navigator.pop(context);
                await _uploadSingleImage(await _uploadService.pickImageFromCamera());
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(context);
                if (remainingSlots > 1) {
                  final images = await _uploadService.pickMultipleImages();
                  await _uploadMultipleImages(images.take(remainingSlots).toList());
                } else {
                  await _uploadSingleImage(await _uploadService.pickImageFromGallery());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadSingleImage(File imageFile) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final url = await _uploadService.uploadImage(
        imageFile,
        folder: widget.folder,
        onProgress: (sent, total) {
          setState(() {
            _uploadProgress = sent / total;
          });
        },
      );
      
      setState(() {
        _imageUrls.add(url);
      });
      
      widget.onImagesUploaded(_imageUrls);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gambar berhasil diupload')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadMultipleImages(List<File> imageFiles) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final urls = await _uploadService.uploadMultipleImages(
        imageFiles,
        folder: widget.folder,
        onProgress: (completed, total) {
          setState(() {
            _uploadProgress = completed / total;
          });
        },
      );
      
      setState(() {
        _imageUrls.addAll(urls);
      });
      
      widget.onImagesUploaded(_imageUrls);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${urls.length} gambar berhasil diupload')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
    widget.onImagesUploaded(_imageUrls);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        
        if (_isUploading)
          LinearProgressIndicator(value: _uploadProgress),
        
        const SizedBox(height: 8),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _imageUrls.length + (_imageUrls.length < widget.maxImages ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _imageUrls.length) {
              return GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadImages,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                      SizedBox(height: 4),
                      Text('Tambah', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }
            
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrls[index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.white),
                      padding: EdgeInsets.zero,
                      onPressed: () => _removeImage(index),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}