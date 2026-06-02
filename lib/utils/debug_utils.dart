import 'package:flutter/foundation.dart';

class DebugUtils {
  static void log(String message, {String tag = 'OPA'}) {
    if (kDebugMode) {
      print('[$tag] $message');
    }
  }
  
  static void logError(String message, {dynamic error, String tag = 'OPA_ERROR'}) {
    if (kDebugMode) {
      print('[$tag] $message');
      if (error != null) print('Error: $error');
    }
  }
  
  static void logNetworkRequest(String method, String url, dynamic body) {
    if (kDebugMode) {
      print('═══════════════════════════════════════');
      print('📤 REQUEST: $method $url');
      print('📦 BODY: $body');
      print('═══════════════════════════════════════');
    }
  }
  
  static void logNetworkResponse(String method, String url, int statusCode, dynamic data) {
    if (kDebugMode) {
      print('═══════════════════════════════════════');
      print('📥 RESPONSE: $method $url');
      print('📊 STATUS: $statusCode');
      print('📦 DATA: $data');
      print('═══════════════════════════════════════');
    }
  }
  
  static void logDatabase(String operation, String table, dynamic data) {
    if (kDebugMode) {
      print('🗄️ DB: $operation on $table - $data');
    }
  }
}