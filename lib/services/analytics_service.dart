import 'package:dio/dio.dart';

class AnalyticsService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';

  Future<Map<String, dynamic>> getDashboardStats(DateTime startDate, DateTime endDate) async {
    final token = await _getToken();
    final estateId = await _getEstateId();
    
    final response = await _dio.get(
      '$_baseUrl/analytics/dashboard',
      queryParameters: {
        'estateId': estateId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return response.data;
  }

  Future<Map<String, dynamic>> getRealtimeStats() async {
    final token = await _getToken();
    final estateId = await _getEstateId();
    
    final response = await _dio.get(
      '$_baseUrl/analytics/realtime',
      queryParameters: {'estateId': estateId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return response.data;
  }

  Future<String?> _getToken() async {
    // Implement token retrieval
    return '';
  }

  Future<String?> _getEstateId() async {
    // Implement estate ID retrieval from user profile
    return '';
  }
}