import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:http_parser/http_parser.dart';

class ImageUploadService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';

  Future<File> compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return imageFile;
    
    // Resize to max 1200px
    final resizedImage = img.copyResize(image, width: 1200);
    
    // Compress with quality 80%
    final compressedBytes = img.encodeJpg(resizedImage, quality: 80);
    
    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await compressedFile.writeAsBytes(compressedBytes);
    
    return compressedFile;
  }

  Future<String> uploadImage(
    File imageFile, {
    String? folder,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      // Compress first
      final compressedFile = await compressImage(imageFile);
      
      final token = await _getToken();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          compressedFile.path,
          filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });
      
      final response = await _dio.post(
        '$_baseUrl/storage/upload',
        data: formData,
        queryParameters: folder != null ? {'folder': folder} : null,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          contentType: 'multipart/form-data',
        ),
        onSendProgress: onProgress,
      );
      
      // Delete temp file
      await compressedFile.delete();
      
      return response.data['url'];
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles, {
    String? folder,
    Function(int completed, int total)? onProgress,
  }) async {
    final List<String> urls = [];
    int completed = 0;
    
    for (final file in imageFiles) {
      final url = await uploadImage(file, folder: folder);
      urls.add(url);
      completed++;
      onProgress?.call(completed, imageFiles.length);
    }
    
    return urls;
  }

  Future<File> pickImageFromCamera() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) throw Exception('No image selected');
    return File(image.path);
  }

  Future<File> pickImageFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) throw Exception('No image selected');
    return File(image.path);
  }

  Future<List<File>> pickMultipleImages() async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 85);
    return images.map((xfile) => File(xfile.path)).toList();
  }

  Future<void> deleteImage(String imageUrl) async {
    final token = await _getToken();
    final encodedUrl = Uri.encodeComponent(imageUrl);
    
    await _dio.delete(
      '$_baseUrl/storage/$encodedUrl',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<String?> _getToken() async {
    // Implement token retrieval from secure storage
    return '';
  }
}