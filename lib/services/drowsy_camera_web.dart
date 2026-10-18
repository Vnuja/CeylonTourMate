// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../utils/platform_view_registry.dart';

class DrowsyCameraController {
  static const String viewTypeId = 'drowsy-camera-video-view';
  static bool _registered = false;
  static html.IFrameElement? _iframeElement;
  static bool _isActive = false;
  static final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get messageStream =>
      _messageController.stream;

  static void ensureRegistered() {
    if (!_registered) {
      _iframeElement = html.IFrameElement()
        ..src = 'vehicle_monitor/drowsy_embed.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent'
        ..style.overflow = 'hidden'
        ..setAttribute('allow', 'camera *; microphone *; autoplay *; vibration *')
        ..setAttribute('allowfullscreen', 'true');

      html.window.onMessage.listen((event) {
        try {
          if (event.data is Map) {
            _messageController.add(Map<String, dynamic>.from(event.data as Map));
          }
        } catch (_) {}
      });

      PlatformViewRegistry.registerViewFactory(viewTypeId, (int id) {
        return _iframeElement!;
      });
      _registered = true;
    }
  }

  static Future<bool> startCamera() async {
    ensureRegistered();
    try {
      _iframeElement?.contentWindow?.postMessage({'type': 'START_DETECTION'}, '*');
      _isActive = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static void stopCamera() {
    try {
      _iframeElement?.contentWindow?.postMessage({'type': 'STOP_DETECTION'}, '*');
    } catch (_) {}
    _isActive = false;
  }

  static bool get isActive => _isActive;

  static Widget buildView() {
    ensureRegistered();
    return const HtmlElementView(viewType: viewTypeId);
  }
}
