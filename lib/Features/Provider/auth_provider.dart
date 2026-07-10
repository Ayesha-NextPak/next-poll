import 'package:flutter/material.dart';

class AuthProviderData extends ChangeNotifier {
  static bool _showPassword = true;

  bool get showPassword => _showPassword;

  void setShowPassword(bool value) {
    _showPassword = value;
    notifyListeners();
  }

  static bool _loader = false;

  bool get isLoading => _loader;

  void setLoader(bool value) {
    _loader = value;
    notifyListeners();
  }
}
