import 'package:flutter/foundation.dart';

/// Status of a call record in public.calls
enum CallStatus {
  ringing,
  accepted,
  connected,
  declined,
  ended,
  missed,
  unknown;

  static CallStatus fromString(String? status) {
    switch (status?.toLowerCase().trim()) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'connected':
        return CallStatus.connected;
      case 'declined':
        return CallStatus.declined;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      default:
        return CallStatus.unknown;
    }
  }

  String toDbValue() => name;
}

/// Represents a record in public.calls
class CallModel {
  final String id;
  final String callerId;
  final String receiverId;
  final String? bookingId;
  final CallStatus status;
  final String? channelName;
  final DateTime createdAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;

  // Enriched UI metadata (optional, populated from booking/user lookup)
  final String? callerName;
  final String? callerPhone;
  final String? serviceTitle;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.receiverId,
    this.bookingId,
    required this.status,
    this.channelName,
    required this.createdAt,
    this.connectedAt,
    this.endedAt,
    this.callerName,
    this.callerPhone,
    this.serviceTitle,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String? ?? '',
      callerId: json['caller_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      bookingId: json['booking_id'] as String?,
      status: CallStatus.fromString(json['status'] as String?),
      channelName: json['channel_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      connectedAt: json['connected_at'] != null
          ? DateTime.tryParse(json['connected_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
      callerName: json['caller_name'] as String?,
      callerPhone: json['caller_phone'] as String?,
      serviceTitle: json['service_title'] as String?,
    );
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? receiverId,
    String? bookingId,
    CallStatus? status,
    String? channelName,
    DateTime? createdAt,
    DateTime? connectedAt,
    DateTime? endedAt,
    String? callerName,
    String? callerPhone,
    String? serviceTitle,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      bookingId: bookingId ?? this.bookingId,
      status: status ?? this.status,
      channelName: channelName ?? this.channelName,
      createdAt: createdAt ?? this.createdAt,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
      callerName: callerName ?? this.callerName,
      callerPhone: callerPhone ?? this.callerPhone,
      serviceTitle: serviceTitle ?? this.serviceTitle,
    );
  }
}

/// Token payload returned by generate-agora-token Edge Function
class CallTokenData {
  final String appId;
  final String token;
  final String channelName;
  final int uid;
  final String? callId;

  const CallTokenData({
    required this.appId,
    required this.token,
    required this.channelName,
    required this.uid,
    this.callId,
  });

  factory CallTokenData.fromJson(Map<String, dynamic> raw) {
    // Edge function might return data directly or nested inside a 'data' key
    final map = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    final rawAppId =
        (map['app_id'] ??
                map['appId'] ??
                map['agora_app_id'] ??
                map['agoraAppId'] ??
                '')
            .toString()
            .trim();
    final rawToken =
        (map['token'] ??
                map['agora_token'] ??
                map['agoraToken'] ??
                map['rtc_token'] ??
                map['rtcToken'] ??
                '')
            .toString()
            .trim();
    final rawChannel =
        (map['channel_name'] ??
                map['channelName'] ??
                map['channel'] ??
                map['channel_id'] ??
                map['channelId'] ??
                '')
            .toString()
            .trim();

    final rawUid =
        map['uid'] ??
        map['userId'] ??
        map['user_id'] ??
        map['agora_uid'] ??
        map['agoraUid'] ??
        0;
    final parsedUid = rawUid is int
        ? rawUid
        : int.tryParse(rawUid.toString()) ?? 0;
    final effectiveUid = parsedUid > 0 ? parsedUid : 2;

    final rawCallId =
        (map['call_id'] ??
                map['callId'] ??
                (map['call'] is Map ? map['call']['id'] : null) ??
                map['id'])
            ?.toString()
            .trim();

    if (rawAppId.isEmpty) {
      debugPrint(
        '[CallTokenData] Warning: Missing app_id in Edge Function response',
      );
    }
    if (rawToken.isEmpty) {
      debugPrint(
        '[CallTokenData] Warning: Missing token in Edge Function response',
      );
    }
    if (rawChannel.isEmpty) {
      debugPrint(
        '[CallTokenData] Warning: Missing channel_name in Edge Function response',
      );
    }

    return CallTokenData(
      appId: rawAppId,
      token: rawToken,
      channelName: rawChannel,
      uid: effectiveUid,
      callId: (rawCallId != null && rawCallId.isNotEmpty) ? rawCallId : null,
    );
  }
}
