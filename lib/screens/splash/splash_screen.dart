import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/auth/login_screen.dart';
import 'package:service_wala_business/screens/home/main_shell.dart';
import 'package:service_wala_business/screens/onboarding/profile_setup_screen.dart';

/// Beautiful, branded launch splash screen for ServiceWala Partner.
/// Displays the official app icon logo, brand typography, and handles seamless session routing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeIn,
      ),
    );

    _animController.forward();
    _handleRouting();
  }

  Future<void> _handleRouting() async {
    final appState = context.read<AppState>();

    // Run session check and guarantee at least 1.8 seconds of branded splash visibility
    await Future.wait([
      appState.checkSession(),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);

    if (!mounted) return;

    Widget targetScreen;
    if (appState.isLoggedIn) {
      if (appState.isNewUser) {
        targetScreen = const ProfileSetupScreen();
      } else {
        targetScreen = const MainShell();
      }
    } else {
      targetScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Subtle background decorative radial glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Central branded content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Branded App Icon with smooth rounded border and subtle shadow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.22),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 104,
                          height: 104,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App Title
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Service',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: const Color(0xFF0F172A), // Slate 900
                          ),
                        ),
                        Text(
                          'Wala',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppColors.stitchPrimaryCobalt,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Partner Badge / Tagline
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        'PARTNER NETWORK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.stitchPrimaryCobalt,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom subtle loader
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.stitchPrimaryCobalt,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Empowering Service Professionals',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B), // Slate 500
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
