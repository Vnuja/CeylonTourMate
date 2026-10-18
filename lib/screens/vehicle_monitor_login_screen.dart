import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/ceylon_theme.dart';
import 'vehicle_monitor_dashboard_screen.dart';

class VehicleMonitorLoginScreen extends StatefulWidget {
  const VehicleMonitorLoginScreen({super.key});

  @override
  State<VehicleMonitorLoginScreen> createState() => _VehicleMonitorLoginScreenState();
}

class _VehicleMonitorLoginScreenState extends State<VehicleMonitorLoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnim;
  bool _isLoading = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // Floating animation matching CSS: 3s ease-in-out infinite translateY(-8px)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<FirebaseAuth> _getVehicleAuth() async {
    try {
      return FirebaseAuth.instanceFor(app: Firebase.app('VehicleMonitor'));
    } catch (_) {
      try {
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
        final app = await Firebase.initializeApp(
          name: 'VehicleMonitor',
          options: kIsWeb ? webOptions : androidOptions,
        );
        return FirebaseAuth.instanceFor(app: app);
      } catch (_) {
        return FirebaseAuth.instance;
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final FirebaseAuth auth = await _getVehicleAuth();
      final UserCredential userCredential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? account = await googleSignIn.signIn();
        if (account == null) {
          return;
        }
        final GoogleSignInAuthentication googleAuth = await account.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await auth.signInWithCredential(credential);
      }

      if (mounted && userCredential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VehicleMonitorDashboardScreen(
              driverName: userCredential.user?.displayName,
              driverEmail: userCredential.user?.email,
              driverPhotoUrl: userCredential.user?.photoURL,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: CeylonSpiceTheme.saffron),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Google Sign-in: ${e.message ?? e.code}',
                    style: GoogleFonts.outfit(color: CeylonSpiceTheme.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A2E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0x47E8A020)),
            ),
            action: SnackBarAction(
              label: 'Open Demo',
              textColor: CeylonSpiceTheme.saffron,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VehicleMonitorDashboardScreen(
                      driverName: 'Driver Demo',
                      driverEmail: 'driver@ceylontourmate.com',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: CeylonSpiceTheme.saffron),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Google Sign-in: ${e.toString().split(']').last.trim()}',
                    style: GoogleFonts.outfit(color: CeylonSpiceTheme.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A2E1E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0x47E8A020)),
            ),
            action: SnackBarAction(
              label: 'Open Demo',
              textColor: CeylonSpiceTheme.saffron,
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VehicleMonitorDashboardScreen(
                      driverName: 'Driver Demo',
                      driverEmail: 'driver@ceylontourmate.com',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLegalModal(String type) {
    final bool isTos = type == 'tos';
    final String title = isTos ? 'Terms of Service' : 'Privacy Policy';
    final List<Map<String, String>> sections = isTos
        ? [
            {
              'title': '1. Introduction',
              'body':
                  'Welcome to CeylonTourMate Vehicle Monitor. By using our application, you agree to these terms. Please read them carefully.',
            },
            {
              'title': '2. Use of Service',
              'body':
                  'You must follow any policies made available to you within the Service. Do not misuse our Services or interfere with operations.',
            },
            {
              'title': '3. Privacy Protection',
              'body':
                  'Our privacy policies explain how we treat your personal data and protect your privacy when you use our Services.',
            },
            {
              'title': '4. Your Content in our Services',
              'body':
                  'Some of our Services allow you to upload, submit, store, send or receive telemetry and route data. You retain ownership of your intellectual property.',
            },
            {
              'title': '5. Modifying and Terminating Services',
              'body':
                  'We are constantly changing and improving our Services. We may add or remove functionalities or features at any time.',
            },
          ]
        : [
            {
              'title': '1. Data Collection',
              'body':
                  'We collect information to provide better services to all our users, including your Google account details and vehicle telemetry / diagnostics.',
            },
            {
              'title': '2. How We Use Information',
              'body':
                  'We use the information we collect to provide, maintain, protect, and improve driver safety and route monitoring.',
            },
            {
              'title': '3. Transparency and Choice',
              'body':
                  'Our goal is to be clear about what information we collect, so that you can make meaningful choices about how it is used.',
            },
            {
              'title': '4. Information Security',
              'body':
                  'We work hard to protect CeylonTourMate and our users from unauthorized access to or unauthorized alteration of telemetry data.',
            },
          ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF5F0E8),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFB8C4BB)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF2D4A32), height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final item = sections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title']!,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE8A020),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['body']!,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              height: 1.5,
                              color: const Color(0xFFB8C4BB),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A020),
                      foregroundColor: const Color(0xFF0F1A12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('I Understand'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A12),
      body: Stack(
        children: [
          // Background Blob 1 (Top Left)
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

          // Background Blob 2 (Bottom Right)
          Positioned(
            bottom: -120,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE8A020).withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main Center Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Floating Logo Box
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE8A020), Color(0xFFB5651D)],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE8A020).withValues(alpha: 0.35),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // App Title
                      Text(
                        'Vehicle Monitor',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.64,
                          color: const Color(0xFFF5F0E8),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // App Subtitle
                      Text(
                        'CEYLONTOURMATE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.86,
                          color: const Color(0xFFE8A020),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Glass Card (auth-card)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xF21A2E1E), // rgba(26, 46, 30, 0.95)
                                  Color(0xF20F1A12), // rgba(15, 26, 18, 0.95)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0x47E8A020), // rgba(232, 160, 32, 0.28)
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 32,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.24,
                                    color: const Color(0xFFF5F0E8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to continue to your dashboard',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: const Color(0xFFB8C4BB),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Google Sign-in Button
                                MouseRegion(
                                  onEnter: (_) => setState(() => _isHovered = true),
                                  onExit: (_) => setState(() => _isHovered = false),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isLoading ? null : _handleGoogleSignIn,
                                      borderRadius: BorderRadius.circular(14),
                                      splashColor: const Color(0xFFE8A020).withValues(alpha: 0.15),
                                      highlightColor: const Color(0xFF2D4A32),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: double.infinity,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: _isHovered
                                              ? const Color(0xFF2D4A32)
                                              : const Color(0xFF243328),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: _isHovered
                                                ? const Color(0xFFE8A020)
                                                : const Color(0x59E8A020), // rgba(232, 160, 32, 0.35)
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _isHovered
                                                  ? const Color(0xFFE8A020).withValues(alpha: 0.25)
                                                  : Colors.black.withValues(alpha: 0.3),
                                              blurRadius: _isHovered ? 24 : 16,
                                              offset: Offset(0, _isHovered ? 8 : 4),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Color(0xFFE8A020),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const CustomPaint(
                                                      size: Size(20, 20),
                                                      painter: _GoogleLogoPainter(),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      'Continue with Google',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: const Color(0xFFF5F0E8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Legal Text
                      Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF7E9084),
                              height: 1.6,
                            ),
                            children: [
                              const TextSpan(text: 'By signing in, you agree to our\n'),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => _showLegalModal('tos'),
                                  child: Text(
                                    'Terms of Service',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE8A020),
                                      decoration: TextDecoration.underline,
                                      decorationColor: const Color(0xFFE8A020),
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' & '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => _showLegalModal('privacy'),
                                  child: Text(
                                    'Privacy Policy',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE8A020),
                                      decoration: TextDecoration.underline,
                                      decorationColor: const Color(0xFFE8A020),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top Back Navigation Button
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2E1E).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x47E8A020),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFFF5F0E8),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for official 4-color Google "G" logo
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.22;
    final Rect rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w - strokeWidth,
      height: h - strokeWidth,
    );

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red (top arc)
    arcPaint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.14159, 1.45, false, arcPaint);

    // Yellow (left-bottom arc)
    arcPaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 1.95, 1.25, false, arcPaint);

    // Green (bottom arc)
    arcPaint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.72, 1.30, false, arcPaint);

    // Blue (right arc)
    arcPaint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.65, 1.45, false, arcPaint);

    // Blue horizontal center bar
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(w * 0.44, h * 0.40, w * 0.98, h * 0.60),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
