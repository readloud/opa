import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:opa_app/presentation/providers/notification_provider.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreNotifications();
      }
    });
  }

  Future<void> _loadNotifications() async {
    await ref.read(notificationProvider.notifier).loadNotifications();
  }

  Future<void> _loadMoreNotifications() async {
    await ref.read(notificationProvider.notifier).loadMore();
  }

  Future<void> _markAsRead(String id) async {
    await ref.read(notificationProvider.notifier).markAsRead(id);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationProvider);
    final isLoading = ref.watch(notificationLoadingProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationProvider.notifier).markAllAsRead();
            },
            child: const Text('Tandai semua', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: notifications.isEmpty && !isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Tidak ada notifikasi', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: notifications.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                final notification = notifications[index];
                final isRead = notification['isRead'] as bool;
                
                return Dismissible(
                  key: Key(notification['id']),
                  background: Container(color: Colors.red),
                  onDismissed: (direction) async {
                    await _markAsRead(notification['id']);
                  },
                  child: Container(
                    color: isRead ? Colors.white : Colors.green.shade50,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getTypeColor(notification['type']),
                        child: Icon(_getTypeIcon(notification['type']), color: Colors.white),
                      ),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification['body']),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy HH:mm').format(
                              DateTime.parse(notification['createdAt']),
                            ),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!isRead) {
                          _markAsRead(notification['id']);
                        }
                        _handleNotificationTap(notification);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'task':
        return Icons.assignment;
      case 'reminder':
        return Icons.alarm;
      case 'sync':
        return Icons.sync;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'task':
        return Colors.blue;
      case 'reminder':
        return Colors.orange;
      case 'sync':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'];
    final data = notification['data'] as Map?;
    
    if (type == 'task' && data != null) {
      final taskId = data['taskId'];
      Navigator.pushNamed(context, '/task-detail', arguments: taskId);
    }
  }
}