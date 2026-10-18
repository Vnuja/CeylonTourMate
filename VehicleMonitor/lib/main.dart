import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';
import 'models/driver_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init notice (will support Demo/Offline mode): $e');
  }
  runApp(const VehicleMonitorApp());
}

class VehicleMonitorApp extends StatelessWidget {
  const VehicleMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090D16),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: _buildAuthHome(),
    );
  }

  Widget _buildAuthHome() {
    try {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasData && snapshot.data != null) {
            final user = snapshot.data!;
            final driver = DriverProfile(
              id: user.uid,
              name: user.displayName ?? 'Driver',
              email: user.email ?? 'driver@ceylontourmate.com',
              photoUrl: user.photoURL,
              vehicleNumber: 'WP NC-4921',
              vehicleModel: 'Toyota HiAce KDH Luxury Van',
              assignedCorridor: 'Southern Coastal Tourist Corridor (E01 / Galle Rd)',
              isDemo: false,
            );
            return HomeScreen(driver: driver, firebaseUser: user);
          }
          return const LoginScreen();
        },
      );
    } catch (_) {
      // If FirebaseAuth throws (e.g. uninitialized Firebase in some test environments)
      return const LoginScreen();
    }
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Color(0xFF2563EB),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
