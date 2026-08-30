import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/ceylon_theme.dart';
import 'providers/auth_provider.dart' as app_auth;
import 'services/chat_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: CeylonSpiceTheme.darkBg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CeylonTravelPlannerApp());
}

class CeylonTravelPlannerApp extends StatelessWidget {
  const CeylonTravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'CeylonTourMate',
        debugShowCheckedModeBanner: false,
        theme: CeylonSpiceTheme.darkTheme,
        // SplashScreen (from the Explore app) plays first, then hands off
        // to AuthWrapper, which routes to Login or the merged MainShell.
        home: const SplashScreen(),
      ),
    );
  }
}
