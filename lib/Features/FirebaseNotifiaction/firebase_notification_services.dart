// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseNotificationServices {
  FirebaseMessaging messages = FirebaseMessaging.instance;

  Future<void> setupInteractMessage(BuildContext context) async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {}
    FirebaseMessaging.onMessageOpenedApp.listen((event) {});
  }

  Future<String> getDeviceToken() async {
    String? token = await messages.getToken();

    messages.onTokenRefresh.listen((event) {
      token = event;
    });
    return token!;
  }

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize local notifications
  Future<void> initLocalNotifications() async {
    var androidInitialize = const AndroidInitializationSettings('app_icon');
    var initializationSettings =
        InitializationSettings(android: androidInitialize);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Request notification permissions
  void requestNotificationPermissions() async {
    NotificationSettings settings = await messages.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log("User granted Permission");
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      log("User granted Provisional Permission");
    }
  }

  // Show notification when app is in the foreground
  Future<void> foregroundMessage() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        log('Message received: ${message.notification!.title}');

        // Show local notification
        _showLocalNotification(message.notification!);
      }
    });
  }

  // Show local notification using flutter_local_notifications
  Future<void> _showLocalNotification(RemoteNotification message) async {
    var androidDetails = const AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      channelDescription: 'description',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_launcher',
    );

    var platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      message.title,
      message.body,
      platformDetails,
    );
  }
}
