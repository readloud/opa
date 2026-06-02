import 'package:dio/dio.dart';

class NotificationApiService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';

  Future<void> registerToken(String token, String deviceType) async {
    final userToken = await _getUserToken();
    
    await _dio.post(
      '$_baseUrl/notifications/register-token',
      data: {
        'token': token,
        'deviceType': deviceType,
      },
      options: Options(
        headers: {'Authorization': 'Bearer $userToken'},
      ),
    );
  }

  Future<void> unregisterToken(String token) async {
    final userToken = await _getUserToken();
    
    await _dio.post(
      '$_baseUrl/notifications/unregister-token',
      data: {'token': token},
      options: Options(
        headers: {'Authorization': 'Bearer $userToken'},
      ),
    );
  }

  Future<List<dynamic>> getNotifications({int limit = 50, int offset = 0}) async {
    final userToken = await _getUserToken();
    
    final response = await _dio.get(
      '$_baseUrl/notifications',
      queryParameters: {'limit': limit, 'offset': offset},
      options: Options(headers: {'Authorization': 'Bearer $userToken'}),
    );
    
    return response.data;
  }

  Future<int> getUnreadCount() async {
    final userToken = await _getUserToken();
    
    final response = await _dio.get(
      '$_baseUrl/notifications/unread-count',
      options: Options(headers: {'Authorization': 'Bearer $userToken'}),
    );
    
    return response.data['count'];
  }

  Future<void> markAsRead(String notificationId) async {
    final userToken = await _getUserToken();
    
    await _dio.patch(
      '$_baseUrl/notifications/$notificationId/read',
      options: Options(headers: {'Authorization': 'Bearer $userToken'}),
    );
  }

  Future<String?> _getUserToken() async {
    // Implement token retrieval
    return '';
  }
}