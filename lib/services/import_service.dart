import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ImportService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';

  Future<void> downloadTemplate(String type) async {
    final token = await _getToken();
    
    final response = await _dio.get(
      '$_baseUrl/import/template',
      queryParameters: {'type': type},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    
    final directory = await getDownloadsDirectory();
    final filename = 'template_import_$type.xlsx';
    final file = File('${directory!.path}/$filename');
    await file.writeAsBytes(response.data);
    
    await OpenFile.open(file.path);
  }

  Future<ImportResult> importFile(
    PlatformFile file,
    String type, {
    Function(double progress)? onProgress,
  }) async {
    final token = await _getToken();
    final estateId = await _getEstateId();
    
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path!),
      'estateId': estateId,
    });
    
    String endpoint;
    switch (type) {
      case 'harvest':
        endpoint = '$_baseUrl/import/harvest';
        break;
      case 'blocks':
        endpoint = '$_baseUrl/import/blocks';
        break;
      case 'trees':
        endpoint = '$_baseUrl/import/trees';
        break;
      default:
        throw Exception('Invalid import type');
    }
    
    final response = await _dio.post(
      endpoint,
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
      ),
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) {
          onProgress(sent / total);
        }
      },
    );
    
    return ImportResult.fromJson(response.data);
  }

  Future<String?> _getToken() async {
    // Implement token retrieval
    return '';
  }

  Future<String?> _getEstateId() async {
    // Implement estate ID retrieval
    return '';
  }
}

class ImportResult {
  final int total;
  final int success;
  final int failed;
  final List<Map<String, dynamic>> errors;
  final List<String> importedIds;

  ImportResult({
    required this.total,
    required this.success,
    required this.failed,
    required this.errors,
    required this.importedIds,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      total: json['total'],
      success: json['success'],
      failed: json['failed'],
      errors: List<Map<String, dynamic>>.from(json['errors'] ?? []),
      importedIds: List<String>.from(json['importedIds'] ?? []),
    );
  }
}