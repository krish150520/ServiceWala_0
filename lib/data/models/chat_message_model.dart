import 'package:service_wala_business/core/constants/database_constants.dart';

/// Model representing a single chat message from 'public.messages'.
class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMe;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.isMe = false,
  });

  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderId = json[MessageColumns.senderId]?.toString() ?? '';
    
    // Resolve sender full name if users relation is joined
    String? senderName;
    if (json[DbTables.users] is Map<String, dynamic>) {
      senderName = json[DbTables.users][UserColumns.fullName]?.toString();
    } else if (json['sender_name'] != null) {
      senderName = json['sender_name'].toString();
    }

    return ChatMessageModel(
      id: json[MessageColumns.id]?.toString() ?? '',
      conversationId: json[MessageColumns.conversationId]?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      content: json[MessageColumns.content]?.toString() ?? '',
      createdAt: json[MessageColumns.createdAt] != null
          ? DateTime.tryParse(json[MessageColumns.createdAt].toString()) ??
              DateTime.now()
          : DateTime.now(),
      readAt: json[MessageColumns.readAt] != null
          ? DateTime.tryParse(json[MessageColumns.readAt].toString())
          : null,
      isMe: currentUserId != null && senderId.isNotEmpty && senderId == currentUserId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      MessageColumns.id: id,
      MessageColumns.conversationId: conversationId,
      MessageColumns.senderId: senderId,
      MessageColumns.content: content,
      MessageColumns.createdAt: createdAt.toIso8601String(),
      if (readAt != null) MessageColumns.readAt: readAt!.toIso8601String(),
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isMe,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isMe: isMe ?? this.isMe,
    );
  }
}
