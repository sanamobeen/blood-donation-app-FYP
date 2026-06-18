/// Chat Message Model
/// Represents a single message in a donor-patient conversation
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String text;
  final String? imageUrl;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? receiverId;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.text,
    this.imageUrl,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.receiverId,
  });

  /// Create ChatMessage from JSON (Firestore)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Unknown',
      senderAvatar: json['sender_avatar'] as String?,
      text: json['text'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      type: MessageType.fromString(json['type'] as String? ?? 'text'),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      receiverId: json['receiver_id'] as String?,
    );
  }

  /// Convert ChatMessage to JSON (for Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
      'text': text,
      if (imageUrl != null) 'image_url': imageUrl,
      'type': type.value,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'is_read': isRead,
      if (receiverId != null) 'receiver_id': receiverId,
    };
  }

  /// Check if message is from current user
  bool get isFromMe => false; // Will be set based on current user ID

  /// Get formatted time
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Get full formatted date and time
  String get formattedDateTime {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

/// Message Type Enum
enum MessageType {
  text('text'),
  image('image'),
  system('system');

  final String value;
  const MessageType(this.value);

  static MessageType fromString(String value) {
    switch (value) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }
}
