import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient mesh
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  AppTheme.deepJungle.withOpacity(0.8),
                  AppTheme.darkBg,
                ],
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.saffron.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -60,
            child: Container(
              width: 350, height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cinnamon.withOpacity(0.06),
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo icon
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.spiceGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.saffron.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    size: 52,
                    color: AppTheme.darkBg,
                  ),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .fade(duration: 400.ms),
                const SizedBox(height: 32),
                // App name
                Text(
                  'Ceylon',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.coconutCream,
                    letterSpacing: -1,
                  ),
                )
                    .animate(delay: 300.ms)
                    .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOut)
                    .fade(duration: 500.ms),
                Text(
                  'TRAVEL PLANNER',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.saffron,
                    letterSpacing: 5,
                  ),
                )
                    .animate(delay: 500.ms)
                    .slideY(begin: 0.3, duration: 600.ms, curve: Curves.easeOut)
                    .fade(duration: 500.ms),
                const SizedBox(height: 16),
                Text(
                  'AI-Powered Recommendations',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                )
                    .animate(delay: 700.ms)
                    .fade(duration: 500.ms),
                const SizedBox(height: 60),
                // Loading dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == 0
                          ? AppTheme.saffron
                          : i == 1
                              ? AppTheme.cinnamon
                              : AppTheme.deepJungle,
                    ),
                  )
                      .animate(delay: Duration(milliseconds: 900 + i * 150))
                      .scale(
                        duration: 600.ms,
                        curve: Curves.easeInOut,
                        begin: const Offset(0.5, 0.5),
                      )
                      .fade(duration: 400.ms)),
                ),
              ],
            ),
          ),
          // Bottom tagline
        
        ],
      ),
    );
  }
}