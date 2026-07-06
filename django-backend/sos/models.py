"""
Models for the SOS (Emergency) app.
"""
from django.db import models
from django.core.validators import RegexValidator
from django.utils import timezone
import uuid

# Import CustomUser from account app
from account.models import CustomUser


class SOSRequest(models.Model):
    """
    SOS Emergency Blood Request model.
    Used for urgent, life-threatening situations requiring immediate blood donation.
    """

    URGENCY_CHOICES = [
        ('critical', 'Critical - Immediate'),
        ('urgent', 'Urgent - Within 2 hours'),
    ]

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('awaiting_arrival', 'Awaiting Donor Arrival'),
        ('in_progress', 'Donation In Progress'),
        ('resolved', 'Resolved'),
        ('cancelled', 'Cancelled'),
        ('expired', 'Expired - No Responses'),
    ]

    GENDER_CHOICES = [
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
    ]

    BLOOD_GROUP_CHOICES = [
        ('A+', 'A+'),
        ('A-', 'A-'),
        ('B+', 'B+'),
        ('B-', 'B-'),
        ('AB+', 'AB+'),
        ('AB-', 'AB-'),
        ('O+', 'O+'),
        ('O-', 'O-'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # User who created the SOS request
    requester = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='sos_requests',
        help_text="User who created this SOS request"
    )

    # Blood type required
    blood_type = models.CharField(
        max_length=5,
        choices=BLOOD_GROUP_CHOICES,
        help_text="Blood group required"
    )

    # Patient information
    patient_name = models.CharField(
        max_length=255,
        help_text="Name of the patient"
    )
    age = models.PositiveIntegerField(
        help_text="Age of the patient"
    )
    gender = models.CharField(
        max_length=20,
        choices=GENDER_CHOICES,
        help_text="Gender of the patient"
    )

    # Hospital information
    hospital_name = models.CharField(
        max_length=255,
        help_text="Hospital name"
    )
    hospital_address = models.TextField(
        help_text="Full hospital address"
    )
    hospital_lat = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text="Hospital latitude"
    )
    hospital_lng = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        null=True,
        blank=True,
        help_text="Hospital longitude"
    )

    # Contact information
    contact_phone = models.CharField(
        max_length=20,
        validators=[
            RegexValidator(
                regex=r'^\+?1?\d{9,15}$',
                message="Phone number must be entered in the format: '+999999999'. Up to 15 digits allowed."
            )
        ],
        help_text="Emergency contact number"
    )

    # Blood requirement
    units_needed = models.PositiveIntegerField(
        default=1,
        help_text="Number of blood units required"
    )

    # Status tracking
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='active',
        help_text="Current status of the SOS request"
    )
    responders_count = models.PositiveIntegerField(
        default=0,
        help_text="Number of people who have responded"
    )

    # Resolution tracking
    resolution_note = models.TextField(
        blank=True,
        null=True,
        help_text="Note about how the request was resolved"
    )
    resolved_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the request was resolved"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "SOS Request"
        verbose_name_plural = "SOS Requests"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["blood_type"]),
            models.Index(fields=["status"]),
            models.Index(fields=["hospital_lat", "hospital_lng"]),
            models.Index(fields=["-created_at"]),
        ]

    def __str__(self):
        return f"SOS: {self.patient_name} - {self.blood_type} at {self.hospital_name}"

    @property
    def is_active(self):
        """Check if SOS request is still active"""
        return self.status == 'active'

    @property
    def time_remaining_minutes(self):
        """Calculate time remaining until 2-hour mark"""
        if self.status != 'active':
            return 0
        elapsed = (timezone.now() - self.created_at).total_seconds() / 60
        return max(0, 120 - int(elapsed))


class SOSResponse(models.Model):
    """
    Track donor responses to SOS requests.
    """

    RESPONSE_STATUS_CHOICES = [
        ('pending', 'Pending - Awaiting Patient Review'),
        ('accepted', 'Accepted by Patient'),
        ('rejected', 'Rejected by Patient'),
        ('in_transit', 'Donor is On the Way'),
        ('arrived', 'Donor Arrived at Hospital'),
        ('donating', 'Donation In Progress'),
        ('donated', 'Donation Completed'),
        ('no_show', 'Donor Did Not Arrive'),
        ('cancelled', 'Cancelled by Donor'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    sos_request = models.ForeignKey(
        SOSRequest,
        on_delete=models.CASCADE,
        related_name='responses',
        help_text="The SOS request being responded to"
    )

    responder = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='sos_responses',
        help_text="User responding to the SOS"
    )

    # Response details
    can_help = models.BooleanField(
        default=True,
        help_text="Whether the responder can help"
    )
    estimated_arrival_minutes = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Estimated time to reach hospital in minutes"
    )
    note = models.TextField(
        blank=True,
        null=True,
        help_text="Additional note from responder"
    )

    # Confirmation/Status tracking
    status = models.CharField(
        max_length=20,
        choices=RESPONSE_STATUS_CHOICES,
        default='pending',
        help_text="Status of the donor response"
    )
    accepted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When patient accepted this donor"
    )
    departed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor departed for hospital"
    )
    arrived_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor arrived at hospital"
    )
    donated_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor completed donation"
    )
    cancelled_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor cancelled their response"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "SOS Response"
        verbose_name_plural = "SOS Responses"
        ordering = ["-created_at"]
        unique_together = ['sos_request', 'responder']  # One response per SOS per user
        indexes = [
            models.Index(fields=["sos_request", "responder"]),
        ]

    def __str__(self):
        return f"{self.responder.email} -> SOS {self.sos_request.id}"
