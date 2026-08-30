import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../utils/platform_view_registry.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final String viewId = 'vehicle-monitor-iframe';

  @override
  void initState() {
    super.initState();
    // Register the iframe view factory
    PlatformViewRegistry.registerViewFactory(viewId, (int id) {
      final iframe = html.IFrameElement()
        ..src = 'vehicle_monitor/index.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..allow = 'camera; microphone; geolocation; autoplay';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Driver Monitor', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: HtmlElementView(viewType: viewId),
    );
  }
}
