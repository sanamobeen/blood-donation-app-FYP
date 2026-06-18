import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/chat_conversation.dart';
import '../../services/firebase_chat_service.dart';
import 'chat_conversation_screen.dart';

/// Chat List Screen
/// Shows all conversations for the current user
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseChatService _chatService = FirebaseChatService.instance;
  List<ChatConversation> _conversations = [];
  bool _isLoading = true;
  String? _currentUserId;
  StreamSubscription<List<ChatConversation>>? _conversationsSubscription;
  bool _isInBuildPhase = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      await FirebaseChatService.initialize();
      _currentUserId = await _chatService.getCurrentUserId();

      // Listen for conversations - store subscription for cleanup
      _conversationsSubscription = _chatService.getUserConversationsStream().listen(
        (conversations) {
          if (mounted && !_isInBuildPhase) {
            setState(() {
              _conversations = conversations;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          // Silent error handling
        },
      );
    } catch (e) {
      if (mounted && !_isInBuildPhase) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openChat(ChatConversation conversation) async {
    if (_currentUserId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(
          conversation: conversation,
          currentUserId: _currentUserId!,
        ),
      ),
    );

    // Refresh conversations when returning
    if (mounted && !_isInBuildPhase) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isInBuildPhase = true;

    // Reset build phase flag after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isInBuildPhase = false;
    });
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState()
              : _buildConversationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start pledging to blood requests\nto begin conversations!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _ConversationTile(
          conversation: conversation,
          currentUserId: _currentUserId ?? '',
          onTap: () => _openChat(conversation),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = conversation.getOtherParticipantName(currentUserId);
    final otherRole = conversation.getOtherParticipantRole(currentUserId);
    final otherAvatar = conversation.getOtherParticipantAvatar(currentUserId);
    final hasUnread = conversation.hasUnread;
    final unreadCount = conversation.unreadCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.softPink,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: otherAvatar != null && otherAvatar.isNotEmpty
                        ? Image.network(
                            otherAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(otherRole);
                            },
                          )
                        : _buildDefaultAvatar(otherRole),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and role
                  Row(
                    children: [
                      Text(
                        otherName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: hasUnread ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          otherRole[0].toUpperCase() + otherRole.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message preview
                  Text(
                    conversation.lastMessagePreview,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Time and unread indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conversation.formattedTimestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
                if (hasUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String role) {
    return Icon(
      role == 'patient' ? Icons.favorite : Icons.bloodtype,
      color: AppColors.primary,
      size: 28,
    );
  }
}
