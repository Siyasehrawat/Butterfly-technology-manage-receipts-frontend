import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'notification_service.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static String? _fcmToken;
  static String? _currentUserId;

  // Getter for FCM token
  static String? get fcmToken => _fcmToken;

  // Initialize FCM
  static Future<void> initialize() async {
    // Skip FCM initialization on web for now
    if (kIsWeb) {
      debugPrint('FCM not supported on web platform');
      return;
    }

    try {
      // Initialize Firebase with options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Request permission for notifications
      await _requestPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();

      // Configure message handlers
      _configureMessageHandlers();

      debugPrint('FCM Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FCM Service: $e');
    }
  }

  // Set current user ID for token management
  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
    // Send token to backend when user ID is set
    if (_fcmToken != null) {
      NotificationService.sendTokenToBackend(userId);
    }
  }

  // Request notification permissions
  static Future<void> _requestPermission() async {
    if (kIsWeb) return;

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  // Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    if (kIsWeb) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'receipt_reminders', // Channel ID
      'Receipt Reminders', // Channel name
      description: 'Notifications for receipt reminders',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Get FCM token
  static Future<void> _getFCMToken() async {
    if (kIsWeb) return;

    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Send token to backend if user is logged in
      if (_currentUserId != null && _fcmToken != null) {
        NotificationService.sendTokenToBackend(_currentUserId!);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');

        // Send updated token to backend
        if (_currentUserId != null) {
          NotificationService.sendTokenToBackend(_currentUserId!);
        }
      });
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  // Configure message handlers
  static void _configureMessageHandlers() {
    if (kIsWeb) return;

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
      _showLocalNotification(message);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message clicked: ${message.messageId}');
      _handleNotificationTap(message);
    });
  }

  // Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    if (kIsWeb) return;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Handling background message: ${message.messageId}');
  }

  // Show local notification for foreground messages
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'receipt_reminders',
      'Receipt Reminders',
      channelDescription: 'Notifications for receipt reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF7E5EFD),
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Receipt Reminder',
      message.notification?.body ?? 'You have a receipt reminder',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (kIsWeb) return;

    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      _handleNotificationTap(null, data: data);
    }
  }

  // Handle notification tap navigation
  static void _handleNotificationTap(RemoteMessage? message, {Map<String, dynamic>? data}) {
    if (kIsWeb) return;

    final notificationData = data ?? message?.data ?? {};

    // Navigate based on notification data
    if (notificationData.containsKey('receiptId')) {
      // Navigate to receipt details
      // You'll need to implement navigation logic here
      debugPrint('Navigate to receipt: ${notificationData['receiptId']}');
    }
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;

    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;

    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  // Get initial message (when app is opened from notification)
  static Future<RemoteMessage?> getInitialMessage() async {
    if (kIsWeb) return null;

    return await _firebaseMessaging.getInitialMessage();
  }

  // Clear current user (on logout)
  static void clearCurrentUser() {
    if (_currentUserId != null) {
      NotificationService.onUserLogout(_currentUserId!);
    }
    _currentUserId = null;
  }
}
