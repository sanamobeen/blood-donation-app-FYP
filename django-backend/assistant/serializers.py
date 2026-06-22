"""
Serializers for AI Chatbot Assistant API.
"""
from rest_framework import serializers
from .models import FAQ, ChatHistory, UserFeedback


class FAQSerializer(serializers.ModelSerializer):
    """Serializer for FAQ model."""

    class Meta:
        model = FAQ
        fields = ['id', 'question', 'answer', 'category', 'keywords', 'priority', 'is_active', 'target_role']
        read_only_fields = ['id', 'created_at', 'updated_at']


class ChatHistorySerializer(serializers.ModelSerializer):
    """Serializer for ChatHistory model."""

    class Meta:
        model = ChatHistory
        fields = ['id', 'session_id', 'user_question', 'bot_answer', 'matched_faq',
                  'confidence_score', 'category', 'user_satisfied', 'created_at']
        read_only_fields = ['id', 'created_at']


class ChatRequestSerializer(serializers.Serializer):
    """Serializer for chat request."""

    question = serializers.CharField(
        max_length=1000,
        help_text="The user's question"
    )
    role = serializers.CharField(
        required=False,
        default='both',
        help_text="User role for role-specific responses (donor, patient, or both)"
    )
    session_id = serializers.UUIDField(
        required=False,
        help_text="Optional session ID for conversation tracking"
    )
    use_llm = serializers.BooleanField(
        required=False,
        default=True,  # Default to LLM
        help_text="Use LLM service instead of TF-IDF chatbot"
    )


class ChatResponseSerializer(serializers.Serializer):
    """Serializer for chat response."""

    answer = serializers.CharField(help_text="The bot's answer")
    confidence = serializers.FloatField(help_text="Confidence score (0-1)")
    category = serializers.CharField(help_text="Category of the answer")
    matched_question = serializers.CharField(
        required=False,
        help_text="The matched FAQ question"
    )
    session_id = serializers.UUIDField(help_text="Session ID for tracking")


class FeedbackSerializer(serializers.ModelSerializer):
    """Serializer for UserFeedback model."""

    class Meta:
        model = UserFeedback
        fields = ['id', 'chat_history', 'is_helpful', 'comment', 'suggested_answer', 'created_at']
        read_only_fields = ['id', 'created_at']
