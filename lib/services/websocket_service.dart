import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opa_app/services/token_service.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._();
  
  WebSocketService._();
  
  IO.Socket? _socket;
  final Map<String, List<Function>> _listeners = {};
  bool _isConnected = false;
  
  Future<void> connect() async {
    if (_socket != null && _isConnected) return;
    
    final token = await TokenService.getToken();
    if (token == null) return;
    
    _socket = IO.io('https://api.opa-app.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'path': '/sync',
      'extraHeaders': {
        'Authorization': 'Bearer $token',
      },
      'auth': {
        'token': token,
      },
    });
    
    _socket!.connect();
    
    _socket!.onConnect((_) {
      print('WebSocket connected');
      _isConnected = true;
      
      // Subscribe to tasks
      _socket!.emit('subscribe:tasks', {});
      
      // Replay pending listeners
      _replayListeners();
    });
    
    _socket!.onDisconnect((_) {
      print('WebSocket disconnected');
      _isConnected = false;
    });
    
    _socket!.onError((error) {
      print('WebSocket error: $error');
    });
    
    // Handle events
    _socket!.on('task:new', (data) {
      _notifyListeners('task:new', data);
    });
    
    _socket!.on('task:updated', (data) {
      _notifyListeners('task:updated', data);
    });
    
    _socket!.on('sync:completed', (data) {
      _notifyListeners('sync:completed', data);
    });
    
    _socket!.on('sync:new-data', (data) {
      _notifyListeners('sync:new-data', data);
    });
    
    _socket!.on('notification', (data) {
      _notifyListeners('notification', data);
    });
    
    _socket!.on('user:location-update', (data) {
      _notifyListeners('user:location-update', data);
    });
  }
  
  void disconnect() {
    if (_socket != null && _isConnected) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }
  
  void on(String event, Function(dynamic) callback) {
    if (!_listeners.containsKey(event)) {
      _listeners[event] = [];
    }
    _listeners[event]!.add(callback);
  }
  
  void off(String event, {Function? callback}) {
    if (callback == null) {
      _listeners.remove(event);
    } else if (_listeners.containsKey(event)) {
      _listeners[event]!.remove(callback);
    }
  }
  
  void emit(String event, dynamic data) {
    if (_isConnected && _socket != null) {
      _socket!.emit(event, data);
    }
  }
  
  Future<void> syncHarvest(Map<String, dynamic> harvestData) async {
    emit('sync:harvest', harvestData);
  }
  
  Future<void> updateTask(String taskId, String status, String userId) async {
    emit('task:update', {
      'taskId': taskId,
      'status': status,
      'completedBy': userId,
    });
  }
  
  Future<void> selectBlock(String blockId) async {
    emit('block:select', {'blockId': blockId});
  }
  
  Future<void> requestSync(String lastSyncTime, {String? entityType}) async {
    emit('sync:request', {
      'lastSyncTime': lastSyncTime,
      'entityType': entityType,
    });
  }
  
  void _notifyListeners(String event, dynamic data) {
    if (_listeners.containsKey(event)) {
      for (var callback in _listeners[event]!) {
        callback(data);
      }
    }
  }
  
  void _replayListeners() {
    // Re-register listeners after reconnect
    _socket!.emit('subscribe:tasks', {});
  }
  
  bool get isConnected => _isConnected;
}

// Provider untuk Riverpod
final webSocketProvider = Provider<WebSocketService>((ref) {
  return WebSocketService.instance;
});