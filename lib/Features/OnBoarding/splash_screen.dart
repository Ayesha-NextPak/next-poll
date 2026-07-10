// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:next_poll/Features/AuthScreen/auth_services.dart';
import 'package:next_poll/Features/AuthScreen/signin_screen.dart';
import 'package:next_poll/Features/HomeScreens/show_polls.dart';
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
    callfunction();
  }

  void callfunction() {
    navigateToNextScreen();
  }

  Future<void> navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      bool isLoggedIn = await AuthServices.userLogin();

      Navigator.pushAndRemoveUntil(
        context,
        PageTransition(
          child: isLoggedIn ? const PollScreen() : const SignInScreen(),
          type: PageTransitionType.fade,
        ),
        (route) => false,
      );
    } catch (e) {
      log("Error checking login status: $e");
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
          "assets/images/splash_screen_image.png",
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
