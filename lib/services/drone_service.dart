import 'dart:io';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class DroneService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.opa-app.com/v1';
  WebSocketChannel? _wsChannel;
  
  Stream<dynamic>? _telemetryStream;
  Stream<dynamic>? _videoStream;

  Future<void> connectDrone(String droneId) async {
    final token = await _getToken();
    
    _wsChannel = IOWebSocketChannel.connect(
      'wss://api.opa-app.com/drone',
      headers: {'Authorization': 'Bearer $token'},
    );
    
    _wsChannel!.sink.add({
      'event': 'drone:connect',
      'data': {'droneId': droneId},
    });
    
    _telemetryStream = _wsChannel!.stream
        .where((data) => data['event'] == 'drone:telemetry')
        .map((data) => data['data']);
    
    _videoStream = _wsChannel!.stream
        .where((data) => data['event'] == 'drone:frame')
        .map((data) => data['data']);
  }

  Future<void> startMission(String missionId) async {
    _wsChannel!.sink.add({
      'event': 'drone:start-stream',
      'data': {'missionId': missionId},
    });
  }

  Future<void> stopMission(String streamId) async {
    _wsChannel!.sink.add({
      'event': 'drone:stop-stream',
      'data': {'streamId': streamId},
    });
  }

  Future<Map<String, dynamic>> uploadDroneImages(
    List<File> images,
    Map<String, dynamic> flightData,
    Function(int sent, int total)? onProgress,
  ) async {
    final token = await _getToken();
    final formData = FormData();
    
    for (var i = 0; i < images.length; i++) {
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(images[i].path),
        ),
      );
    }
    
    formData.fields.add(MapEntry('flightData', flightData.toString()));
    
    final response = await _dio.post(
      '$_baseUrl/drone/upload',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
      ),
      onSendProgress: onProgress,
    );
    
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getMissions({int limit = 10, int offset = 0}) async {
    final token = await _getToken();
    
    final response = await _dio.get(
      '$_baseUrl/drone/missions',
      queryParameters: {'limit': limit, 'offset': offset},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> getMissionDetails(String missionId) async {
    final token = await _getToken();
    
    final response = await _dio.get(
      '$_baseUrl/drone/missions/$missionId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return response.data;
  }

  Future<Map<String, dynamic>> getMissionReport(String missionId) async {
    final token = await _getToken();
    
    final response = await _dio.get(
      '$_baseUrl/drone/missions/$missionId/report',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return response.data;
  }

  Future<Map<String, dynamic>> autoScheduleMission() async {
    final token = await _getToken();
    
    final response = await _dio.post(
      '$_baseUrl/drone/auto-schedule',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    return response.data;
  }

  Stream<dynamic> get telemetryStream => _telemetryStream ?? const Stream.empty();
  Stream<dynamic> get videoStream => _videoStream ?? const Stream.empty();
  
  void disconnect() {
    _wsChannel?.sink.close();
  }

  Future<String?> _getToken() async {
    // Implement token retrieval
    return '';
  }
}