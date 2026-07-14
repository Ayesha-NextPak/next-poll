import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:next_poll/Features/FirebaseNotifiaction/firebase_notification_services.dart';
import 'package:next_poll/Features/OnBoarding/splash_screen.dart';
import 'package:next_poll/Features/Provider/auth_provider.dart';
import 'package:next_poll/Features/Provider/chat_provider.dart';
import 'package:next_poll/Features/Provider/poll_provider.dart';
import 'package:next_poll/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

FirebaseNotificationServices firebaseNotificationServices =
    FirebaseNotificationServices();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProviderData()),
        ChangeNotifierProvider(create: (_) => PollProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

@pragma('va:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log(message.notification!.title.toString());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    firebaseNotificationServices.requestNotificationPermissions();
    firebaseNotificationServices.foregroundMessage();
    firebaseNotificationServices.setupInteractMessage(context);
    firebaseNotificationServices.getDeviceToken().then((value) {
      log('FcmToken: $value');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange.withValues(alpha: 0.5),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
