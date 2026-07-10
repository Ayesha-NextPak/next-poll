// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:next_poll/Features/AuthScreen/auth_services.dart';
import 'package:next_poll/Features/AuthScreen/forget_password_screen.dart';
import 'package:next_poll/Features/AuthScreen/signup_screen.dart';
import 'package:next_poll/Features/Provider/auth_provider.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  TextEditingController emailCTRL =
      TextEditingController(text: "saqib@nextpak.org");
  TextEditingController passwordCTRL = TextEditingController(text: "Sa1234567");

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 30,
                ),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.asset(
                    'assets/images/login_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Text(
                  "SignIn",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                SizedBox(
                  height: 30,
                ),
                SizedBox(
                  height: 30,
                ),
                TextFormField(
                  controller: emailCTRL,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.25),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: Icon(
                      Icons.email,
                      color: Colors.black,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(
                  height: 20,
                ),
                Consumer<AuthProviderData>(builder: (_, authProvider, child) {
                  return TextFormField(
                    controller: passwordCTRL,
                    obscureText: authProvider.showPassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.25),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: Colors.black,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          authProvider
                              .setShowPassword(!authProvider.showPassword);
                        },
                        child: Icon(
                          authProvider.showPassword
                              ? Icons.remove_red_eye
                              : Icons.remove_red_eye_outlined,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                  );
                }),
                SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            PageTransition(
                                child: ForgetPasswordScreen(),
                                type: PageTransitionType.fade));
                      },
                      child: Text(
                        'Forget Password?',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          decorationColor: Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  ],
                ),
                SizedBox(
                  height: 32,
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () async {
                        AuthServices.signInWithGoogle(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/images/google_icon_image.png",
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text("Google Sign In")
                        ],
                      )),
                ),
                SizedBox(
                  height: 32,
                ),
                Consumer<AuthProviderData>(
                    builder: (_, authLoaderProvider, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: authLoaderProvider.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                            color: Colors.orange,
                          ))
                        : ElevatedButton(
                            onPressed: () async {
                              if (emailCTRL.text.isEmpty) {
                                AuthServices.showSnackBar(
                                    "Please Add Email", context);
                              } else if (passwordCTRL.text.isEmpty) {
                                AuthServices.showSnackBar(
                                    "Please enter your password", context);
                              } else if (!isValidEmail(emailCTRL.text)) {
                                AuthServices.showSnackBar(
                                    "Please enter a valid email address.",
                                    context);
                              } else {
                                authLoaderProvider.setLoader(true);
                                await AuthServices.handleSignIn(
                                    emailCTRL.text.toString(),
                                    passwordCTRL.text.toString(),
                                    context);
                                authLoaderProvider.setLoader(false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              "Sign In",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                  );
                }),
                SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have Account?",
                      style: TextStyle(color: Colors.black, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            PageTransition(
                                child: SignUpScreen(),
                                type: PageTransitionType.fade));
                      },
                      child: Text(
                        'SignUp',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ));
  }

  void validateEmail(String email, BuildContext contextEmail) {
    if (isValidEmail(email)) {
    } else {
      AuthServices.showSnackBar(
          "Please enter a valid email address", contextEmail);
    }
  }

  bool isValidEmail(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }
}
