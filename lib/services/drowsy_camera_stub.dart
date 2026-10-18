import 'package:flutter/material.dart';

class DrowsyCameraController {
  static const String viewTypeId = 'drowsy-camera-video-view';

  static void ensureRegistered() {}

  static Future<bool> startCamera() async {
    return true;
  }

  static void stopCamera() {}

  static bool get isActive => false;

  static Stream<Map<String, dynamic>> get messageStream => const Stream.empty();

  static Widget buildView() {
    return Container(
      color: const Color(0xFF0F1A12),
      child: const Center(
        child: Icon(Icons.videocam_rounded, color: Colors.white38, size: 48),
      ),
    );
  }
}
