"""
Models for Chat app.

Phase 8: Private messaging between patients and donors with safety controls.
"""
from django.db import models
import uuid
from account.models import CustomUser


class Conversation(models.Model):
    """
    Conversation between patient and donor for a blood request.

    Only created AFTER pledge is confirmed to ensure safety.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    blood_request = models.ForeignKey(
        'blood_requests.BloodRequest',
        on_delete=models.CASCADE,
        related_name='conversations',
        help_text="The blood request this conversation is about"
    )
    pledge = models.ForeignKey(
        'blood_requests.DonorResponse',
        on_delete=models.CASCADE,
        related_name='conversations',
        null=True,
        blank=True,
        help_text="The most recent pledge that updated this conversation"
    )
    patient = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='patient_conversations',
        help_text="The patient who created the blood request"
    )
    donor = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='donor_conversations',
        help_text="The donor who pledged to donate"
    )

    # Safety controls
    is_active = models.BooleanField(
        default=True,
        help_text="Whether the conversation is active"
    )
    blocked_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='blocked_conversations',
        help_text="User who blocked this conversation"
    )
    blocked_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the conversation was blocked"
    )
    block_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for blocking (optional)"
    )

    # Message limits (anti-spam)
    patient_message_count = models.PositiveIntegerField(
        default=0,
        help_text="Number of messages sent by patient"
    )
    donor_message_count = models.PositiveIntegerField(
        default=0,
        help_text="Number of messages sent by donor"
    )
    last_message_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the last message was sent"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Conversation"
        verbose_name_plural = "Conversations"
        unique_together = [['patient', 'donor']]
        indexes = [
            models.Index(fields=['patient', 'is_active']),
            models.Index(fields=['donor', 'is_active']),
            models.Index(fields=['-created_at']),
            models.Index(fields=['-updated_at']),
        ]

    def __str__(self):
        return f"Chat: {self.patient.email} <-> {self.donor.email}"

    @property
    def other_participant(self, user):
        """Get the other participant in the conversation."""
        if user == self.patient:
            return self.donor
        return self.patient


class Message(models.Model):
    """
    Individual message in a conversation.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='messages',
        help_text="The conversation this message belongs to"
    )
    sender = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='sent_messages',
        help_text="User who sent this message"
    )

    # Message content
    content = models.TextField(
        max_length=5000,
        help_text="Message text content"
    )
    message_type = models.CharField(
        max_length=20,
        choices=[
            ('text', 'Text'),
            ('location', 'Location'),
            ('system', 'System'),
        ],
        default='text',
        help_text="Type of message"
    )

    # Location data (if message_type is location)
    location_lat = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        help_text="Latitude coordinate for location messages"
    )
    location_lng = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        help_text="Longitude coordinate for location messages"
    )

    # Read status
    is_read = models.BooleanField(
        default=False,
        help_text="Whether the message has been read"
    )
    read_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the message was read"
    )

    # Safety
    is_deleted = models.BooleanField(
        default=False,
        help_text="Whether the message was deleted"
    )
    deleted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the message was deleted"
    )
    reported = models.BooleanField(
        default=False,
        help_text="Whether the message was reported"
    )
    report_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for reporting the message"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Message"
        verbose_name_plural = "Messages"
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', '-created_at']),
            models.Index(fields=['sender', '-created_at']),
            models.Index(fields=['is_read']),
            models.Index(fields=['reported']),
        ]

    def __str__(self):
        preview = self.content[:50] if self.content else ''
        return f"{self.sender.email}: {preview}"


class BlockedUser(models.Model):
    """
    Block list for chat safety.

    Users can block other users to prevent receiving messages.
    """
    blocker = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='blocked_users',
        help_text="User who blocked someone"
    )
    blocked = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='blocked_by_users',
        help_text="User who was blocked"
    )
    reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for blocking"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Blocked User"
        verbose_name_plural = "Blocked Users"
        unique_together = ['blocker', 'blocked']
        indexes = [
            models.Index(fields=['blocker']),
            models.Index(fields=['blocked']),
        ]

    def __str__(self):
        return f"{self.blocker.email} blocked {self.blocked.email}"
