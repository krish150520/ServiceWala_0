import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/auth/forgot_password_screen.dart';
import 'package:service_wala_business/screens/auth/register_screen.dart';
import 'package:service_wala_business/screens/home/main_shell.dart';
import 'package:service_wala_business/screens/onboarding/profile_setup_screen.dart';

/// Precision Partner Suite - Approved Google Stitch Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final appState = context.read<AppState>();
    final success = await appState.loginWithEmailPassword(
      email: email,
      password: password,
    );

    if (mounted && success) {
      if (appState.isNewUser) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar matching Stitch: Back button, Logo + Partner Sign In, Profile Avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 22),
                        color: AppColors.stitchOnSurface,
                        onPressed: () => Navigator.maybePop(context),
                        splashRadius: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.stitchPrimary, AppColors.stitchPrimaryContainer],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Partner Sign In',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.stitchOnSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.stitchPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Brand Identity Row (ServiceWala Partner Suite)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.handyman_rounded,
                            color: AppColors.stitchPrimaryCobalt,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'ServiceWala',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.stitchOnSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'PARTNER SUITE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Organic Cutout Graphic Backdrop with Technician Illustration
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Layered pastel backdrop blobs
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                color: AppColors.stitchSecondaryFixed.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.1,
                              child: Container(
                                width: 154,
                                height: 154,
                                decoration: BoxDecoration(
                                  color: AppColors.stitchSurfaceContainer,
                                  borderRadius: BorderRadius.circular(36),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: -0.05,
                              child: Container(
                                width: 154,
                                height: 154,
                                decoration: BoxDecoration(
                                  color: AppColors.stitchPrimaryFixed.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                              ),
                            ),

                            // Technician Illustration Container
                            Container(
                              width: 142,
                              height: 142,
                              decoration: BoxDecoration(
                                color: AppColors.stitchSurfaceContainerLowest,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.network(
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBNrG65THVphYLB3J1tBsQGhg315rAx1PNeovaxXw083wcJ4aitr9Yf7lvNJVBWVRtxWOSguoWKmwpvxPBbsziQWXp7K-Vsmhg-pdnEMNy_JvK2b1A2P5wvaaqgpVKUdWFHjleT7YXkfkZjGSoDWBAXWDXvYlrUGjCvIkKFNeEbEwnq3M3_hB8uWkNXyp-b5gzN-HpLB9n2OwsP4AedgIatUnM5coV_N-A3vraiy6J-gIvj2AwFdTU9GQ',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: AppColors.stitchSurfaceContainerLow,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.engineering_rounded,
                                            size: 52,
                                            color: AppColors.stitchPrimaryCobalt,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Field Specialist',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.stitchPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Floating "Active Dispatch" pill badge
                            Positioned(
                              bottom: 8,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.stitchSurfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(9999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.stitchTertiary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Active Dispatch',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.stitchOnSurface,
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

                    const SizedBox(height: 16),

                    // Main Rounded Bottom Panel (White card matching Stitch)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceContainerLowest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Title & Subtitle
                            const Text(
                              'ServiceWala Partner',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.stitchOnSurface,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Sign in to manage your customer jobs and track daily earnings',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.stitchOnSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Error Message Banner (if any)
                            if (appState.error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.error.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppColors.error,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          appState.error!,
                                          style: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Field 1: Email Address
                            const Text(
                              'EMAIL ADDRESS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.stitchSurfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.stitchOnSurface,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'partner@example.com',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.stitchOutline,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    color: AppColors.stitchOnSurfaceVariant,
                                    size: 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email address';
                                  }
                                  final emailRegex =
                                      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Field 2: Password
                            const Text(
                              'PASSWORD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.stitchOnSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.stitchSurfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.stitchOnSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.stitchOutline,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppColors.stitchOnSurfaceVariant,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.stitchOnSurfaceVariant,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(
                                          () => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                            ),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                ),
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.stitchPrimaryCobalt,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Primary Sign In Button (52px height, solid cobalt, right arrow)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: appState.isLoading ? null : _handleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.stitchPrimaryCobalt,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor:
                                      AppColors.stitchPrimaryCobalt.withValues(alpha: 0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: appState.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Text(
                                            'Sign In',
                                            style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Registration Navigation Link
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'New to ServiceWala? ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.stitchOnSurfaceVariant,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Register as Partner',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.stitchPrimaryCobalt,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Fine Print / Regulatory Disclaimer
                            const Center(
                              child: Text(
                                'By signing in, you agree to ServiceWala Partner Terms & Privacy Policy',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.stitchOutline,
                                  height: 1.4,
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
          ],
        ),
      ),
    );
  }
}
