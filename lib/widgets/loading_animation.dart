import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:service_wala_business/config/theme.dart';

/// ServiceWala Partner Loading Animation Suite
/// Provides rich, high-fidelity loading indicators and shimmer skeletons
/// designed to keep users engaged even over slow 2G/3G connections.

// ============================================================================
// 1. Core Shimmer Provider & ShimmerBox
// ============================================================================

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.baseColor = const Color(0xFFE8EDF5),
    this.highlightColor = const Color(0xFFF8FAFC),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double value = _controller.value;
            return LinearGradient(
              begin: const Alignment(-2.0, -0.3),
              end: const Alignment(2.0, 0.3),
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Convenience primitive for drawing rounded shimmer placeholders
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFE5EAF2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ============================================================================
// 2. ServiceWala Branded Pulse Loader with Slow Network Reassurance
// ============================================================================

class ServiceWalaPulseLoader extends StatefulWidget {
  final String message;
  final String? slowNetworkMessage;
  final Duration slowThreshold;
  final bool showSlowMessage;

  const ServiceWalaPulseLoader({
    super.key,
    this.message = 'Fetching latest updates...',
    this.slowNetworkMessage =
        'Slow network detected. Connecting to ServiceWala cloud...',
    this.slowThreshold = const Duration(seconds: 3),
    this.showSlowMessage = true,
  });

  @override
  State<ServiceWalaPulseLoader> createState() => _ServiceWalaPulseLoaderState();
}

class _ServiceWalaPulseLoaderState extends State<ServiceWalaPulseLoader>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  bool _isSlow = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.85,
      upperBound: 1.15,
    )..repeat(reverse: true);

    if (widget.showSlowMessage) {
      Future.delayed(widget.slowThreshold, () {
        if (mounted) {
          setState(() => _isSlow = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing concentric pulse circle
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating gradient track
                AnimatedBuilder(
                  animation: _spinController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _spinController.value * 2 * math.pi,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              AppColors.stitchPrimaryCobalt.withValues(alpha: 0.1),
                              AppColors.stitchPrimaryCobalt,
                              AppColors.stitchTertiaryFixed,
                              AppColors.stitchPrimaryCobalt.withValues(alpha: 0.1),
                            ],
                            stops: const [0.0, 0.45, 0.8, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Masking inner hole to turn gradient into a sleek thin ring
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),

                // Central pulsing brand badge
                ScaleTransition(
                  scale: _pulseController,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Animated message
            Text(
              widget.message,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.stitchOnSurface,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Reassuring slow-network hint if connection takes long
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 400),
              crossFadeState: _isSlow
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(height: 14),
              secondChild: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warningLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.slowNetworkMessage ??
                            'Slow connection. Syncing data...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                        textAlign: TextAlign.center,
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

// ============================================================================
// 3. Home Screen Stitch Skeleton Shimmer
// ============================================================================

class HomeShimmerLoading extends StatelessWidget {
  const HomeShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const ShimmerBox(width: 32, height: 32, borderRadius: 10),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(width: 80, height: 10, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 120, height: 16, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
                const ShimmerBox(width: 36, height: 36, borderRadius: 18),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Personalized Salutation
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 160, height: 26, borderRadius: 6),
                SizedBox(height: 6),
                ShimmerBox(width: 240, height: 14, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 18),

            // 3. Online Availability Card Placeholder
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Row(
                children: [
                  const ShimmerBox(width: 44, height: 44, borderRadius: 14),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(width: 110, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 180, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  const ShimmerBox(width: 48, height: 28, borderRadius: 14),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Digital Earnings Hero Card Placeholder
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      ShimmerBox(width: 130, height: 14, borderRadius: 4),
                      ShimmerBox(width: 70, height: 22, borderRadius: 11),
                    ],
                  ),
                  const ShimmerBox(width: 150, height: 28, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Dashboard Overview 2x2 Grid Placeholders
            const ShimmerBox(width: 150, height: 18, borderRadius: 4),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(
                  child: ShimmerBox(width: double.infinity, height: 86, borderRadius: 16),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ShimmerBox(width: double.infinity, height: 86, borderRadius: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: ShimmerBox(width: double.infinity, height: 86, borderRadius: 16),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ShimmerBox(width: double.infinity, height: 86, borderRadius: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. Bookings & Requests Shimmer Loading
// ============================================================================

class BookingCardsShimmerLoading extends StatelessWidget {
  final int count;
  final String label;

  const BookingCardsShimmerLoading({
    super.key,
    this.count = 3,
    this.label = 'Loading service jobs...',
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EDF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 46, height: 46, borderRadius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          ShimmerBox(width: 140, height: 16, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 90, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    const ShimmerBox(width: 72, height: 24, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 14),
                const ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                const ShimmerBox(width: 180, height: 14, borderRadius: 4),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 80, height: 20, borderRadius: 6),
                    ShimmerBox(width: 110, height: 36, borderRadius: 10),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 5. Chat List Shimmer Loading
// ============================================================================

class ChatListShimmerLoading extends StatelessWidget {
  final int count;

  const ChatListShimmerLoading({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EDF5)),
            ),
            child: Row(
              children: [
                const ShimmerBox(width: 48, height: 48, borderRadius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 130, height: 15, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 180, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    ShimmerBox(width: 45, height: 10, borderRadius: 3),
                    SizedBox(height: 8),
                    ShimmerBox(width: 18, height: 18, borderRadius: 9),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 6. Chat Messages Shimmer Loading
// ============================================================================

class ChatMessagesShimmerLoading extends StatelessWidget {
  const ChatMessagesShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Customer message (left)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 220,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Partner reply (right)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 180,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Customer follow-up (left)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 250,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. Fullscreen App Splash / Boot Loader
// ============================================================================

class FullScreenSplashLoader extends StatefulWidget {
  final String statusText;

  const FullScreenSplashLoader({
    super.key,
    this.statusText = 'Starting Partner Portal...',
  });

  @override
  State<FullScreenSplashLoader> createState() => _FullScreenSplashLoaderState();
}

class _FullScreenSplashLoaderState extends State<FullScreenSplashLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showSlowHint = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.92,
      upperBound: 1.08,
    )..repeat(reverse: true);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSlowHint = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseController,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.stitchPrimary,
                          AppColors.stitchPrimaryCobalt,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.stitchPrimaryCobalt.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ServiceWala Partner',
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
                  'Verified On-Demand Service Network',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Sleek progress bar
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3.5,
                      backgroundColor: Color(0xFFE8EDF5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.stitchPrimaryCobalt,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOutline,
                  ),
                ),

                if (_showSlowHint) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Slow internet detected. Syncing account...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
