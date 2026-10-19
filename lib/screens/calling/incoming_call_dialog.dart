import 'dart:async';
import 'package:flutter/material.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/core/services/agora_call_service.dart';
import 'package:service_wala_business/data/models/call_model.dart';
import 'package:service_wala_business/screens/calling/agora_call_screen.dart';

import 'package:service_wala_business/core/services/supabase_service.dart';

/// Modal dialog shown when an incoming VoIP audio call is detected via Realtime.
class IncomingCallDialog extends StatefulWidget {
  final CallModel call;
  final VoidCallback onDismiss;

  const IncomingCallDialog({
    super.key,
    required this.call,
    required this.onDismiss,
  });

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _missedTimer;
  Timer? _statusCheckTimer;
  bool _isResponding = false;
  late String _callerName;
  String? _callerPhone;
  late String _serviceTitle;

  @override
  void initState() {
    super.initState();

    _callerName = (widget.call.callerName?.isNotEmpty == true &&
            widget.call.callerName!.toLowerCase() != 'customer')
        ? widget.call.callerName!
        : 'Customer';
    _callerPhone = widget.call.callerPhone;
    _serviceTitle = widget.call.serviceTitle?.isNotEmpty == true
        ? widget.call.serviceTitle!
        : 'Service Request';

    if (_callerName == 'Customer' || _callerPhone == null) {
      _resolveCallerDetails();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fast periodic check to auto-dismiss if customer cuts/cancels the call before agent responds
    _statusCheckTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (timer) async {
        if (!mounted || _isResponding) {
          timer.cancel();
          return;
        }
        try {
          final res = await SupabaseService.client
              .from('calls')
              .select('status')
              .eq('id', widget.call.id)
              .maybeSingle();
          if (res != null) {
            final status = (res['status'] as String? ?? '').toLowerCase();
            if (status == 'ended' ||
                status == 'declined' ||
                status == 'missed') {
              debugPrint(
                '[IncomingCallDialog] Customer cut/cancelled incoming call ($status). Auto-dismissing dialog.',
              );
              timer.cancel();
              if (mounted && !_isResponding) {
                _isResponding = true;
                _missedTimer?.cancel();
                Navigator.of(context, rootNavigator: true).pop();
                widget.onDismiss();
              }
            }
          }
        } catch (_) {}
      },
    );

    // 45-Second Missed Call Timeout
    _missedTimer = Timer(const Duration(seconds: 45), () async {
      if (mounted && !_isResponding) {
        debugPrint(
          '[IncomingCallDialog] 45s timeout reached. Marking call as missed.',
        );
        _isResponding = true;
        _statusCheckTimer?.cancel();
        await AgoraCallService.instance.markCallMissed(widget.call.id);
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          widget.onDismiss();
        }
      }
    });
  }

  Future<void> _resolveCallerDetails() async {
    try {
      // 1. Check users by callerId
      if (widget.call.callerId.isNotEmpty) {
        final userData = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', widget.call.callerId)
            .maybeSingle();

        if (userData != null && mounted) {
          final name = (userData['full_name'] ??
                  userData['name'] ??
                  userData['display_name'])
              ?.toString()
              .trim();
          final phone = (userData['phone'] ??
                  userData['phone_number'] ??
                  userData['mobile'])
              ?.toString()
              .trim();

          if (name != null && name.isNotEmpty && name.toLowerCase() != 'customer') {
            setState(() {
              _callerName = name;
              if (phone != null && phone.isNotEmpty) _callerPhone = phone;
            });
            return;
          }
        }
      }

      // 2. Check bookings by bookingId
      if (widget.call.bookingId != null && widget.call.bookingId!.isNotEmpty) {
        final bData = await SupabaseService.client
            .from('bookings')
            .select()
            .eq('id', widget.call.bookingId!)
            .maybeSingle();

        if (bData != null && mounted) {
          final custId = bData['customer_id']?.toString();
          if (custId != null && custId.isNotEmpty) {
            final custUser = await SupabaseService.client
                .from('users')
                .select()
                .eq('id', custId)
                .maybeSingle();

            if (custUser != null && mounted) {
              final name = (custUser['full_name'] ??
                      custUser['name'] ??
                      custUser['display_name'])
                  ?.toString()
                  .trim();
              final phone = (custUser['phone'] ??
                      custUser['phone_number'] ??
                      custUser['mobile'])
                  ?.toString()
                  .trim();

              if (name != null && name.isNotEmpty && name.toLowerCase() != 'customer') {
                setState(() {
                  _callerName = name;
                  if (phone != null && phone.isNotEmpty) _callerPhone ??= phone;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[IncomingCallDialog] Error resolving caller: $e');
    }
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _missedTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleDecline() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    _statusCheckTimer?.cancel();
    _missedTimer?.cancel();

    try {
      await AgoraCallService.instance.declineIncomingCall(widget.call.id);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        widget.onDismiss();
      }
    }
  }

  Future<void> _handleAccept() async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    _statusCheckTimer?.cancel();
    _missedTimer?.cancel();

    // Close dialog
    Navigator.of(context, rootNavigator: true).pop();
    widget.onDismiss();

    final enrichedForScreen = widget.call.copyWith(
      callerName: _callerName,
      callerPhone: _callerPhone,
      serviceTitle: _serviceTitle,
    );

    // Start accepting in background and immediately push call screen
    final navContext = context;
    final acceptFuture = AgoraCallService.instance.acceptIncomingCall(
      enrichedForScreen,
    );

    if (mounted) {
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => AgoraCallScreen(
            call: enrichedForScreen,
            initialAcceptFuture: acceptFuture,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final callerName = _callerName;
    final serviceTitle = _serviceTitle;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleDecline();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), // Deep Slate Navy
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge: Incoming VoIP Call
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'INCOMING AUDIO CALL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Animated Pulsing Avatar
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 130 * _pulseAnimation.value,
                        height: 130 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      Container(
                        width: 110 * _pulseAnimation.value,
                        height: 110 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            callerName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Caller Details
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),

              if (_callerPhone != null && _callerPhone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 13,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _callerPhone!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 6),

              Text(
                serviceTitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'ServiceWala Voice Call (Agora HD)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 36),

              // Action Buttons: Decline & Accept
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _isResponding ? null : _handleDecline,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFEF4444), // Red
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Accept Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _isResponding ? null : _handleAccept,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10B981), // Emerald Green
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
