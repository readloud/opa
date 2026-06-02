import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opa_app/services/notification_api_service.dart';

final notificationApiProvider = Provider<NotificationApiService>((ref) {
  return NotificationApiService();
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(notificationApiProvider);
  return await api.getUnreadCount();
});

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<Map<String, dynamic>>>((ref) {
  return NotificationNotifier(ref.read(notificationApiProvider));
});

final notificationLoadingProvider = StateProvider<bool>((ref) => false);

class NotificationNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final NotificationApiService _apiService;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoading = false;

  NotificationNotifier(this._apiService) : super([]);

  Future<void> loadNotifications() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _offset = 0;
    
    try {
      final notifications = await _apiService.getNotifications(limit: 20);
      state = List.from(notifications);
      _hasMore = notifications.length == 20;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    _isLoading = true;
    
    try {
      final notifications = await _apiService.getNotifications(
        limit: 20,
        offset: state.length,
      );
      
      if (notifications.isNotEmpty) {
        state = [...state, ...notifications];
      }
      _hasMore = notifications.length == 20;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _apiService.markAsRead(notificationId);
    
    state = state.map((n) {
      if (n['id'] == notificationId) {
        return {...n, 'isRead': true};
      }
      return n;
    }).toList();
    
    // Refresh unread count
    ref.read(unreadCountProvider);
  }

  Future<void> markAllAsRead() async {
    for (var notification in state.where((n) => !n['isRead'])) {
      await _apiService.markAsRead(notification['id']);
    }
    
    state = state.map((n) {
      return {...n, 'isRead': true};
    }).toList();
    
    ref.invalidate(unreadCountProvider);
  }
}