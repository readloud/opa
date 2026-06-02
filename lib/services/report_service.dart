import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ReportService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';

  Future<List<Map<String, dynamic>>> getReportPreview(
    String type,
    String estateId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final response = await _dio.get(
      '$_baseUrl/reports/$type/preview',
      queryParameters: {
        'estateId': estateId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
      options: Options(headers: {
        'Authorization': 'Bearer ${await _getToken()}',
      }),
    );
    
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<File> exportReport(
    String type,
    String estateId,
    DateTime startDate,
    DateTime endDate,
    String format,
  ) async {
    final response = await _dio.get(
      '$_baseUrl/reports/$type/export',
      queryParameters: {
        'estateId': estateId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'format': format,
      },
      options: Options(
        headers: {'Authorization': 'Bearer ${await _getToken()}'},
        responseType: ResponseType.bytes,
      ),
    );
    
    final directory = await getDownloadsDirectory();
    final filename = 'laporan_${DateTime.now().millisecondsSinceEpoch}.$format';
    final file = File('${directory!.path}/$filename');
    await file.writeAsBytes(response.data);
    
    return file;
  }

  Future<String> _getToken() async {
    // Ambil token dari secure storage
    return '';
  }
}