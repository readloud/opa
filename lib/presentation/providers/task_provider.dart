import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opa_app/services/websocket_service.dart';
import 'package:opa_app/domain/entities/task.dart';

final taskProvider = StateNotifierProvider<TaskNotifier, List<Task>>((ref) {
  final webSocket = ref.read(webSocketProvider);
  return TaskNotifier(webSocket);
});

class TaskNotifier extends StateNotifier<List<Task>> {
  final WebSocketService _webSocket;
  
  TaskNotifier(this._webSocket) : super([]) {
    _setupWebSocketListeners();
  }
  
  void _setupWebSocketListeners() {
    _webSocket.on('task:new', (data) {
      final newTask = Task.fromJson(data['task']);
      state = [newTask, ...state];
    });
    
    _webSocket.on('task:updated', (data) {
      final updatedTaskId = data['taskId'];
      final newStatus = data['status'];
      
      state = state.map((task) {
        if (task.id == updatedTaskId) {
          return task.copyWith(status: newStatus);
        }
        return task;
      }).toList();
    });
    
    _webSocket.on('sync:new-data', (data) {
      if (data['type'] == 'harvest') {
        // Refresh harvest list
        _refreshHarvests();
      }
    });
  }
  
  Future<void> _refreshHarvests() async {
    // Implement refresh logic
  }
  
  void addTask(Task task) {
    state = [task, ...state];
  }
  
  void updateTaskStatus(String taskId, String status) {
    state = state.map((task) {
      if (task.id == taskId) {
        return task.copyWith(status: status);
      }
      return task;
    }).toList();
  }
}