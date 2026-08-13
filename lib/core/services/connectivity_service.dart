import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps `connectivity_plus` to expose a simple online/offline stream.
///
/// connectivity_plus v6+ emits a `List<ConnectivityResult>`; this service
/// collapses that into a single [ConnectivityResult] and a boolean online flag.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Stream of the primary [ConnectivityResult] whenever it changes.
  Stream<ConnectivityResult> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(_reduce);

  /// Stream of a simple online/offline boolean.
  Stream<bool> get onOnlineChanged =>
      onStatusChanged.map(_isOnline);

  /// One-shot check of the current primary connectivity result.
  Future<ConnectivityResult> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return _reduce(results);
  }

  /// One-shot online check.
  Future<bool> isOnline() async {
    final result = await checkConnectivity();
    return _isOnline(result);
  }

  ConnectivityResult _reduce(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;
    // Prefer any "connected" result over `none`.
    return results.firstWhere(
      (r) => r != ConnectivityResult.none,
      orElse: () => ConnectivityResult.none,
    );
  }

  bool _isOnline(ConnectivityResult result) =>
      result != ConnectivityResult.none;
}
