import 'package:service_wala_business/data/models/chat_message_model.dart';

/// UI Chat message model used across ChatScreen, ChatListScreen, and AppState.
class ChatMessage {
  final String id;
  final String bookingId;
  final String? conversationId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMe;

  const ChatMessage({
    required this.id,
    required this.bookingId,
    this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.readAt,
    this.isMe = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    return ChatMessage(
      id: json['id'] ?? '',
      bookingId: json['booking_id'] ?? '',
      conversationId: json['conversation_id'],
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? '',
      message: json['message'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      isMe: json['sender_id'] == currentUserId,
    );
  }

  factory ChatMessage.fromDbModel(
    ChatMessageModel model, {
    required String bookingId,
    String? defaultSenderName,
  }) {
    return ChatMessage(
      id: model.id,
      bookingId: bookingId,
      conversationId: model.conversationId,
      senderId: model.senderId,
      senderName: model.senderName ??
          defaultSenderName ??
          (model.isMe ? 'You' : 'Customer'),
      message: model.content,
      createdAt: model.createdAt,
      readAt: model.readAt,
      isMe: model.isMe,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? bookingId,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? message,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isMe,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isMe: isMe ?? this.isMe,
    );
  }
}
