import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_chat_message.dart';
import '../config/api_config.dart';
import 'api_service.dart';

/// AI Chat Service
/// Handles communication with the AI chatbot backend
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
      // Check if we have an API endpoint configured
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

  /// Send message to backend API
  Future<String> _sendToBackend(String message) async {
    try {
      // Try to use the Django backend AI endpoint
      final token = await ApiService.getAccessToken();

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.authEndpoint}/ai/chat/'),
        headers: headers,
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['response'] as String? ??
                 data['data']['message'] as String? ??
                 'I received your message but couldn\'t generate a response.';
        }
      }

      // Fallback to mock response if API fails
      return _getMockResponse(message);
    } catch (e) {
      // Return mock response on error
      return _getMockResponse(message);
    }
  }

  /// Get mock response for demonstration
  String _getMockResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // Blood donation eligibility
    if (lowerMessage.contains('eligible') || lowerMessage.contains('can i donate') || lowerMessage.contains('donate blood')) {
      return '''Most healthy adults can donate blood if they:

• Are between 18-65 years old
• Weigh at least 50kg (110 lbs)
• Are in good general health
• Haven't donated in the last 56 days (for whole blood)

You cannot donate if you:
• Have certain medical conditions
• Have recently gotten a tattoo or piercing
• Have traveled to certain countries
• Are pregnant or breastfeeding

Would you like me to help you find a donation center near you?''';
    }

    // Blood type information
    if (lowerMessage.contains('blood type') || lowerMessage.contains('blood group')) {
      return '''There are 8 main blood types: A+, A-, B+, B-, AB+, AB-, O+, and O-.

• O+ is the most common type (37% of population)
• O- is the universal donor - can give to anyone
• AB+ is the universal recipient - can receive from anyone
• A- and B- are rare types

Your blood type is inherited from your parents and stays the same throughout your life.

Do you know your blood type? I can help you find out!''';
    }

    // Donation process
    if (lowerMessage.contains('process') || lowerMessage.contains('how to donate') || lowerMessage.contains('what happens')) {
      return '''The blood donation process takes about 10-15 minutes:

1. Registration: You'll fill out a form with your details
2. Health Check: We'll check your iron levels, blood pressure, and temperature
3. Donation: You'll comfortably donate about 1 pint of blood
4. Recovery: Enjoy refreshments and relax for 10-15 minutes

After donating:
• Drink plenty of fluids
• Avoid heavy lifting for 24 hours
• You can resume normal activities immediately

One donation can save up to 3 lives! 🩸''';
    }

    // Benefits
    if (lowerMessage.contains('benefit') || lowerMessage.contains('why donate') || lowerMessage.contains('good')) {
      return '''Blood donation benefits are amazing! 💪

For recipients:
• One donation can save up to 3 lives
• Blood cannot be manufactured - only donors can provide it
• Blood is needed every 2 seconds

For donors:
• Free health screening before each donation
• Reduces risk of heart disease
• Burns calories (~650 calories per donation!)
• Gives you a sense of satisfaction

The need is constant - someone needs blood every few seconds. You can make a difference!''';
    }

    // Side effects
    if (lowerMessage.contains('side effect') || lowerMessage.contains('hurt') || lowerMessage.contains('pain') || lowerMessage.contains('after donating')) {
      return '''Blood donation is very safe! Most people feel fine afterward.

Possible minor side effects:
• Slight lightheadedness (goes away quickly)
• Minor bruising at the needle site
• Feeling tired for a few hours

Tips to feel better:
• Eat a healthy meal before donating
• Drink extra water for 24-48 hours
• Avoid strenuous exercise for the rest of the day
• Keep the bandage on for 4-6 hours

Serious side effects are extremely rare. Our staff monitors you throughout to ensure your safety!''';
    }

    // Help/greeting
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi') || lowerMessage.contains('hey') || lowerMessage.contains('help')) {
      return '''Hello! 👋 I'm your Blood Donation AI assistant. I can help you with:

• Eligibility: Check if you can donate blood
• Process: Learn how donation works
• Benefits: Discover why donating matters
• Blood Types: Understand blood type compatibility
• After Care: What to do after donating
• Locations: Find donation centers nearby

What would you like to know about blood donation?''';
    }

    // Find donation center
    if (lowerMessage.contains('where') || lowerMessage.contains('center') || lowerMessage.contains('location') || lowerMessage.contains('nearby')) {
      return '''You can find blood donation centers nearby by using our app's map feature!

📍 To find a center near you:
1. Go to the "Map" tab in the bottom navigation
2. Enable location services
3. You'll see all nearby donation centers

Each center shows:
• Address and contact information
• Operating hours
• Current blood needs

Would you like help with anything else about blood donation?''';
    }

    // SOS/Emergency
    if (lowerMessage.contains('emergency') || lowerMessage.contains('urgent') || lowerMessage.contains('sos') || lowerMessage.contains('help immediately')) {
      return '''🚨 For URGENT blood needs:

If you or someone needs blood urgently, please use our SOS feature:

1. Tap the SOS button on the home screen
2. Fill in the required details (blood type, units needed, hospital)
3. Nearby donors will be notified immediately

Our system connects blood requesters with willing donors in real-time during emergencies.

For life-threatening emergencies, also call emergency services (911 or your local emergency number).

Is this an emergency right now? If so, please use the SOS feature immediately!''';
    }

    // Frequency
    if (lowerMessage.contains('often') || lowerMessage.contains('how many times') || lowerMessage.contains('frequency') || lowerMessage.contains('again')) {
      return '''Here's how often you can donate:

Whole Blood:
• Men: Every 56 days (up to 6 times/year)
• Women: Every 84 days (up to 4 times/year)

Platelets:
• Every 7 days (up to 24 times/year)

Plasma:
• Every 28 days (up to 13 times/year)

The waiting period helps your body replenish what was donated. Regular donors are heroes! 🦸‍♂️

When was your last donation?''';
    }

    // Default response
    return '''That's a great question! As a blood donation assistant, I'm here to help with topics like:

• Donating blood and eligibility
• Blood types and compatibility
• The donation process
• Benefits of donating
• After donation care
• Finding donation centers
• Emergency blood requests

Could you tell me more about what you'd like to know? I'm happy to help! 🩸''';
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
