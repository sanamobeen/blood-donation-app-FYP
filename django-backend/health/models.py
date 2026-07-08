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

    # New fields to track ineligibility period after failed quiz
    last_failed_quiz_date = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp of the last failed quiz attempt"
    )
    ineligible_until = models.DateTimeField(
        null=True,
        blank=True,
        help_text="User cannot donate/pledge until this datetime (30-day penalty after failed quiz)"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Eligibility Record'
        verbose_name_plural = 'Eligibility Records'

    def __str__(self):
        return f"{self.user.email} - Eligible: {self.is_eligible}"

    def is_currently_eligible(self):
        """
        Check if user is currently eligible to donate/pledge.

        Returns a tuple: (is_eligible, message, cooldown_days_remaining)
        """
        from django.utils import timezone

        # Check if user is in ineligibility period due to failed quiz
        if self.ineligible_until and self.ineligible_until > timezone.now():
            days_remaining = (self.ineligible_until - timezone.now()).days
            return False, "Quiz failed - ineligible period", days_remaining + 1  # Round up

        # Check if eligibility is still valid (within 30 days of last successful quiz)
        if self.is_eligible and self.eligibility_valid_until:
            if self.eligibility_valid_until >= timezone.now().date():
                return True, "Eligible", 0
            else:
                # Eligibility expired but no penalty - user just needs to retake quiz
                return False, "Eligibility expired - retake quiz required", 0

        # User is not eligible (failed quiz and eligibility expired)
        if not self.is_eligible:
            return False, "Not eligible - failed quiz", 0

        return True, "Eligible", 0
