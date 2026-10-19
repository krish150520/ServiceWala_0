import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:service_wala_business/core/services/agora_call_service.dart';

/// State of an in-app VoIP / direct voice call
enum CallState { idle, connecting, ringing, active, ended, failed }

/// Abstract contract for Voice/Audio calling.
abstract class ICallService {
  Future<void> initialize();
  Future<void> startCall({
    required String channelId,
    required String targetUserId,
    String? callerName,
  });
  Future<void> endCall();
  void toggleMute(bool isMuted);
  void toggleSpeaker(bool isSpeakerOn);
  ValueNotifier<CallState> get callState;
  ValueNotifier<int> get callDurationSeconds;
  ValueNotifier<bool> get isMuted;
  ValueNotifier<bool> get isSpeakerOn;
}

/// Compatibility bridge delegating directly to AgoraCallService.
class CallService implements ICallService {
  static final CallService instance = CallService._();
  CallService._() {
    _agoraService.callState.addListener(_syncState);
    _agoraService.callDurationSeconds.addListener(() {
      _callDurationSeconds.value = _agoraService.callDurationSeconds.value;
    });
    _agoraService.isMuted.addListener(() {
      _isMuted.value = _agoraService.isMuted.value;
    });
    _agoraService.isSpeakerOn.addListener(() {
      _isSpeakerOn.value = _agoraService.isSpeakerOn.value;
    });
  }

  final AgoraCallService _agoraService = AgoraCallService.instance;

  final ValueNotifier<CallState> _callState = ValueNotifier<CallState>(
    CallState.idle,
  );
  final ValueNotifier<int> _callDurationSeconds = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isSpeakerOn = ValueNotifier<bool>(true);

  void _syncState() {
    switch (_agoraService.callState.value) {
      case CallUiState.idle:
        _callState.value = CallState.idle;
        break;
      case CallUiState.connecting:
        _callState.value = CallState.connecting;
        break;
      case CallUiState.ringing:
        _callState.value = CallState.ringing;
        break;
      case CallUiState.connected:
        _callState.value = CallState.active;
        break;
      case CallUiState.ended:
        _callState.value = CallState.ended;
        break;
      case CallUiState.failed:
        _callState.value = CallState.failed;
        break;
    }
  }

  @override
  ValueNotifier<CallState> get callState => _callState;

  @override
  ValueNotifier<int> get callDurationSeconds => _callDurationSeconds;

  @override
  ValueNotifier<bool> get isMuted => _isMuted;

  @override
  ValueNotifier<bool> get isSpeakerOn => _isSpeakerOn;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startCall({
    required String channelId,
    required String targetUserId,
    String? callerName,
  }) async {
    await _agoraService.startOutgoingCall(
      customerName: callerName ?? 'Customer',
      customerId: targetUserId,
      bookingId: channelId,
    );
  }

  @override
  void toggleMute(bool muted) {
    _agoraService.toggleMute(muted);
  }

  @override
  void toggleSpeaker(bool speaker) {
    _agoraService.toggleSpeaker(speaker);
  }

  @override
  Future<void> endCall() async {
    await _agoraService.endCall();
  }
}
