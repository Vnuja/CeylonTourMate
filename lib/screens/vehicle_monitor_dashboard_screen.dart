import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/drowsy_camera.dart';
import 'vehicle_monitor_login_screen.dart';

class VehicleMonitorDashboardScreen extends StatefulWidget {
  final String? driverName;
  final String? driverEmail;
  final String? driverPhotoUrl;

  const VehicleMonitorDashboardScreen({
    super.key,
    this.driverName,
    this.driverEmail,
    this.driverPhotoUrl,
  });

  @override
  State<VehicleMonitorDashboardScreen> createState() =>
      _VehicleMonitorDashboardScreenState();
}

class _VehicleMonitorDashboardScreenState
    extends State<VehicleMonitorDashboardScreen> with TickerProviderStateMixin {
  // Alertness & AI state
  bool _isMonitoring = false;
  bool _isDrowsy = false;
  String _eyeState = 'OPEN';
  double _ear = 0.32;
  double _confidencePercent = 0.0;
  StreamSubscription<Map<String, dynamic>>? _drowsySub;

  // Cloud Firestore & Fleet / Remote sync
  FirebaseFirestore? _firestore;
  FirebaseAuth? _vehicleAuth;
  String? _driverId;
  StreamSubscription<DocumentSnapshot>? _commandsSub;
  StreamSubscription<DocumentSnapshot>? _telemetrySub;
  Timer? _fleetSyncTimer;
  bool _isCloudConnected = false;

  // Live telemetry state
  int _speed = 0;
  final String _locationName = 'Galle Face Green, Colombo';
  String _engineTemp = '84 °C';
  String _routeDeviation = '0m';
  String _areaStatus = 'Safe Zone';

  // Intercom / Dispatch Call state
  bool _isIntercomActive = false;
  int _intercomCallSeconds = 0;
  Timer? _intercomTimer;
  BuildContext? _intercomDialogContext;

  // Notifications
  final List<Map<String, dynamic>> _notifications = [
    {},
  ];

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Listen to local camera embed telemetry
    _drowsySub = DrowsyCameraController.messageStream.listen((data) {
      if (data['type'] == 'DROWSY_TELEMETRY' && mounted) {
        setState(() {
          if (data['speed'] != null) {
            _speed = (data['speed'] as num).toInt();
          }
          if (data['status'] != null) {
            _isMonitoring = data['status'] != 'Inactive';
            _isDrowsy = data['status'] == 'Drowsy';
          }
          if (data['eyeState'] != null) {
            _eyeState = (data['eyeState'] as String).toUpperCase();
          }
          if (data['ear'] != null) {
            _ear = (data['ear'] as num).toDouble();
          }
          if (data['confidence'] != null) {
            _confidencePercent = ((data['confidence'] as num).toDouble()) * 100;
          }
        });
        _syncToFleet();
      }
    });

    // Initialize Cloud connection to vehiclemonitor-5b1e8 (Firestore for Fleet & Remote)
    _initVehicleCloud();
  }

  Future<void> _initVehicleCloud() async {
    try {
      FirebaseApp app;
      try {
        app = Firebase.app('VehicleMonitor');
      } catch (_) {
        const FirebaseOptions webOptions = FirebaseOptions(
          apiKey: 'AIzaSyCQ9XwaEWDPE3YEaD00AhKMN0dplkiTWAE',
          appId: '1:342502404771:web:91ba8e2eca1a09cad24516',
          messagingSenderId: '342502404771',
          projectId: 'vehiclemonitor-5b1e8',
          authDomain: 'vehiclemonitor-5b1e8.firebaseapp.com',
          storageBucket: 'vehiclemonitor-5b1e8.firebasestorage.app',
        );
        const FirebaseOptions androidOptions = FirebaseOptions(
          apiKey: 'AIzaSyBU80-7WH0zBN87uqPBtIwrhE-MvVIfJ7A',
          appId: '1:342502404771:android:407361204b173d9dd24516',
          messagingSenderId: '342502404771',
          projectId: 'vehiclemonitor-5b1e8',
          storageBucket: 'vehiclemonitor-5b1e8.firebasestorage.app',
        );
        app = await Firebase.initializeApp(
          name: 'VehicleMonitor',
          options: kIsWeb ? webOptions : androidOptions,
        );
      }

      _firestore = FirebaseFirestore.instanceFor(app: app);
      _vehicleAuth = FirebaseAuth.instanceFor(app: app);

      final user =
          _vehicleAuth?.currentUser ?? FirebaseAuth.instance.currentUser;
      _driverId = user?.uid ??
          'driver_${widget.driverEmail?.replaceAll('@', '_').replaceAll('.', '_') ?? "ceylon"}';

      _subscribeToRemoteCommands();
      _subscribeToTelemetryOverride();
      _startFleetHeartbeat();
      _syncToFleet();

      if (mounted) {
        setState(() {
          _isCloudConnected = true;
        });
      }
    } catch (e) {
      debugPrint('[VehicleMonitor] Cloud connection error: $e');
    }
  }

  void _subscribeToRemoteCommands() {
    if (_firestore == null || _driverId == null) return;
    _commandsSub?.cancel();
    _commandsSub = _firestore!
        .collection('commands')
        .doc(_driverId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      final bool processed = data['processed'] == true;
      if (!processed) {
        final type = data['type'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        _handleIncomingRemoteCommand(type, message);

        // Mark command as processed in Firestore
        _firestore!
            .collection('commands')
            .doc(_driverId)
            .update({'processed': true}).catchError((_) {});
      }
    }, onError: (err) {
      debugPrint('[VehicleMonitor] Error listening to commands: $err');
    });
  }

  void _subscribeToTelemetryOverride() {
    if (_firestore == null || _driverId == null) return;
    _telemetrySub?.cancel();
    _telemetrySub = _firestore!
        .collection('telemetry_override')
        .doc(_driverId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null || data['active'] != true) return;

      bool changed = false;
      if (data['speed'] != null) {
        final int newSpeed = (data['speed'] as num).toInt();
        if (newSpeed != _speed) {
          _speed = newSpeed;
          changed = true;
        }
      }
      if (data['engineTemp'] != null) {
        final String newTemp = '${data['engineTemp']} °C';
        if (newTemp != _engineTemp) {
          _engineTemp = newTemp;
          changed = true;
        }
      }
      if (changed && mounted) {
        setState(() {});
        _showRemoteSnackBar(
          'Remote telemetry override: $_speed km/h, $_engineTemp',
          const Color(0xFFE8A020),
        );
        _syncToFleet();
      }
    }, onError: (err) {
      debugPrint(
          '[VehicleMonitor] Error listening to telemetry override: $err');
    });
  }

  void _startFleetHeartbeat() {
    _fleetSyncTimer?.cancel();
    // Maintain active trip status in Fleet Monitor every 4 seconds
    _fleetSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _syncToFleet();
    });
  }

  Future<void> _syncToFleet() async {
    if (_firestore == null || _driverId == null) return;
    try {
      final name = widget.driverName ??
          _vehicleAuth?.currentUser?.displayName ??
          'Driver';
      final email = widget.driverEmail ??
          _vehicleAuth?.currentUser?.email ??
          'driver@ceylontourmate.com';

      final int tempVal =
          int.tryParse(_engineTemp.replaceAll(RegExp(r'[^0-9]'), '')) ?? 84;
      final int devVal =
          int.tryParse(_routeDeviation.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      final telemetryData = {
        'driverId': _driverId,
        'driverName': name,
        'driverEmail': email,
        'status': _isDrowsy
            ? 'Drowsy'
            : (_routeDeviation != '0m'
                ? 'Warning'
                : (_speed > 100 ? 'Warning' : 'Safe')),
        'eyeState': _eyeState,
        'ear': _ear,
        'confidence': _confidencePercent.round(),
        'speed': _speed,
        'engineTemp': tempVal,
        'gps': {
          'lat': 6.9271, // Galle Face Green, Colombo
          'lng': 79.8612,
          'heading': 180,
          'accuracy': 5,
        },
        'locationName': _locationName,
        'onRoute': _areaStatus == 'Safe Zone',
        'deviationMeters': devVal,
        'currentZone': {
          'id': 'safe-colombo',
          'name': 'Colombo Tourist Corridor',
          'type': _areaStatus == 'Safe Zone' ? 'safe' : 'warning',
        },
        'lastUpdated': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore!
          .collection('active_trips')
          .doc(_driverId)
          .set(telemetryData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[VehicleMonitor] Fleet sync failed: $e');
    }
  }

  Future<void> _logAlertToCloud({
    required String alertType,
    required String message,
    required String status,
  }) async {
    if (_firestore == null || _driverId == null) return;
    try {
      final name = widget.driverName ??
          _vehicleAuth?.currentUser?.displayName ??
          'Driver';
      final email =
          widget.driverEmail ?? _vehicleAuth?.currentUser?.email ?? '';
      final now = DateTime.now().millisecondsSinceEpoch;
      final alertId = '${_driverId}_$now';

      await _firestore!.collection('alerts').doc(alertId).set({
        'driverId': _driverId,
        'driverName': name,
        'driverEmail': email,
        'status': status,
        'type': alertType,
        'message': message,
        'speed': _speed,
        'gps': {'lat': 6.9271, 'lng': 79.8612},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _handleIncomingRemoteCommand(String type, String message) {
    if (!mounted) return;

    final String displayMessage =
        message.isNotEmpty ? message : 'Remote trigger received';

    final Map<String, dynamic> notifItem = {
      'title': 'Remote: ${type.toUpperCase()}',
      'message': displayMessage,
      'time': 'Just now',
      'icon': _getIconForCommandType(type),
      'color': _getColorForCommandType(type),
    };

    setState(() {
      _notifications.insert(0, notifItem);
    });

    switch (type) {
      case 'start_ai':
        DrowsyCameraController.startCamera();
        setState(() => _isMonitoring = true);
        _showRemoteSnackBar(
          '🚀 AI Alertness Camera Started by Remote',
          const Color(0xFF4CAF50),
        );
        break;

      case 'stop_ai':
        DrowsyCameraController.stopCamera();
        setState(() => _isMonitoring = false);
        _showRemoteSnackBar(
          '⏹️ AI Alertness Camera Stopped by Remote',
          const Color(0xFFE8A020),
        );
        break;

      case 'drowsy':
        setState(() {
          _isDrowsy = true;
          _eyeState = 'CLOSED';
        });
        _showRemoteSnackBar(displayMessage, const Color(0xFFE57373));
        _logAlertToCloud(
          alertType: 'drowsiness_alert',
          message: displayMessage,
          status: 'Drowsy',
        );
        break;

      case 'microsleep':
        setState(() {
          _isDrowsy = true;
          _eyeState = 'CLOSED';
        });
        _showRemoteSnackBar(
          '🚨 CRITICAL: Microsleep detected by Remote Controller!',
          const Color(0xFFE57373),
        );
        _logAlertToCloud(
          alertType: 'eye_closure_alert',
          message: 'Critical microsleep detected',
          status: 'Danger',
        );
        break;

      case 'deviation':
        setState(() {
          _routeDeviation = '680m';
          _areaStatus = 'Deviation Warning';
        });
        _showRemoteSnackBar(displayMessage, const Color(0xFFE8A020));
        _logAlertToCloud(
          alertType: 'route_deviation_alert',
          message: displayMessage,
          status: 'Warning',
        );
        break;

      case 'speeding':
        _showRemoteSnackBar(displayMessage, const Color(0xFFE8A020));
        _logAlertToCloud(
          alertType: 'overspeed_alert',
          message: displayMessage,
          status: 'Warning',
        );
        break;

      case 'distraction':
      case 'phone':
      case 'sudden_brake':
        _showRemoteSnackBar(displayMessage, const Color(0xFFE8A020));
        _logAlertToCloud(
          alertType: type,
          message: displayMessage,
          status: 'Warning',
        );
        break;

      case 'incoming_call':
        _showIncomingIntercomDialog(
          message.isNotEmpty
              ? message
              : 'Fleet Operations Dispatch is requesting an audio intercom call.',
        );
        break;

      case 'end_call':
        _dismissIncomingIntercomDialog();
        _showRemoteSnackBar(
          'Call ended by Fleet Dispatch',
          const Color(0xFF81C784),
        );
        break;

      case 'clear':
        setState(() {
          _isDrowsy = false;
          _eyeState = 'OPEN';
          _routeDeviation = '0m';
          _areaStatus = 'Safe Zone';
        });
        _showRemoteSnackBar('All Alerts Cleared', const Color(0xFF4CAF50));
        break;

      default:
        _showRemoteSnackBar(displayMessage, const Color(0xFFE8A020));
    }

    _syncToFleet();
  }

  IconData _getIconForCommandType(String type) {
    switch (type) {
      case 'start_ai':
        return Icons.play_circle_filled_rounded;
      case 'stop_ai':
        return Icons.stop_circle_rounded;
      case 'drowsy':
      case 'microsleep':
        return Icons.bedtime_rounded;
      case 'deviation':
        return Icons.alt_route_rounded;
      case 'speeding':
        return Icons.speed_rounded;
      case 'phone':
        return Icons.phone_android_rounded;
      case 'sudden_brake':
        return Icons.emergency_rounded;
      case 'incoming_call':
      case 'end_call':
        return Icons.support_agent_rounded;
      case 'clear':
        return Icons.check_circle_rounded;
      default:
        return Icons.settings_remote_rounded;
    }
  }

  Color _getColorForCommandType(String type) {
    switch (type) {
      case 'start_ai':
      case 'clear':
        return const Color(0xFF4CAF50);
      case 'drowsy':
      case 'microsleep':
        return const Color(0xFFE57373);
      case 'deviation':
      case 'distraction':
      case 'phone':
      case 'sudden_brake':
      case 'speeding':
        return const Color(0xFFE8A020);
      case 'incoming_call':
        return const Color(0xFF81C784);
      default:
        return const Color(0xFF2F81F7);
    }
  }

  void _showRemoteSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.cell_tower_rounded, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFF5F0E8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openFleetMonitor() async {
    final uri = Uri.parse('vehicle_monitor/fleet_monitor.html');
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        await launchUrl(
          Uri.parse('http://localhost:7151/vehicle_monitor/fleet_monitor.html'),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }
    } catch (_) {
      try {
        await launchUrl(
          Uri.parse('http://localhost:7151/vehicle_monitor/fleet_monitor.html'),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } catch (_) {}
    }
  }

  Future<void> _openRemoteController() async {
    final uri = Uri.parse('vehicle_monitor/remote.html');
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        await launchUrl(
          Uri.parse('http://localhost:7151/vehicle_monitor/remote.html'),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }
    } catch (_) {
      try {
        await launchUrl(
          Uri.parse('http://localhost:7151/vehicle_monitor/remote.html'),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } catch (_) {}
    }
  }

  void _showIncomingIntercomDialog(String message) {
    if (_intercomDialogContext != null) {
      try {
        Navigator.of(_intercomDialogContext!).pop();
      } catch (_) {}
      _intercomDialogContext = null;
    }

    _isIntercomActive = false;
    _intercomCallSeconds = 0;
    _intercomTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _intercomDialogContext = ctx;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final String minutes =
                (_intercomCallSeconds ~/ 60).toString().padLeft(2, '0');
            final String seconds =
                (_intercomCallSeconds % 60).toString().padLeft(2, '0');

            return Dialog(
              backgroundColor: const Color(0xFF1A2E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with pulsing glow
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1B5E3B),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withValues(
                                  alpha: 0.3 + _pulseController.value * 0.4,
                                ),
                                blurRadius: 20 + _pulseController.value * 15,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: Color(0xFFF5F0E8),
                            size: 42,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Fleet Dispatch',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF5F0E8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isIntercomActive
                          ? '🎙️ Intercom Connected'
                          : 'Incoming Intercom Call...',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF81C784),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFFB8C4BB),
                        height: 1.4,
                      ),
                    ),
                    if (_isIntercomActive) ...[
                      const SizedBox(height: 20),
                      Text(
                        '$minutes:$seconds',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF81C784),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (!_isIntercomActive)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE57373),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _intercomDialogContext = null;
                                _showRemoteSnackBar(
                                  'Call declined',
                                  const Color(0xFFB8C4BB),
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.call_end_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Decline',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: const Color(0xFF0F1A12),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  _isIntercomActive = true;
                                  _intercomCallSeconds = 0;
                                });
                                _intercomTimer?.cancel();
                                _intercomTimer = Timer.periodic(
                                  const Duration(seconds: 1),
                                  (_) {
                                    if (mounted) {
                                      setDialogState(() {
                                        _intercomCallSeconds++;
                                      });
                                    }
                                  },
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.call_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Accept',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE57373),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            _intercomTimer?.cancel();
                            Navigator.of(ctx).pop();
                            _intercomDialogContext = null;
                            _showRemoteSnackBar(
                              'Intercom ended',
                              const Color(0xFF81C784),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.call_end_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'End Intercom',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _dismissIncomingIntercomDialog() {
    _intercomTimer?.cancel();
    if (_intercomDialogContext != null) {
      try {
        Navigator.of(_intercomDialogContext!).pop();
      } catch (_) {}
      _intercomDialogContext = null;
    }
  }

  @override
  void dispose() {
    _fleetSyncTimer?.cancel();
    _commandsSub?.cancel();
    _telemetrySub?.cancel();
    _intercomTimer?.cancel();
    _drowsySub?.cancel();
    _pulseController.dispose();

    // Mark status offline in Firestore active_trips if available
    try {
      if (_firestore != null && _driverId != null) {
        _firestore!.collection('active_trips').doc(_driverId).set({
          'status': 'Offline',
          'lastUpdated': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    super.dispose();
  }

  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x47E8A020)),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFF5F0E8),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of Vehicle Monitor?',
          style: GoogleFonts.outfit(color: const Color(0xFFB8C4BB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: const Color(0xFFB8C4BB)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8A020),
              foregroundColor: const Color(0xFF0F1A12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _fleetSyncTimer?.cancel();
        _commandsSub?.cancel();
        _telemetrySub?.cancel();
        if (_firestore != null && _driverId != null) {
          await _firestore!.collection('active_trips').doc(_driverId).set({
            'status': 'Offline',
            'lastUpdated': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
        await _vehicleAuth?.signOut();
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VehicleMonitorLoginScreen()),
        );
      }
    }
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1E),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: const Color(0x47E8A020)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 30,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E9084).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_rounded,
                                color: Color(0xFFE8A020), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Notifications',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF5F0E8),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFFB8C4BB)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF2D4A32), height: 1),
                  Expanded(
                    child: _notifications.isEmpty
                        ? Center(
                            child: Text(
                              'No new notifications',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF7E9084),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFF243328), height: 20),
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (notif['color'] as Color)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      notif['icon'] as IconData,
                                      color: notif['color'] as Color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notif['title'] as String,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: const Color(0xFFF5F0E8),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          notif['message'] as String,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: const Color(0xFFB8C4BB),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif['time'] as String,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: const Color(0xFF7E9084),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (_notifications.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () {
                            setModalState(() => _notifications.clear());
                            setState(() {});
                          },
                          child: Text(
                            'Clear All Notifications',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFE8A020),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLegalModal(String type) {
    final bool isTos = type == 'tos';
    final String title = isTos ? 'Terms of Service' : 'Privacy Policy';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x47E8A020)),
        ),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFF5F0E8),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          isTos
              ? 'By using the CeylonTourMate Vehicle Monitor, you agree to comply with transport safety regulations and real-time corridor telematics.'
              : 'Driver and telemetry data are securely handled to ensure passenger safety and emergency assistance along Sri Lankan tourist corridors.',
          style:
              GoogleFonts.outfit(color: const Color(0xFFB8C4BB), height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8A020),
              foregroundColor: const Color(0xFF0F1A12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.driverName ?? 'Driver';
    final String email = widget.driverEmail ?? 'driver@ceylontourmate.com';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A12),
      body: Stack(
        children: [
          // Background Blob 1
          Positioned(
            top: -100,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF1B5E3B).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Background Blob 3
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB5651D).withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main Scrollable Area
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildHeader(),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Welcome Section
                            _buildWelcomeSection(name),
                            const SizedBox(height: 20),

                            // Profile Card
                            _buildProfileCard(name, email, initial),
                            const SizedBox(height: 24),

                            // Quick Stats Section (Speed, GPS, Temp)
                            _buildQuickStatsSection(),
                            const SizedBox(height: 32),

                            // Driver Alertness Section (Camera / Drowsiness)
                            _buildAlertnessSection(),
                            const SizedBox(height: 32),

                            // Route & Safety Section (Compliance)
                            _buildComplianceSection(),
                            const SizedBox(height: 32),

                            // Live Tracking Map Section
                            _buildMapSection(),
                            const SizedBox(height: 40),

                            // Footer
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B5E3B), Color(0xFF1A2E1E)],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF2D4A32))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Vehicle & Driver Monitor',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF5F0E8),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Notification Button
              InkWell(
                onTap: _showNotificationsPanel,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8A020),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_notifications.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F1A12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Sign Out Button
              InkWell(
                onTap: _signOut,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome,',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: const Color(0xFFB8C4BB),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: GoogleFonts.playfairDisplay(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: const Color(0xFFF5F0E8),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(String name, String email, String initial) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x47E8A020)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8A020), Color(0xFFB5651D)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8A020).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: widget.driverPhotoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      widget.driverPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF5F0E8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFFB8C4BB),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E3B).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF81C784),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'VERIFIED',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: const Color(0xFF81C784),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF5F0E8),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.speed_rounded,
                iconBg: const Color(0xFFE8A020).withValues(alpha: 0.15),
                iconColor: const Color(0xFFE8A020),
                value: '$_speed km/h',
                label: 'Speed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.gps_fixed_rounded,
                iconBg: const Color(0xFF1B5E3B).withValues(alpha: 0.25),
                iconColor: const Color(0xFF81C784),
                value: _isMonitoring ? 'Active' : 'GPS Ready',
                label: 'Location',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.thermostat_rounded,
                iconBg: const Color(0xFFE57373).withValues(alpha: 0.15),
                iconColor: const Color(0xFFE57373),
                value: _engineTemp,
                label: 'Engine Temp',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D4A32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF5F0E8),
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFFB8C4BB),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertnessSection() {
    return SizedBox(
      height: 600,
      width: double.infinity,
      child: DrowsyCameraController.buildView(),
    );
  }

  Widget _buildComplianceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Route & Safety',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF5F0E8),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E3B).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF81C784), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'On Route',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF81C784),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildComplianceCard(
                icon: Icons.near_me_rounded,
                iconBg: const Color(0xFFE8A020).withValues(alpha: 0.15),
                iconColor: const Color(0xFFE8A020),
                value: _routeDeviation,
                label: 'Deviation',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildComplianceCard(
                icon: Icons.fence_rounded,
                iconBg: const Color(0xFF1B5E3B).withValues(alpha: 0.25),
                iconColor: const Color(0xFF81C784),
                value: _areaStatus,
                label: 'Area Status',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComplianceCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D4A32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF5F0E8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFFB8C4BB),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live Tracking',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF5F0E8),
              ),
            ),
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF81C784),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF81C784).withValues(
                              alpha: 0.4 + _pulseController.value * 0.4,
                            ),
                            blurRadius: 6 + _pulseController.value * 4,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF81C784),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Map Card
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x47E8A020)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Stylized Dark Map Visualizer
                CustomPaint(
                  size: const Size(double.infinity, 260),
                  painter: _MapGridPainter(),
                ),

                // Vehicle Pin Marker
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8A020),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE8A020)
                                  .withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_filled_rounded,
                          color: Color(0xFF0F1A12),
                          size: 20,
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 8,
                        color: const Color(0xFFE8A020),
                      ),
                    ],
                  ),
                ),

                // Location Overlay Pill & Recenter
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2E1E)
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0x47E8A020)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      color: Color(0xFFE8A020), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LIVE POSITION',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: const Color(0xFF7E9084),
                                          ),
                                        ),
                                        Text(
                                          _locationName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFF5F0E8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: const Color(0xFFE8A020),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Map recentered to current vehicle GPS position',
                                  style: GoogleFonts.outfit(),
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF1A2E1E),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF0F1A12),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2D4A32))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showLegalModal('tos'),
                child: Text(
                  'Terms',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFFE8A020),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '•',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF7E9084),
                    fontSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showLegalModal('privacy'),
                child: Text(
                  'Privacy',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFFE8A020),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© 2026 CeylonTourMate',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF7E9084),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering a stylized dark mode GPS road grid with corridor lines
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF142418);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = const Color(0xFF1F3826)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final roadCenterPaint = Paint()
      ..color = const Color(0xFF2D4A32)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Road 1: Diagonal expressway
    final path1 = Path()
      ..moveTo(-20, size.height * 0.8)
      ..cubicTo(size.width * 0.3, size.height * 0.7, size.width * 0.6,
          size.height * 0.3, size.width + 20, size.height * 0.2);
    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path1, roadCenterPaint);

    // Road 2: Cross corridor
    final path2 = Path()
      ..moveTo(size.width * 0.2, -20)
      ..cubicTo(size.width * 0.4, size.height * 0.5, size.width * 0.6,
          size.height * 0.6, size.width * 0.85, size.height + 20);
    canvas.drawPath(path2, roadPaint);
    canvas.drawPath(path2, roadCenterPaint);

    // Active route highlight
    final activeRoutePaint = Paint()
      ..color = const Color(0xFFE8A020).withValues(alpha: 0.7)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final activePath = Path()
      ..moveTo(-20, size.height * 0.8)
      ..cubicTo(size.width * 0.3, size.height * 0.7, size.width * 0.5,
          size.height * 0.5, size.width * 0.5, size.height * 0.5);
    canvas.drawPath(activePath, activeRoutePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
