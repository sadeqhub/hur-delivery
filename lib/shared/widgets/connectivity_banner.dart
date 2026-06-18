import 'package:flutter/material.dart';

import '../../core/icons/hur_icons.dart';
import 'hur_icon.dart';

/// A slim banner shown at the top of the screen when the device is offline.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding + 6,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.orange.shade700],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HurIcon(
                HurIconKind.wifiOff,
                size: HurIconSize.xs,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'لا يوجد اتصال بالإنترنت',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
