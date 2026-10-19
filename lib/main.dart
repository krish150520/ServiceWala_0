import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/core/services/incoming_call_manager.dart';
import 'package:service_wala_business/core/services/notification_service.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations & status bar style
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Supabase (safely handles unconfigured/demo environments)
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('[Main] Supabase initialization notice: $e');
  }

  // Launch app immediately so the UI renders without blocking on native services
  runApp(const ServiceWalaPartnerApp());

  // Initialize Firebase Push Notifications and Native CallKit asynchronously in background
  try {
    NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[Main] NotificationService initialization notice: $e');
  }
}

class ServiceWalaPartnerApp extends StatelessWidget {
  const ServiceWalaPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        title: 'ServiceWala Partner',
        navigatorKey: IncomingCallManager.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
