import 'chat_message.dart';

/// Chat Conversation Model
/// Represents a conversation between a donor and patient
class ChatConversation {
  final String id;
  final String? requestId; // Associated blood request ID
  final String participant1Id;
  final String participant1Name;
  final String? participant1Avatar;
  final String participant1Role; // 'donor' or 'patient'
  final String participant2Id;
  final String participant2Name;
  final String? participant2Avatar;
  final String participant2Role; // 'donor' or 'patient'
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final bool isActive;

  ChatConversation({
    required this.id,
    this.requestId,
    required this.participant1Id,
    required this.participant1Name,
    this.participant1Avatar,
    required this.participant1Role,
    required this.participant2Id,
    required this.participant2Name,
    this.participant2Avatar,
    required this.participant2Role,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Create ChatConversation from JSON (Firestore)
  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String? ?? '',
      requestId: json['request_id'] as String?,
      participant1Id: json['participant1_id'] as String? ?? '',
      participant1Name: json['participant1_name'] as String? ?? 'Unknown',
      participant1Avatar: json['participant1_avatar'] as String?,
      participant1Role: json['participant1_role'] as String? ?? 'donor',
      participant2Id: json['participant2_id'] as String? ?? '',
      participant2Name: json['participant2_name'] as String? ?? 'Unknown',
      participant2Avatar: json['participant2_avatar'] as String?,
      participant2Role: json['participant2_role'] as String? ?? 'patient',
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
          : DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Convert ChatConversation to JSON (for Firestore)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (requestId != null) 'request_id': requestId,
      'participant1_id': participant1Id,
      'participant1_name': participant1Name,
      if (participant1Avatar != null) 'participant1_avatar': participant1Avatar,
      'participant1_role': participant1Role,
      'participant2_id': participant2Id,
      'participant2_name': participant2Name,
      if (participant2Avatar != null) 'participant2_avatar': participant2Avatar,
      'participant2_role': participant2Role,
      if (lastMessage != null) 'last_message': lastMessage!.toJson(),
      'unread_count': unreadCount,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_active': isActive,
    };
  }

  /// Get other participant's info (not current user)
  String getOtherParticipantId(String currentUserId) {
    return participant1Id == currentUserId ? participant2Id : participant1Id;
  }

  String getOtherParticipantName(String currentUserId) {
    return participant1Id == currentUserId ? participant2Name : participant1Name;
  }

  String? getOtherParticipantAvatar(String currentUserId) {
    return participant1Id == currentUserId ? participant2Avatar : participant1Avatar;
  }

  String getOtherParticipantRole(String currentUserId) {
    return participant1Id == currentUserId ? participant2Role : participant1Role;
  }

  /// Get current user's name (for sending messages)
  String getCurrentUserName(String currentUserId) {
    return participant1Id == currentUserId ? participant1Name : participant2Name;
  }

  /// Get current user's avatar (for sending messages)
  String? getCurrentUserAvatar(String currentUserId) {
    return participant1Id == currentUserId ? participant1Avatar : participant2Avatar;
  }

  /// Get display title
  String getDisplayTitle(String currentUserId) {
    final otherName = getOtherParticipantName(currentUserId);
    final otherRole = getOtherParticipantRole(currentUserId);
    return '$otherName ($otherRole)';
  }

  /// Check if conversation has unread messages
  bool get hasUnread => unreadCount > 0;

  /// Get formatted last message preview
  String get lastMessagePreview {
    if (lastMessage == null) return 'No messages yet';
    if (lastMessage!.type == MessageType.image) {
      return '📷 Photo';
    }
    return lastMessage!.text.length > 30
        ? '${lastMessage!.text.substring(0, 30)}...'
        : lastMessage!.text;
  }

  /// Get formatted timestamp
  String get formattedTimestamp {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${updatedAt.day}/${updatedAt.month}';
    }
  }

  /// Create a copy of the conversation with updated fields
  ChatConversation copyWith({
    String? id,
    String? requestId,
    String? participant1Id,
    String? participant1Name,
    String? participant1Avatar,
    String? participant1Role,
    String? participant2Id,
    String? participant2Name,
    String? participant2Avatar,
    String? participant2Role,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      participant1Id: participant1Id ?? this.participant1Id,
      participant1Name: participant1Name ?? this.participant1Name,
      participant1Avatar: participant1Avatar ?? this.participant1Avatar,
      participant1Role: participant1Role ?? this.participant1Role,
      participant2Id: participant2Id ?? this.participant2Id,
      participant2Name: participant2Name ?? this.participant2Name,
      participant2Avatar: participant2Avatar ?? this.participant2Avatar,
      participant2Role: participant2Role ?? this.participant2Role,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
