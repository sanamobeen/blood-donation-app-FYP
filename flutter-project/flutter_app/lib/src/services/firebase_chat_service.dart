import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/chat_message.dart';
import '../models/chat_conversation.dart';
import 'api_service.dart';

/// Firebase Chat Service
/// Handles all chat operations using Cloud Firestore
class FirebaseChatService {
  static FirebaseChatService? _instance;
  static FirebaseFirestore? _firestore;

  static const String _conversationsCollection = 'conversations';
  static const String _messagesCollection = 'messages';

  FirebaseChatService._();

  static FirebaseChatService get instance {
    _instance ??= FirebaseChatService._();
    return _instance!;
  }

  /// Initialize Firebase
  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    _firestore = FirebaseFirestore.instance;
  }

  /// Check if device has internet connectivity
  /// On web, always return true since connectivity check isn't reliable
  static Future<bool> hasNetworkConnectivity() async {
    // Skip connectivity check on web platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        // Handle both single result and list of results
        List<ConnectivityResult> results;
        if (connectivityResult is List) {
          results = connectivityResult as List<ConnectivityResult>;
        } else if (connectivityResult is ConnectivityResult) {
          results = [connectivityResult];
        } else {
          return false;
        }

        return results.any((result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn);
      } catch (e) {
        developer.log('Error checking connectivity: $e');
        return true; // Assume connected if check fails
      }
    }
    // For web and desktop, assume connected
    return true;
  }

  /// Get user-friendly error message from Firebase exception
  static String getFirebaseErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('UNAVAILABLE') ||
        errorString.contains('firestore.googleapis.com')) {
      return 'Firebase unavailable. Check your internet connection.';
    } else if (errorString.contains('permission-denied')) {
      return 'Permission denied. You don\'t have access to this chat.';
    } else if (errorString.contains('not-found')) {
      return 'Chat conversation not found in Firebase.';
    } else if (errorString.contains('timeout')) {
      return 'Connection timeout. Please check your internet.';
    } else if (errorString.contains('network')) {
      return 'Network error. Please check your connection.';
    }
    return 'Chat error: $errorString';
  }

  /// Get Firestore instance
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('FirebaseChatService not initialized. Call initialize() first.');
    }
    return _firestore!;
  }

  /// Get current user ID
  Future<String?> getCurrentUserId() async {
    // Get from API service (which has the logged-in user)
    final profile = await ApiService.getProfile();
    if (profile['success'] == true) {
      return profile['data']['user']?['id']?.toString();
    }
    return null;
  }

  /// Create or get conversation between donor and patient
  Future<ChatConversation> getOrCreateConversation({
    required String requestId,
    required String patientId,
    required String patientName,
    required String donorId,
    required String donorName,
  }) async {
    // Check network connectivity first
    final hasNetwork = await FirebaseChatService.hasNetworkConnectivity();
    if (!hasNetwork) {
      throw Exception('No internet connection. Please check your network and try again.');
    }

    // Note: We don't check currentUserId here since the caller already knows
    // who they are based on context (they pass donorId as their own ID)
    // This avoids unnecessary API calls that might fail

    // Generate conversation ID (consistent for both participants)
    final conversationId = _generateConversationId(requestId, patientId, donorId);

    // Check if conversation exists
    final doc = await firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .get();

    if (doc.exists) {
      final conversation = ChatConversation.fromJson(doc.data()!..['id'] = doc.id);

      // Update participant names if they were placeholder/unknown values
      // This ensures names are correct regardless of who created the conversation first
      final data = doc.data()!;
      final needsUpdate = (data['participant1_name'] == 'Unknown' || data['participant1_name'] == 'Patient') ||
          (data['participant2_name'] == 'Unknown' || data['participant2_name'] == 'Donor');

      if (needsUpdate) {
        await firestore
            .collection(_conversationsCollection)
            .doc(conversationId)
            .update({
              'participant1_name': patientName,
              'participant2_name': donorName,
            });
        // Return updated conversation
        return conversation.copyWith(
          participant1Name: patientName,
          participant2Name: donorName,
        );
      }

      return conversation;
    }

    // Create new conversation
    final now = DateTime.now();
    final conversationData = {
      'id': conversationId,
      'request_id': requestId,
      'participant1_id': patientId,
      'participant1_name': patientName,
      'participant1_role': 'patient',
      'participant2_id': donorId,
      'participant2_name': donorName,
      'participant2_role': 'donor',
      'unread_count': 0,
      'updated_at': now.millisecondsSinceEpoch,
      'is_active': true,
      'created_at': now.millisecondsSinceEpoch,
    };

    await firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .set(conversationData);

    return ChatConversation.fromJson(conversationData);
  }

  /// Generate consistent conversation ID
  String _generateConversationId(String requestId, String patientId, String donorId) {
    // Sort IDs to ensure same ID regardless of who creates conversation
    final ids = [patientId, donorId]..sort();
    return 'conv_${requestId}_${ids[0]}_${ids[1]}';
  }

  /// Send text message
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    String? receiverId,
  }) async {
    try {
      // Check network connectivity (but don't block on it - it can be unreliable)
      final hasNetwork = await FirebaseChatService.hasNetworkConnectivity();

      if (!hasNetwork) {
        // Don't throw here - let Firebase handle the actual error
      }


      final messageId = firestore.collection(_conversationsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .doc()
          .id;


      final message = ChatMessage(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        text: text,
        type: MessageType.text,
        timestamp: DateTime.now(),
        isRead: false,
        receiverId: receiverId,
      );

      final messageData = message.toJson();

      // Add message to messages subcollection
      await firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .doc(messageId)
          .set(messageData);


      // Update conversation's last message and timestamp
      await firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .update({
        'last_message': messageData,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });

    } catch (e) {
      rethrow;
    }
  }

  /// Send system message (e.g., "Donor pledged to help")
  Future<void> sendSystemMessage({
    required String conversationId,
    required String text,
  }) async {
    final messageId = firestore.collection(_conversationsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .doc()
        .id;

    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      senderId: 'system',
      senderName: 'System',
      text: text,
      type: MessageType.system,
      timestamp: DateTime.now(),
      isRead: true,
    );

    await firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .doc(messageId)
        .set(message.toJson());
  }

  /// Get messages stream for a conversation
  Stream<List<ChatMessage>> getMessagesStream(String conversationId) {

    return firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) {
        final msg = ChatMessage.fromJson(doc.data());
        return msg;
      })
          .toList();
      return messages;
    });
  }

  /// Get conversations stream for current user
  Stream<List<ChatConversation>> getUserConversationsStream() async* {
    final currentUserId = await getCurrentUserId();
    if (currentUserId == null) {
      yield [];
      return;
    }


    // Listen for conversations where user is participant1
    final stream1 = firestore
        .collection(_conversationsCollection)
        .where('participant1_id', isEqualTo: currentUserId)
        .where('is_active', isEqualTo: true)
        .snapshots();

    // Listen for conversations where user is participant2
    final stream2 = firestore
        .collection(_conversationsCollection)
        .where('participant2_id', isEqualTo: currentUserId)
        .where('is_active', isEqualTo: true)
        .snapshots();

    // Use a broadcast StreamController to properly merge both streams
    final controller = StreamController<List<ChatConversation>>.broadcast();

    // Store latest data from both streams
    final List<ChatConversation> latestFromStream1 = [];
    final List<ChatConversation> latestFromStream2 = [];

    // Listen to stream1 (participant1 conversations)
    StreamSubscription? sub1;
    sub1 = stream1.listen((snapshot) {
      latestFromStream1.clear();
      latestFromStream1.addAll(
        snapshot.docs.map((doc) => ChatConversation.fromJson(doc.data()))
      );
      // Merge and emit
      final merged = [
        ...latestFromStream1,
        ...latestFromStream2,
      ];
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }, onError: (e) {
    });

    // Listen to stream2 (participant2 conversations)
    StreamSubscription? sub2;
    sub2 = stream2.listen((snapshot) {
      latestFromStream2.clear();
      latestFromStream2.addAll(
        snapshot.docs.map((doc) => ChatConversation.fromJson(doc.data()))
      );
      // Merge and emit
      final merged = [
        ...latestFromStream1,
        ...latestFromStream2,
      ];
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }, onError: (e) {
    });

    // Yield from the combined stream
    yield* controller.stream;

    // Clean up when stream is cancelled
    await sub1?.cancel();
    await sub2?.cancel();
    if (!controller.isClosed) {
      await controller.close();
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    final unreadMessages = await firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .collection(_messagesCollection)
        .where('receiver_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .get();

    final batch = firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'is_read': true});
    }

    await batch.commit();
  }

  /// Update conversation unread count
  Future<void> updateUnreadCount({
    required String conversationId,
    required int count,
  }) async {
    await firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .update({'unread_count': count});
  }

  /// Get conversation by ID
  Future<ChatConversation?> getConversation(String conversationId) async {
    final doc = await firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .get();

    if (!doc.exists) return null;

    return ChatConversation.fromJson(doc.data()!..['id'] = doc.id);
  }

  /// Archive/deactivate conversation
  Future<void> archiveConversation(String conversationId) async {
    await firestore
        .collection(_conversationsCollection)
        .doc(conversationId)
        .update({'is_active': false});
  }
}
