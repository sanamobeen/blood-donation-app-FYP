"""
Models for health eligibility quiz system.
"""
from django.db import models
from django.contrib.auth import get_user_model
import uuid

User = get_user_model()


class HealthQuizQuestion(models.Model):
    """
    Quiz questions for blood donation eligibility.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    question_text = models.TextField(help_text="The question text")
    question_type = models.CharField(
        max_length=20,
        choices=[
            ('yes_no', 'Yes/No'),
            ('multiple_choice', 'Multiple Choice'),
            ('text', 'Text Input'),
        ],
        default='yes_no'
    )
    options = models.JSONField(
        default=list,
        blank=True,
        help_text="List of options for the question"
    )
    order = models.PositiveIntegerField(default=0, help_text="Display order")
    is_active = models.BooleanField(default=True, help_text="Whether the question is active")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order']
        verbose_name = 'Health Quiz Question'
        verbose_name_plural = 'Health Quiz Questions'

    def __str__(self):
        return f"{self.order}. {self.question_text[:50]}..."


class HealthQuizResponse(models.Model):
    """
    Stores user's responses to health quiz questions.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='quiz_responses'
    )
    responses = models.JSONField(
        help_text="User's responses as key-value pairs (question_id: answer)"
    )
    is_eligible = models.BooleanField(
        null=True,
        help_text="Whether user is eligible based on quiz responses"
    )
    disqualification_reasons = models.JSONField(
        default=list,
        blank=True,
        help_text="List of reasons why user was disqualified"
    )
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-completed_at']
        verbose_name = 'Health Quiz Response'
        verbose_name_plural = 'Health Quiz Responses'

    def __str__(self):
        return f"Quiz by {self.user.email} - Eligible: {self.is_eligible}"


class EligibilityRecord(models.Model):
    """
    Tracks user's eligibility status over time.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='eligibility_record'
    )
    is_eligible = models.BooleanField(default=True)
    last_quiz_date = models.DateTimeField(null=True, blank=True)
    last_quiz_response = models.ForeignKey(
        HealthQuizResponse,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='eligibility_records'
    )
    disqualification_reasons = models.JSONField(
        default=list,
        blank=True
    )
    eligibility_valid_until = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Eligibility Record'
        verbose_name_plural = 'Eligibility Records'

    def __str__(self):
        return f"{self.user.email} - Eligible: {self.is_eligible}"
