import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/driver_profile.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final DriverProfile driver;
  final User? firebaseUser;

  const HomeScreen({
    super.key,
    required this.driver,
    this.firebaseUser,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  bool _isMonitoring = true;
  bool _isSimulatingDrowsy = false;
  double _drowsinessLevel = 0.08; // 0.0 to 1.0
  String _eyeState = 'Open';
  double _perclos = 5.4; // Percentage of eye closure
  int _blinkRate = 18; // blinks/min
  int _speed = 58; // km/h
  final int _speedLimit = 70; // km/h
  final int _routeDeviation = 0; // meters
  final String _geofenceStatus = 'Southern Tourist Safety Belt (Zone A)';
  bool _alarmActive = false;

  Timer? _telemetryTimer;
  late AnimationController _pulseController;
  late AnimationController _scannerController;
  late AnimationController _alarmPulseController;

  final List<AlertItem> _alerts = [
    AlertItem(
      id: '1',
      title: 'Surveillance Active',
      message: 'AI Driver Fatigue & Geofence monitoring online.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      severity: AlertSeverity.info,
      icon: Icons.shield_rounded,
    ),
    AlertItem(
      id: '2',
      title: 'Corridor Verification',
      message: 'Vehicle entered Southern Expressway (E01) Tourist Zone.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 24)),
      severity: AlertSeverity.info,
      icon: Icons.alt_route_rounded,
    ),
    AlertItem(
      id: '3',
      title: 'Speed Advisory',
      message: 'Adhering to 70 km/h regional expressway limit.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 48)),
      severity: AlertSeverity.info,
      icon: Icons.speed_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _alarmPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startTelemetryStream();
  }

  void _startTelemetryStream() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        if (!_isMonitoring) {
          _drowsinessLevel = 0.0;
          _eyeState = 'Monitoring Paused';
          return;
        }

        if (_isSimulatingDrowsy) {
          _drowsinessLevel = (_drowsinessLevel + 0.15).clamp(0.0, 0.95);
          _eyeState = 'Closed (Drowsy)';
          _perclos = 52.8;
          _blinkRate = 4;
          if (_drowsinessLevel >= 0.65 && !_alarmActive) {
            _triggerDrowsyAlarm();
          }
        } else {
          // Normal fluctuation
          _drowsinessLevel =
              (0.05 + (DateTime.now().second % 10) * 0.015).clamp(0.0, 0.25);
          _eyeState = 'Open';
          _perclos = 5.2 + (DateTime.now().second % 4) * 0.4;
          _blinkRate = 16 + (DateTime.now().second % 5);
          _speed = (55 + (DateTime.now().second % 8));
        }
      });
    });
  }

  void _triggerDrowsyAlarm() {
    setState(() {
      _alarmActive = true;
      _alerts.insert(
        0,
        AlertItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'CRITICAL: Driver Drowsiness Detected!',
          message:
              'Prolonged eye closure (PERCLOS > 50%). Audible alarm triggered.',
          timestamp: DateTime.now(),
          severity: AlertSeverity.critical,
          icon: Icons.warning_amber_rounded,
        ),
      );
    });
  }

  void _dismissAlarm() {
    setState(() {
      _alarmActive = false;
      _isSimulatingDrowsy = false;
      _drowsinessLevel = 0.12;
      _eyeState = 'Open';
      _perclos = 6.0;
    });
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'End Driver Session?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will disconnect vehicle surveillance and return to login.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      if (widget.firebaseUser != null) {
        try {
          await GoogleSignIn().signOut();
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  void _showEmergencyHotlines() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emergency_rounded,
                      color: Color(0xFFEF4444)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency SOS Hotlines',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Immediate Sri Lanka Response & Dispatch',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sosTile('1912', 'Sri Lanka Tourist Police Hotline',
                Icons.local_police_rounded),
            _sosTile('119', 'Police Emergency Dispatch', Icons.shield_rounded),
            _sosTile('1990', 'Suwa Seriya Free Emergency Ambulance',
                Icons.medical_services_rounded),
            _sosTile('+94 11 214 2355', 'CeylonTourMate Fleet Assistance',
                Icons.support_agent_rounded),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sosTile(String number, String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF38BDF8), size: 22),
        title: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.call_rounded, size: 14, color: Color(0xFF34D399)),
              SizedBox(width: 4),
              Text(
                'CALL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF34D399),
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dialing $number ($label)...'),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _pulseController.dispose();
    _scannerController.dispose();
    _alarmPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadAlerts = _alerts.where((a) => !a.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Stack(
        children: [
          // Ambient lighting
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                _buildTopAppBar(unreadAlerts),

                // Main Content View
                Expanded(
                  child: IndexedStack(
                    index: _currentTabIndex,
                    children: [
                      _buildMonitorTab(),
                      _buildRouteTab(),
                      _buildFleetTab(),
                      _buildAlertsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Alarm Overlay Modal if active
          if (_alarmActive) _buildAlarmOverlay(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(unreadAlerts),
    );
  }

  Widget _buildTopAppBar(int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Driver Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF10B981)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFF131B2E),
              backgroundImage: widget.driver.photoUrl != null
                  ? NetworkImage(widget.driver.photoUrl!)
                  : null,
              child: widget.driver.photoUrl == null
                  ? Text(
                      widget.driver.name.isNotEmpty
                          ? widget.driver.name[0].toUpperCase()
                          : 'D',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Name and Vehicle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.driver.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.driver.vehicleNumber} • ${widget.driver.vehicleModel}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // SOS Quick Button
          IconButton(
            tooltip: 'Emergency SOS',
            onPressed: _showEmergencyHotlines,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Color(0xFFEF4444),
                size: 18,
              ),
            ),
          ),

          // Sign Out Button
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _signOut,
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(int unreadAlerts) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF2563EB).withValues(alpha: 0.25),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF60A5FA) : Colors.white54,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 22,
              color: isSelected ? const Color(0xFF60A5FA) : Colors.white54,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentTabIndex,
          onDestinationSelected: (idx) {
            setState(() => _currentTabIndex = idx);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.remove_red_eye_outlined),
              selectedIcon: Icon(Icons.remove_red_eye_rounded),
              label: 'Monitor',
            ),
            const NavigationDestination(
              icon: Icon(Icons.alt_route_outlined),
              selectedIcon: Icon(Icons.alt_route_rounded),
              label: 'Route & GPS',
            ),
            const NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed_rounded),
              label: 'Telemetry',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unreadAlerts > 0,
                label: Text('$unreadAlerts'),
                backgroundColor: const Color(0xFFEF4444),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: unreadAlerts > 0,
                label: Text('$unreadAlerts'),
                backgroundColor: const Color(0xFFEF4444),
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: LIVE MONITOR (DROWSINESS & CAMERA) =================
  Widget _buildMonitorTab() {
    final isDrowsy = _drowsinessLevel >= 0.55;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert Status Banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDrowsy
                  ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                  : const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDrowsy
                    ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                    : const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDrowsy
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: (isDrowsy
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981))
                                .withValues(
                                    alpha: _pulseController.value * 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDrowsy
                            ? 'DROWSINESS WARNING'
                            : 'DRIVER ALERT & VIGILANT',
                        style: TextStyle(
                          color: isDrowsy
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        isDrowsy
                            ? 'High fatigue detected. Please focus on the road.'
                            : 'AI vision active: Normal eye aspect ratio and blink rate.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDrowsy)
                  ElevatedButton(
                    onPressed: _triggerDrowsyAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('ALARM',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Face Tracking Camera Feed Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                children: [
                  // Camera Viewfinder Box
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 220,
                        width: double.infinity,
                        color: const Color(0xFF0A0F1D),
                        child: CustomPaint(
                          painter: _CameraMeshPainter(
                            scannerProgress: _scannerController.value,
                            isDrowsy: isDrowsy,
                          ),
                        ),
                      ),

                      // Scanning line animation
                      AnimatedBuilder(
                        animation: _scannerController,
                        builder: (context, child) {
                          return Positioned(
                            top: 220 * _scannerController.value,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    (isDrowsy
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF38BDF8))
                                        .withValues(alpha: 0.9),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Face Target Box
                      Container(
                        width: 140,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDrowsy
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF38BDF8),
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Left eye indicator
                            Positioned(
                              top: 45,
                              left: 30,
                              child: _eyeIndicator(isClosed: isDrowsy),
                            ),
                            // Right eye indicator
                            Positioned(
                              top: 45,
                              right: 30,
                              child: _eyeIndicator(isClosed: isDrowsy),
                            ),
                            // Center target icon
                            Center(
                              child: Icon(
                                Icons.face_rounded,
                                size: 70,
                                color: (isDrowsy
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF38BDF8))
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Top camera badge & flip
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_front_rounded,
                                  size: 13, color: Colors.white70),
                              SizedBox(width: 5),
                              Text(
                                'FRONT CABIN CAM',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDrowsy
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981))
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'EYE: $_eyeState',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Drowsiness Bar & Metrics
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Drowsiness Risk Level',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '${(_drowsinessLevel * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDrowsy
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF34D399),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _drowsinessLevel,
                            minHeight: 10,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDrowsy
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Metric Chips
                        Row(
                          children: [
                            _miniMetric('PERCLOS', '$_perclos%',
                                Icons.visibility_rounded),
                            const SizedBox(width: 8),
                            _miniMetric('Blink Rate', '$_blinkRate/m',
                                Icons.remove_red_eye_rounded),
                            const SizedBox(width: 8),
                            _miniMetric('EAR Ratio', isDrowsy ? '0.14' : '0.32',
                                Icons.show_chart_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Controls Card (Research Defense / Simulation Mode)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.science_rounded,
                              size: 20, color: Color(0xFFF59E0B)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Simulate Drowsy State',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Test alert trigger & audio-visual response',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _isSimulatingDrowsy,
                      activeThumbColor: const Color(0xFFEF4444),
                      activeTrackColor:
                          const Color(0xFFEF4444).withValues(alpha: 0.35),
                      onChanged: (val) {
                        setState(() {
                          _isSimulatingDrowsy = val;
                          if (val) {
                            _drowsinessLevel = 0.75;
                            _triggerDrowsyAlarm();
                          } else {
                            _dismissAlarm();
                          }
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _isMonitoring = !_isMonitoring);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isMonitoring
                              ? const Color(0xFFF87171)
                              : const Color(0xFF34D399),
                          side: BorderSide(
                            color: _isMonitoring
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                            _isMonitoring
                                ? Icons.pause_circle_rounded
                                : Icons.play_circle_rounded,
                            size: 18),
                        label: Text(
                            _isMonitoring ? 'Pause Camera' : 'Resume Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _triggerDrowsyAlarm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.volume_up_rounded, size: 18),
                        label: const Text('Test Alarm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dashboard Quick Telemetry Row
          Row(
            children: [
              Expanded(
                child: _dashboardCard(
                  'Speed',
                  '$_speed km/h',
                  'Limit: $_speedLimit',
                  Icons.speed_rounded,
                  const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dashboardCard(
                  'Route Dev.',
                  '$_routeDeviation m',
                  'On Corridor',
                  Icons.near_me_rounded,
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dashboardCard(
                  'Engine',
                  '88°C',
                  'Optimal',
                  Icons.thermostat_rounded,
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _eyeIndicator({required bool isClosed}) {
    return Container(
      width: 22,
      height: 14,
      decoration: BoxDecoration(
        color: isClosed ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardCard(
      String title, String main, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            main,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 2: ROUTE & GPS COMPLIANCE =================
  Widget _buildRouteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF10B981), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Route Compliant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '0m DEVIATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Assigned Corridor: ${widget.driver.assignedCorridor}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 4),
                    Text(
                      'Destination: Mirissa Bay • ETA: 34 mins',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Live Vector Map Card
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 280),
                    painter: _MapRoutePainter(pulseVal: _pulseController.value),
                  ),

                  // Map Floating Controls
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed_rounded,
                              size: 14, color: Color(0xFF10B981)),
                          SizedBox(width: 6),
                          Text(
                            'GPS HIGH ACCURACY (±3m)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: FloatingActionButton.small(
                      heroTag: 'recenter_map',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Re-centered on Vehicle: WP NC-4921'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      backgroundColor: const Color(0xFF2563EB),
                      child: const Icon(Icons.my_location_rounded,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Corridor & Geofence Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Safety & Geofencing Parameters',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _parameterRow('Geofence Buffer', _geofenceStatus),
                _parameterRow('Speed Cap', '70 km/h (Expressway Regulation)'),
                _parameterRow('Max Idle Duration', '15 minutes allowed'),
                _parameterRow(
                    'Alert Dispatch', 'Active to CeylonTourMate Command'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parameterRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: FLEET TELEMETRY & HEALTH =================
  Widget _buildFleetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driving Score Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF131B2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: 0.94,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981)),
                      ),
                    ),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '94',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'SCORE',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Health Rating',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Excellent safety profile. Zero drowsiness alerts in past 48 hours.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Vehicle Health & Diagnostics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _diagnosticCard('Fuel Level', '74%', '380 km Range',
                  Icons.local_gas_station_rounded, const Color(0xFF10B981)),
              _diagnosticCard('Battery', '13.8 V', 'Alternator Charging',
                  Icons.battery_charging_full_rounded, const Color(0xFF38BDF8)),
              _diagnosticCard('Tire Pressure', '32 PSI', 'Optimal All-Round',
                  Icons.album_rounded, const Color(0xFFF59E0B)),
              _diagnosticCard('Cloud Sync', 'Connected', 'Ping: 24ms (OK)',
                  Icons.cloud_done_rounded, const Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 18),

          // Trip Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Trip Statistics',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _tripStat('Duration', '1h 45m'),
                    _tripStat('Distance', '86.4 km'),
                    _tripStat('Avg Speed', '52 km/h'),
                    _tripStat('Breaks', '1 Taken'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticCard(
      String title, String val, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: color),
              Text(
                val,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripStat(String label, String val) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }

  // ================= TAB 4: ALERT NOTIFICATIONS =================
  Widget _buildAlertsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alerts & Safety Events (${_alerts.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _alerts.clear());
                },
                child: const Text('Clear All',
                    style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          'No active alerts',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      final isCritical =
                          alert.severity == AlertSeverity.critical;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCritical
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCritical
                                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isCritical
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF38BDF8))
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                alert.icon,
                                size: 18,
                                color: isCritical
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isCritical
                                          ? const Color(0xFFFCA5A5)
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    alert.message,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ================= FULLSCREEN DROWSINESS ALARM MODAL =================
  Widget _buildAlarmOverlay() {
    return AnimatedBuilder(
      animation: _alarmPulseController,
      builder: (context, child) {
        return Container(
          color: const Color(0xFFEF4444)
              .withValues(alpha: 0.25 + _alarmPulseController.value * 0.35),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFEF4444), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                    blurRadius: 40,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'WAKE UP DRIVER!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Prolonged Eye Closure Detected\nPlease keep your eyes on the road or pull over safely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 26),
                  ElevatedButton(
                    onPressed: _dismissAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 6,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'I AM AWAKE • DISMISS ALARM',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom Painter for Camera Mesh Viewfinder
class _CameraMeshPainter extends CustomPainter {
  final double scannerProgress;
  final bool isDrowsy;

  _CameraMeshPainter({required this.scannerProgress, required this.isDrowsy});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDrowsy ? const Color(0xFFEF4444) : const Color(0xFF38BDF8))
          .withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw grid lines
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CameraMeshPainter oldDelegate) => true;
}

// Custom Painter for Map Route Preview
class _MapRoutePainter extends CustomPainter {
  final double pulseVal;

  _MapRoutePainter({required this.pulseVal});

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;

    final routePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;

    final path = Path()
      ..moveTo(40, size.height - 30)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.7, size.width * 0.5,
          size.height * 0.45)
      ..lineTo(size.width - 50, 40);

    // Draw expressway corridor
    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path, routePaint);

    // Vehicle Location Marker
    final carPos = Offset(size.width * 0.5, size.height * 0.45);
    final ripplePaint = Paint()
      ..color =
          const Color(0xFF10B981).withValues(alpha: (1.0 - pulseVal) * 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(carPos, 12 + pulseVal * 10, ripplePaint);

    final carPaint = Paint()..color = const Color(0xFF10B981);
    canvas.drawCircle(carPos, 7, carPaint);
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) => true;
}
