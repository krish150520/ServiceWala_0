import 'dart:async';
import 'package:flutter/material.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/core/services/agora_call_service.dart';
import 'package:service_wala_business/data/models/call_model.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Active voice call screen with live Agora RTC audio, remote-join detection,
/// call duration timer, mute/speaker toggles, and clean RPC teardown.
class AgoraCallScreen extends StatefulWidget {
  final CallModel call;
  final Future<bool>? initialAcceptFuture;

  const AgoraCallScreen({
    super.key,
    required this.call,
    this.initialAcceptFuture,
  });

  /// Helper to push AgoraCallScreen
  static void open({
    required BuildContext context,
    required CallModel call,
    Future<bool>? initialAcceptFuture,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          call: call,
          initialAcceptFuture: initialAcceptFuture,
        ),
      ),
    );
  }

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen>
    with SingleTickerProviderStateMixin {
  final AgoraCallService _callService = AgoraCallService.instance;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _hasPopped = false;
  bool _wasConnected = false;
  late String _callerName;
  String? _callerPhone;

  @override
  void initState() {
    super.initState();

    _callerName = (widget.call.callerName?.isNotEmpty == true &&
            widget.call.callerName!.toLowerCase() != 'customer')
        ? widget.call.callerName!
        : 'Customer';
    _callerPhone = widget.call.callerPhone;

    if (_callerName == 'Customer' || _callerPhone == null) {
      _resolveCallerDetails();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen for state changes (auto-close when ended, idle, or failed)
    _callService.callState.addListener(_onCallStateChanged);
    _callService.remoteUid.addListener(_onRemoteUidChanged);
    _callService.errorMessage.addListener(_onErrorOccurred);

    // If an accept future was provided, wait on it to catch immediate errors
    if (widget.initialAcceptFuture != null) {
      widget.initialAcceptFuture!.then((success) {
        if (!success && mounted && !_hasPopped) {
          _showErrorSnack(
            _callService.errorMessage.value ?? 'Could not connect call.',
          );
        }
      });
    }
  }

  Future<void> _resolveCallerDetails() async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      final targetUserId = (widget.call.callerId == currentUserId && widget.call.receiverId.isNotEmpty)
          ? widget.call.receiverId
          : (widget.call.callerId.isNotEmpty ? widget.call.callerId : widget.call.receiverId);

      if (targetUserId.isNotEmpty) {
        final userData = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', targetUserId)
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
      debugPrint('[AgoraCallScreen] Error resolving caller: $e');
    }
  }

  void _onCallStateChanged() {
    if (!mounted || _hasPopped) return;
    final state = _callService.callState.value;
    if (state == CallUiState.ended || state == CallUiState.idle) {
      debugPrint('[AgoraCallScreen] Call state changed to $state. Auto-popping screen.');
      _safePop();
    } else if (state == CallUiState.failed) {
      // Auto-dismiss failed call after brief pause so user is not stuck
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted &&
            !_hasPopped &&
            _callService.callState.value == CallUiState.failed) {
          _safePop();
        }
      });
    }
  }

  void _onRemoteUidChanged() {
    if (!mounted || _hasPopped) return;
    final rUid = _callService.remoteUid.value;
    if (rUid != null && rUid > 0) {
      _wasConnected = true;
    } else if (_wasConnected && rUid == null) {
      debugPrint(
        '[AgoraCallScreen] Remote customer disconnected or hung up. Auto-popping screen.',
      );
      _safePop();
    }
  }

  void _onErrorOccurred() {
    if (!mounted || _hasPopped) return;
    final err = _callService.errorMessage.value;
    if (err != null && err.isNotEmpty) {
      _showErrorSnack(err);
    }
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _safePop() {
    if (_hasPopped) return;
    _hasPopped = true;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callService.callState.removeListener(_onCallStateChanged);
    _callService.remoteUid.removeListener(_onRemoteUidChanged);
    _callService.errorMessage.removeListener(_onErrorOccurred);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _endCall() async {
    final activeCallId = _callService.currentCall.value?.id;
    final candidateId = (activeCallId != null &&
            AgoraCallService.isValidUuid(activeCallId))
        ? activeCallId
        : (AgoraCallService.isValidUuid(widget.call.id)
            ? widget.call.id
            : null);

    await _callService.endCall(callId: candidateId);
    _safePop();
  }

  Future<void> _launchCellularCall() async {
    final phone = widget.call.callerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available for this customer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await _endCall();
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final callerName = _callerName;
    final serviceTitle = widget.call.serviceTitle;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate Navy Background
        body: SafeArea(
          child: ValueListenableBuilder<CallUiState>(
            valueListenable: _callService.callState,
            builder: (context, state, _) {
              return Column(
                children: [
                  // Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _endCall,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70,
                            size: 32,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.wifi_calling_3_rounded,
                                size: 14,
                                color: state == CallUiState.connected
                                    ? const Color(0xFF10B981)
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                state == CallUiState.connected
                                    ? 'HD Call Active'
                                    : 'Agora Voice Network',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48), // Balance spacing
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Customer Avatar & Pulsing Rings
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final isWaiting =
                          state == CallUiState.connecting ||
                          state == CallUiState.ringing;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isWaiting)
                            Container(
                              width: 160 * _pulseAnimation.value,
                              height: 160 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                          if (isWaiting)
                            Container(
                              width: 135 * _pulseAnimation.value,
                              height: 135 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                callerName.isNotEmpty
                                    ? callerName[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                  fontSize: 44,
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

                  const SizedBox(height: 28),

                  // Customer Name
                  Text(
                    callerName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (_callerPhone != null && _callerPhone!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _callerPhone!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (serviceTitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      serviceTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Call State / Duration Timer (Connected state only shows when remote user is joined!)
                  ValueListenableBuilder<int>(
                    valueListenable: _callService.callDurationSeconds,
                    builder: (context, seconds, _) {
                      String statusText;
                      Color statusColor = Colors.white70;

                      switch (state) {
                        case CallUiState.connecting:
                          statusText = 'Connecting Voice Engine...';
                          statusColor = AppColors.primary;
                          break;
                        case CallUiState.ringing:
                          statusText = 'Ringing (Waiting for Customer)...';
                          statusColor = AppColors.primary;
                          break;
                        case CallUiState.connected:
                          statusText = _formatDuration(seconds);
                          statusColor = const Color(0xFF10B981); // Emerald
                          break;
                        case CallUiState.ended:
                          statusText = 'Call Ended';
                          statusColor = AppColors.error;
                          break;
                        case CallUiState.failed:
                          statusText = 'Connection Failed';
                          statusColor = AppColors.error;
                          break;
                        case CallUiState.idle:
                          statusText = 'Ready';
                          break;
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (state == CallUiState.failed &&
                              _callService.errorMessage.value != null &&
                              _callService.errorMessage.value!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                left: 24,
                                right: 24,
                              ),
                              child: Text(
                                _callService.errorMessage.value!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  // In-Call Action Grid (Mute, Speakerphone, Direct Phone Fallback)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute Button
                        ValueListenableBuilder<bool>(
                          valueListenable: _callService.isMuted,
                          builder: (context, isMuted, _) {
                            return _CallActionButton(
                              icon: isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: isMuted ? 'Unmute' : 'Mute',
                              isActive: isMuted,
                              onTap: () => _callService.toggleMute(!isMuted),
                            );
                          },
                        ),

                        // Speakerphone Button
                        ValueListenableBuilder<bool>(
                          valueListenable: _callService.isSpeakerOn,
                          builder: (context, isSpeakerOn, _) {
                            return _CallActionButton(
                              icon: isSpeakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_down_rounded,
                              label: isSpeakerOn ? 'Speaker' : 'Earpiece',
                              isActive: isSpeakerOn,
                              onTap: () =>
                                  _callService.toggleSpeaker(!isSpeakerOn),
                            );
                          },
                        ),

                        // Direct Cellular Fallback Button
                        _CallActionButton(
                          icon: Icons.phone_forwarded_rounded,
                          label: 'Cellular Call',
                          onTap: _launchCellularCall,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // End Call Button
                  Center(
                    child: GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFF0F172A) : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
