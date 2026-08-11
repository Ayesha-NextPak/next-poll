// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:next_poll/Features/AuthScreen/auth_services.dart';
import 'package:next_poll/Features/AuthScreen/signin_screen.dart';
import 'package:next_poll/Features/HomeScreens/show_polls.dart';
import 'package:next_poll/main.dart' show appOpenAdManager;
import 'package:page_transition/page_transition.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Wait for the splash to be visible for at least 2 seconds, giving the
    // App Open Ad (loaded in main()) time to arrive from the network.
    await Future.delayed(const Duration(seconds: 2));

    // Show the App Open Ad now.  Navigation is performed inside [onComplete]
    // so it always fires – whether the ad was shown, skipped, or failed.
    appOpenAdManager.showAdIfAvailable(
      onComplete: _navigateToNextScreen,
    );
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    try {
      final bool isLoggedIn = await AuthServices.userLogin();

      Navigator.pushAndRemoveUntil(
        context,
        PageTransition(
          child: isLoggedIn ? const PollScreen() : const SignInScreen(),
          type: PageTransitionType.fade,
        ),
        (route) => false,
      );
    } catch (e) {
      log('SplashScreen: error checking login status: $e');
      Navigator.pushAndRemoveUntil(
        context,
        PageTransition(
          child: const SignInScreen(),
          type: PageTransitionType.fade,
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/splash_screen_image.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
