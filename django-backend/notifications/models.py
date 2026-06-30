from django.db import models
import uuid


class DeviceToken(models.Model):
    """
    Store FCM device tokens for push notifications.
    Each user can have multiple tokens (multiple devices).
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        'account.CustomUser',
        on_delete=models.CASCADE,
        related_name='device_tokens'
    )
    token = models.CharField(max_length=255, unique=True, db_index=True)
    device_type = models.CharField(max_length=10)  # ios, android, web
    device_name = models.CharField(max_length=100, blank=True)  # Optional device name
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'device_tokens'
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['token']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.device_type} ({self.device_name or 'Unknown'})"


class Notification(models.Model):
    """
    Notification model for in-app notifications to users.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Recipient
    user = models.ForeignKey(
        'account.CustomUser',
        on_delete=models.CASCADE,
        related_name='notifications',
        help_text="User receiving the notification"
    )

    # Notification content
    title = models.CharField(
        max_length=255,
        help_text="Notification title"
    )
    message = models.TextField(
        help_text="Notification message"
    )

    # Notification type
    type = models.CharField(
        max_length=50,
        help_text="Type of notification (pledge, message, request_updated, etc.)"
    )

    # Related entities (optional)
    related_request_id = models.UUIDField(
        null=True,
        blank=True,
        help_text="ID of related blood request"
    )
    related_pledge_id = models.UUIDField(
        null=True,
        blank=True,
        help_text="ID of related pledge"
    )
    related_conversation_id = models.UUIDField(
        null=True,
        blank=True,
        help_text="ID of related conversation"
    )

    # Additional data (JSON field for extra information)
    data = models.JSONField(
        null=True,
        blank=True,
        help_text="Additional notification data (donor info, location, etc.)"
    )

    # Status
    is_read = models.BooleanField(
        default=False,
        help_text="Whether notification has been read"
    )
    read_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When notification was read"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Notification"
        verbose_name_plural = "Notifications"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['user', 'is_read']),
            models.Index(fields=['type']),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.title}"
