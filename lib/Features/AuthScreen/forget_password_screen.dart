// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:next_poll/Features/AuthScreen/auth_services.dart';
import 'package:next_poll/Features/Provider/auth_provider.dart';
import 'package:provider/provider.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  TextEditingController emailCTRL = TextEditingController();
  TextEditingController passwordCTRL = TextEditingController();
  bool loader = false;

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
                  width: 250,
                  height: 250,
                  child: Image.asset(
                    'assets/images/forget_password_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Text(
                  "Forget Password",
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
                  height: 50,
                ),
                Consumer<AuthProviderData>(builder: (_, laoderProvider, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: laoderProvider.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                            color: Colors.orange,
                          ))
                        : ElevatedButton(
                            onPressed: () async {
                              if (emailCTRL.text.isEmpty) {
                                AuthServices.showSnackBar(
                                    "Please Add Email", context);
                              } else if (!isValidEmail(emailCTRL.text)) {
                                AuthServices.showSnackBar(
                                    "Please enter a valid email address.",
                                    context);
                              } else {
                                laoderProvider.setLoader(true);

                                await AuthServices.sendPasswordResetEmail(
                                    emailCTRL.text.toString(), context);
                                laoderProvider.setLoader(false);
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
                              "Send Password Reset Email",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                  );
                }),
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
