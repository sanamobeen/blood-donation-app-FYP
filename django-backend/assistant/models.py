"""
Models for AI Chatbot Assistant.

Handles FAQ knowledge base and chat history for blood donation questions.
"""
from django.db import models
import uuid


class FAQ(models.Model):
    """
    Frequently Asked Questions about blood donation.

    Used by the AI chatbot to answer user questions.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    question = models.TextField(
        help_text="The question text"
    )
    answer = models.TextField(
        help_text="The answer text"
    )
    category = models.CharField(
        max_length=100,
        help_text="Category for better matching (e.g., eligibility, safety, process)"
    )
    keywords = models.TextField(
        blank=True,
        help_text="Comma-separated keywords for better matching"
    )
    priority = models.PositiveIntegerField(
        default=0,
        help_text="Higher priority FAQs are matched first"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this FAQ is active"
    )
    target_role = models.CharField(
        max_length=20,
        choices=[
            ('both', 'Both Donor and Patient'),
            ('donor', 'Donor Only'),
            ('patient', 'Patient Only'),
        ],
        default='both',
        help_text="Target audience for this FAQ"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "FAQ"
        verbose_name_plural = "FAQs"
        ordering = ['-priority', 'category']
        indexes = [
            models.Index(fields=['category']),
            models.Index(fields=['is_active']),
            models.Index(fields=['-priority']),
        ]

    def __str__(self):
        return f"{self.question[:50]}..."


class ChatHistory(models.Model):
    """
    Chat history for the AI assistant.

    Tracks user questions and bot responses for analytics and improvement.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    session_id = models.UUIDField(
        null=True,
        blank=True,
        help_text="Session ID for grouping conversations"
    )
    user_question = models.TextField(
        help_text="The user's question"
    )
    bot_answer = models.TextField(
        help_text="The bot's answer"
    )
    matched_faq = models.ForeignKey(
        FAQ,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='chat_entries',
        help_text="The FAQ that was matched (if any)"
    )
    confidence_score = models.FloatField(
        null=True,
        blank=True,
        help_text="Confidence score of the match (0-1)"
    )
    category = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="Category of the matched answer"
    )
    user_satisfied = models.BooleanField(
        null=True,
        blank=True,
        help_text="Whether user was satisfied (feedback)"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Chat History"
        verbose_name_plural = "Chat Histories"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['session_id']),
            models.Index(fields=['-created_at']),
            models.Index(fields=['confidence_score']),
        ]

    def __str__(self):
        return f"Chat: {self.user_question[:50]}..."


class UserFeedback(models.Model):
    """
    User feedback on chatbot responses.

    Used to improve the chatbot's accuracy.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    chat_history = models.ForeignKey(
        ChatHistory,
        on_delete=models.CASCADE,
        related_name='feedbacks',
        help_text="The chat entry this feedback is for"
    )
    is_helpful = models.BooleanField(
        help_text="Whether the response was helpful"
    )
    comment = models.TextField(
        blank=True,
        help_text="Additional user comments"
    )
    suggested_answer = models.TextField(
        blank=True,
        help_text="User's suggested better answer"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "User Feedback"
        verbose_name_plural = "User Feedbacks"
        ordering = ['-created_at']

    def __str__(self):
        return f"Feedback: {'Helpful' if self.is_helpful else 'Not helpful'}"
