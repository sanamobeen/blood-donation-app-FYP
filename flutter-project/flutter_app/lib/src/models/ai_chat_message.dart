/// AI Chat Message Model
/// Represents a single message in the AI chatbot conversation
class AIChatMessage {
  final String id;
  final String text;
  final AIMessageType type;
  final DateTime timestamp;
  final bool isTyping;

  AIChatMessage({
    required this.id,
    required this.text,
    required this.type,
    required this.timestamp,
    this.isTyping = false,
  });

  /// Create a user message
  factory AIChatMessage.user(String text) {
    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      type: AIMessageType.user,
      timestamp: DateTime.now(),
    );
  }

  /// Create an AI message
  factory AIChatMessage.ai(String text) {
    return AIChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      type: AIMessageType.ai,
      timestamp: DateTime.now(),
    );
  }

  /// Create a typing indicator message
  factory AIChatMessage.typing() {
    return AIChatMessage(
      id: 'typing-${DateTime.now().millisecondsSinceEpoch}',
      text: '',
      type: AIMessageType.ai,
      timestamp: DateTime.now(),
      isTyping: true,
    );
  }

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
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// AI Message Type Enum
enum AIMessageType {
  user,
  ai,
}
