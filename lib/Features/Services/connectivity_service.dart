import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged
        .listen((event) => _checkActualInternet());
  }

  Stream<bool> get internetStatusStream =>_controller.stream;

  Future<void> _checkActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      _controller.add(result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } catch (_) {
      _controller.add(false);
    }
  }

  Future<bool> checkNow() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  void dispose()
  {
    _controller.close();
  }
}
