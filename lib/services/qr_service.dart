import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class QrService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';

  Future<String> getTreeQrCode(String treeId) async {
    final token = await _getToken();
    
    final response = await _dio.get(
      '$_baseUrl/qrcode/tree/$treeId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    // Extract QR code from HTML response
    final html = response.data as String;
    final match = RegExp(r'src="([^"]+)"').firstMatch(html);
    return match?.group(1) ?? '';
  }

  Future<Map<String, dynamic>> scanQrCode(String qrData) async {
    final token = await _getToken();
    
    final response = await _dio.post(
      '$_baseUrl/qrcode/scan',
      data: {'data': qrData},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return response.data;
  }

  Future<Map<String, dynamic>> getTreeHistory(String treeId) async {
    final token = await _getToken();
    
    final response = await _dio.get(
      '$_baseUrl/qrcode/tree/$treeId/history',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return response.data;
  }

  Future<Uint8List> generateQrCodePdf(String treeId) async {
    final token = await _getToken();
    
    final response = await _dio.get(
      '$_baseUrl/qrcode/batch/$treeId',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    
    return response.data;
  }

  Future<String?> _getToken() async {
    // Implement token retrieval
    return '';
  }
}