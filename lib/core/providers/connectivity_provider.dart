import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  final controller = StreamController<bool>.broadcast();

  connectivity.checkConnectivity().then((result) {
    if (!controller.isClosed) {
      controller.add(result != ConnectivityResult.none);
    }
  });

  final sub = connectivity.onConnectivityChanged.listen((result) {
    if (!controller.isClosed) {
      controller.add(result != ConnectivityResult.none);
    }
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
