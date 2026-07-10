// ignore_for_file: use_build_context_synchronously
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:next_poll/Features/AuthScreen/signin_screen.dart';
import 'package:next_poll/Features/HomeScreens/show_polls.dart';
import 'package:page_transition/page_transition.dart';

class AuthServices {
  static Future<String> signUpwithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      return "Sign-Up successful!";
    } catch (e) {
      return "Error during sign-up : ${e.toString()}";
    }
  }

  static handleSignUp(
      String email, String password, BuildContext context) async {
    String message = await signUpwithEmail(email, password);

    if (message == "Sign-Up successful!") {
      await sendVerificationEmail(context, message);
    }
  }

  static Future<void> sendVerificationEmail(
      BuildContext context, String? message) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        showSnackBar(
            "$message & Verification email sent to ${user.email}", context);
        Navigator.pushAndRemoveUntil(
            context,
            PageTransition(
                child: const SignInScreen(), type: PageTransitionType.fade),
            (route) => false);
      } else if (user != null && user.emailVerified) {
        showSnackBar(message!, context);
        Navigator.pushAndRemoveUntil(
            context,
            PageTransition(
                child: const PollScreen(), type: PageTransitionType.fade),
            (route) => false);
      }
    } catch (e) {
      showSnackBar("Error: ${e.toString()}", context);
    }
  }

  static Future<String> signInwithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      return "Sign-In successful!";
    } catch (e) {
      return "Error during sign-In : ${e.toString()}";
    }
  }

  static handleSignIn(
      String email, String password, BuildContext context) async {
    String message = await signInwithEmail(email, password);

    if (message == "Sign-In successful!") {
      await sendVerificationEmail(context, message);
    }
  }

  static void showSnackBar(String message, BuildContext context) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static Future<Map<String, dynamic>?> signInWithGoogle(
      BuildContext context) async {
    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      log('Google sign-in successful: ${googleUser.email}');

      Navigator.pushAndRemoveUntil(
          context,
          PageTransition(
              child: const PollScreen(), type: PageTransitionType.fade),
          (route) => false);

      return {
        'email': googleUser.email,
        'displayName': googleUser.displayName,
        'photoUrl': googleUser.photoUrl,
        'id': googleUser.id,
      };
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User dismissed the sign-in dialog — not an error
        return null;
      }
      log('Google sign-in error: $e');
      showSnackBar("Google Sign-In failed: ${e.toString()}", context);
      return null;
    } catch (e) {
      log('Google sign-in error: $e');
      showSnackBar("Google Sign-In failed: ${e.toString()}", context);
      return null;
    }
  }

  static Future<void> signOut(BuildContext context) async {
    try {
      await GoogleSignIn.instance.signOut();

      Navigator.pushAndRemoveUntil(
          context,
          PageTransition(
              child: const SignInScreen(), type: PageTransitionType.fade),
          (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
    } catch (e) {
      log('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  static Future<void> sendPasswordResetEmail(
      String email, BuildContext context) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      showSnackBar("Password reset email sent to $email", context);

      Navigator.pushAndRemoveUntil(
          context,
          PageTransition(
              child: const SignInScreen(), type: PageTransitionType.fade),
          (route) => false);
    } catch (e) {
      showSnackBar("Error: ${e.toString()}", context);
    }
  }

  static Future<bool> userLogin() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return true;
    } else {
      return false;
    }
  }
}
