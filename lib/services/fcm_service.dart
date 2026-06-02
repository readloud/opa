import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:opa_app/services/websocket_service.dart';
import 'package:opa_app/services/notification_api_service.dart';

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final NotificationApiService _apiService = NotificationApiService();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Request permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    print('User granted permission: ${settings.authorizationStatus}');
    
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'opa_tasks',
      'OPA Tasks',
      description: 'Notifikasi untuk tugas lapangan',
      importance: Importance.high,
      playSound: true,
    );
    
    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // Get token and register to backend
    await _registerDeviceToken();
    
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle messages when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Handle initial message when app is opened from terminated state
    final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    
    _isInitialized = true;
  }

  Future<void> _registerDeviceToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      
      // Determine device type
      String deviceType = '';
      if (Theme.of(WidgetsBinding.instance.context).platform == TargetPlatform.iOS) {
        deviceType = 'ios';
      } else if (Theme.of(WidgetsBinding.instance.context).platform == TargetPlatform.android) {
        deviceType = 'android';
      } else {
        deviceType = 'web';
      }
      
      await _apiService.registerToken(token, deviceType);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    
    final title = message.notification?.title ?? 'OPA Notification';
    final body = message.notification?.body ?? '';
    
    // Show local notification
    await _showLocalNotification(title, body, message.data);
    
    // Update UI via provider
    if (message.data['type'] == 'task') {
      // Refresh task list
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('Message opened app!');
    _handleMessage(message);
  }

  void _handleMessage(RemoteMessage message) {
    final type = message.data['type'];
    final taskId = message.data['taskId'];
    
    if (type == 'task' && taskId != null) {
      // Navigate to task detail
      // Use navigator key to push screen
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Parse payload and navigate
      print('Notification tapped: $payload');
    }
  }

  Future<void> _showLocalNotification(String title, String body, Map<String, String> data) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'opa_tasks',
      'OPA Tasks',
      channelDescription: 'Notifikasi untuk tugas lapangan',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data.toString(),
    );
  }

  Future<void> deleteToken() async {
    await _firebaseMessaging.deleteToken();
  }
}