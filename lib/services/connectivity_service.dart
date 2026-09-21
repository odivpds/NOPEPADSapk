import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides a stream of connectivity status (true = online, false = offline)
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityService().onlineStream;
});

/// One-shot check: is the device currently online?
final isOnlineProvider = FutureProvider<bool>((ref) async {
  return ConnectivityService().checkOnline();
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream that emits true when online, false when offline
  Stream<bool> get onlineStream async* {
    yield await checkOnline();
    await for (final results in _connectivity.onConnectivityChanged) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        yield true;
      } else {
        // Fallback for Windows desktop where ConnectivityResult.none can be falsely reported
        yield await checkOnline();
      }
    }
  }

  /// Robust connectivity check: checks adapter type with real DNS fallback for desktop
  Future<bool> checkOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.any((r) => r != ConnectivityResult.none)) {
        return true;
      }
    } catch (_) {}

    // Fallback: actual socket/DNS resolution for Windows desktop
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      try {
        final result2 = await InternetAddress.lookup('one.one.one.one')
            .timeout(const Duration(seconds: 2));
        if (result2.isNotEmpty && result2[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }

    return false;
  }
}
