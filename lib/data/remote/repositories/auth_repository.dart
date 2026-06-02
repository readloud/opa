import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:opa_app/domain/entities/user.dart';

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  static const String _tokenKey = 'access_token';
  static const String _userKey = 'user_data';
  static const String _baseUrl = 'https://api.opa-app.com/v1'; // Ganti dengan URL backend

  AuthRepository({
    Dio? dio,
    FlutterSecureStorage? secureStorage,
  }) : _dio = dio ?? Dio(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // Request OTP
  Future<void> requestOtp(String identifier) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/auth/request-otp',
        data: {'identifier': identifier},
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal mengirim OTP: ${response.data['message']}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  // Verify OTP dan login
  Future<User> verifyOtp(String identifier, String otpCode) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/auth/verify-otp',
        data: {'identifier': identifier, 'otp_code': otpCode},
      );

      if (response.statusCode != 200) {
        throw Exception('OTP tidak valid: ${response.data['message']}');
      }

      final data = response.data;
      final token = data['access_token'];
      final userData = data['user'];

      // Save token and user data securely
      await _secureStorage.write(key: _tokenKey, value: token);
      await _secureStorage.write(key: _userKey, value: jsonEncode(userData));

      return User.fromJson(userData);
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  // Get current user from storage
  Future<User?> getCurrentUser() async {
    final userJson = await _secureStorage.read(key: _userKey);
    if (userJson == null) return null;

    try {
      return User.fromJson(jsonDecode(userJson));
    } catch (e) {
      return null;
    }
  }

  // Get token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  // Logout
  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    final user = await getCurrentUser();
    return token != null && user != null;
  }
}