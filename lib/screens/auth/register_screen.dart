import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/home/main_shell.dart';
import 'package:service_wala_business/screens/onboarding/profile_setup_screen.dart';

/// Precision Partner Suite - Approved Google Stitch Signup Screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _needsEmailConfirmation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final appState = context.read<AppState>();
    final result = await appState.registerWithEmailPassword(
      email: email,
      password: password,
      fullName: name,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      if (result['needsEmailConfirmation'] == true) {
        setState(() => _needsEmailConfirmation = true);
      } else {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar matching Stitch: Back button, Logo + Partner Registration, Profile Avatar
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
                        'Partner Registration',
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

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: _needsEmailConfirmation
                    ? _buildEmailConfirmationView()
                    : _buildRegistrationForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    final appState = context.watch<AppState>();

    return Column(
      children: [
        const SizedBox(height: 6),

        // Hero Storytelling Header: Centered Specialist Avatar with Verified Badge
        Center(
          child: Column(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Outer Soft Container Ring
                    Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceContainerHigh,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuAawgL6Oucmr5a2shD82mzNx7HHiNNG1KAvHl9cLR42nqlpGGqc2Jz8Fy7D8GiJoGN0SiO2TlaOnRuJqjdYhTSoeKQv7egYg01b6vmZIe4vCY8V0ErcasmRQzPpBzvtymPx0z5JakQ_lf5_SG5ZvS6i4nFVf-U5TrpMiNbg2gHJ2tFT0GSF08NRX0AWA6UimYYFGWudOKYfndjL4a_4KUtYdn9904MNjTBO3SXWjuvLh4xEHRruE0vy7Q',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.stitchSurfaceContainerLowest,
                            child: const Icon(
                              Icons.engineering_rounded,
                              size: 56,
                              color: AppColors.stitchPrimaryCobalt,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Micro Trust Badge (Verified check in bottom-right)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.stitchPrimaryCobalt,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Brand Tag Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceContainer,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.handyman_rounded,
                      size: 14,
                      color: AppColors.stitchPrimaryCobalt,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'PARTNER NETWORK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.stitchPrimaryCobalt,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Main White Card Container matching Stitch
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.stitchSurfaceContainerLowest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                // Header Typography
                const Text(
                  'Join as a Partner',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.stitchOnSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create your ServiceWala Partner account to start receiving high-paying nearby jobs',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.stitchOnSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Error Banner
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

                // Field 1: Full Name
                const Text(
                  'Full Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.stitchOnSurface,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Ramesh Sharma',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.stitchOutline,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.stitchOutline,
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
                        return 'Please enter your full name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name is too short';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Field 2: Email Address
                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurface,
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
                        color: AppColors.stitchOutline,
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
                const SizedBox(height: 14),

                // Field 3: Password
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurface,
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
                      hintText: 'Minimum 6 characters',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.stitchOutline,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.stitchOutline,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.stitchOutline,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
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
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Field 4: Confirm Password
                const Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.stitchOnSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Re-enter your password',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.stitchOutline,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.stitchOutline,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.stitchOutline,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() =>
                              _obscureConfirmPassword = !_obscureConfirmPassword);
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
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 22),

                // Submit Action Button (52px height, solid cobalt, right arrow)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: appState.isLoading ? null : _handleRegister,
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
                                'Create Partner Account',
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

                const SizedBox(height: 20),

                // Already have an account? Sign In Link
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.stitchOnSurfaceVariant,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign In',
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

                const SizedBox(height: 16),

                // Legal Footer
                const Center(
                  child: Text(
                    'By registering, you agree to ServiceWala\'s Partner Terms of Service and Privacy Policy.',
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
    );
  }

  Widget _buildEmailConfirmationView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 36),
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.stitchPrimaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.mail_outline_rounded,
                color: AppColors.stitchPrimaryCobalt,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verify Your Email',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.stitchOnSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'We sent a confirmation link to ${_emailController.text.trim()}.\n\nPlease check your inbox and tap the link to activate your partner account before logging in.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.stitchOnSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stitchPrimaryCobalt,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Proceed to Sign In',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
