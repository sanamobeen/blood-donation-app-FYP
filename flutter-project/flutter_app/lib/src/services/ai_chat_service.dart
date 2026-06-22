import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_chat_message.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI Chat Service
/// Handles communication with the AI chatbot backend using LLM
class AIChatService {
  AIChatService._();

  static final AIChatService instance = AIChatService._();

  final List<AIChatMessage> _messages = [];
  final _messageController = StreamController<List<AIChatMessage>>.broadcast();

  Stream<List<AIChatMessage>> get messagesStream => _messageController.stream;
  List<AIChatMessage> get messages => List.unmodifiable(_messages);

  /// Add a message to the conversation
  void _addMessage(AIChatMessage message) {
    _messages.add(message);
    _messageController.add(List.unmodifiable(_messages));
  }

  /// Send a user message and get AI response
  Future<String> sendMessage(String userMessage) async {
    // Add user message
    _addMessage(AIChatMessage.user(userMessage));

    // Add typing indicator
    final typingMessage = AIChatMessage.typing();
    _addMessage(typingMessage);

    try {
      final response = await _sendToBackend(userMessage);

      // Remove typing indicator
      _messages.remove(typingMessage);

      // Add AI response
      _addMessage(AIChatMessage.ai(response));

      return response;
    } catch (e) {
      // Remove typing indicator
      _messages.remove(typingMessage);

      // Add error message
      final errorMsg = 'Sorry, I encountered an error. Please try again.';
      _addMessage(AIChatMessage.ai(errorMsg));

      return errorMsg;
    }
  }

  /// Send message to backend API using LLM
  Future<String> _sendToBackend(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role') ?? 'both';

      final token = await ApiService.getAccessToken();

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Use LLM by default (use_llm=true)
      final response = await http.post(
        Uri.parse('${ApiConfig.assistantEndpoint}/chat/'),
        headers: headers,
        body: jsonEncode({
          'question': message,
          'role': userRole,
          'use_llm': true,  // Always use LLM
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['answer'] as String? ??
                 'I received your message but couldn\'t generate a response.';
        } else {
          return data['message'] as String? ?? 'Unable to process your request.';
        }
      } else if (response.statusCode == 503) {
        return 'The chatbot service is currently unavailable. Please try again later.';
      } else {
        debugPrint('Backend API error. Status: ${response.statusCode}, Body: ${response.body}');
        return 'Sorry, I encountered an error communicating with the server.';
      }
    } catch (e) {
      debugPrint('Backend API error: $e');
      return 'Sorry, I couldn\'t connect to the server. Please check your internet connection.';
    }
  }

  /// Clear chat history
  void clearHistory() {
    _messages.clear();
    _messageController.add(List.unmodifiable(_messages));
  }

  /// Dispose the stream controller
  void dispose() {
    _messageController.close();
  }
}
