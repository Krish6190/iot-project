import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static const String _backendUrl = 'https://idk-9nf0.onrender.com'; 

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase already initialized');
    }

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _registerDeviceToken(token);
    }

    _firebaseMessaging.onTokenRefresh.listen(_registerDeviceToken);
    FirebaseMessaging.onMessage.listen(_showNotification);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _registerDeviceToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/upload/register-device'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );

      if (response.statusCode != 200) {
        print('Failed to register device token');
      }
    } catch (e) {
      print('Error registering device token: $e');
    }
  }

  static Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'image_upload_channel',
      'Image Upload Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    await showNotification(
      message.notification?.title ?? 'New Image',
      message.notification?.body ?? 'A new image has been uploaded'
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  await NotificationService.showNotification(
    message.notification?.title ?? 'New Image',
    message.notification?.body ?? 'A new image has been uploaded'
  );
}