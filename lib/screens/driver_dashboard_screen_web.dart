import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:html' as html;
import '../theme/ceylon_theme.dart';
import '../utils/platform_view_registry.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  static const String viewId = 'vehicle-monitor-iframe';
  static bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    // Register the iframe view factory once
    if (!_isRegistered) {
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
      _isRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      appBar: AppBar(
        title: Text(
          'Driver Monitor',
          style: GoogleFonts.playfairDisplay(
            color: CeylonSpiceTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: CeylonSpiceTheme.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: CeylonSpiceTheme.textPrimary),
      ),
      body: HtmlElementView(viewType: viewId),
    );
  }
}
