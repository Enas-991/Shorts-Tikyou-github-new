// Folder: lib/services/
// File:   connectivity_service.dart
//
// Wraps connectivity_plus into a simple reactive service.
// Other parts of the app watch [isOnline] to decide stream vs local playback.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  static ConnectivityService? _instance;

  ConnectivityService._() {
    _init();
  }

  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void _init() {
    // Get initial state
    Connectivity().checkConnectivity().then(_updateFromResults);

    // Listen for changes
    _sub = Connectivity().onConnectivityChanged.listen(_updateFromResults);
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      debugPrint('[Connectivity] Network: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
