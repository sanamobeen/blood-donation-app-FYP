"""
Models for the Blood Requests app.
"""
from django.db import models
from django.core.validators import RegexValidator
from django.utils import timezone
import uuid

# Import CustomUser from account app
from account.models import CustomUser


class BloodRequest(models.Model):
    """
    Blood request model for patients needing blood donations.
    Used to create and manage blood requests from hospitals or individuals.
    """

    URGENCY_CHOICES = [
        ('critical', 'Critical'),
        ('urgent', 'Urgent'),
        ('normal', 'Normal'),
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

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('partial', 'Partial'),
        ('fulfilled', 'Fulfilled'),
        ('cancelled', 'Cancelled'),
        ('expired', 'Expired'),  # Phase 1: Auto-expired requests
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient_name = models.CharField(
        max_length=255,
        help_text="Name of the patient requiring blood"
    )
    blood_group = models.CharField(
        max_length=5,
        choices=BLOOD_GROUP_CHOICES,
        help_text="Blood group required"
    )
    units_needed = models.PositiveIntegerField(
        help_text="Number of blood units required (in pints/bags)"
    )
    urgency_level = models.CharField(
        max_length=20,
        choices=URGENCY_CHOICES,
        default='normal',
        help_text="Urgency level of the blood request"
    )
    contact_number = models.CharField(
        max_length=20,
        validators=[
            RegexValidator(
                regex=r'^\+?1?\d{9,15}$',
                message="Phone number must be entered in the format: '+999999999'. Up to 15 digits allowed."
            )
        ],
        help_text="Contact number for the requester"
    )
    additional_notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional notes or medical information (optional)"
    )
    hospital_name = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Hospital name where blood is needed (optional)"
    )
    location = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Location/Hospital address (optional)"
    )

    # GPS coordinates for precise distance calculation
    location_lat = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        blank=True,
        null=True,
        help_text="Latitude coordinate of request location (patient location)"
    )
    location_lng = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        blank=True,
        null=True,
        help_text="Longitude coordinate of request location (patient location)"
    )

    # Request expiration (auto-expire if not fulfilled)
    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When this request automatically expires"
    )

    # Phase 4: Track the currently active (confirmed) donor to prevent race conditions
    # This field will be populated when a patient confirms a pledge
    active_donor_pledge_id = models.UUIDField(
        null=True,
        blank=True,
        help_text="ID of the currently confirmed (active) donor pledge"
    )

    # Emergency/SOS broadcast fields
    broadcast_radius = models.IntegerField(
        default=50,
        help_text="Radius in km for broadcasting the request to nearby donors"
    )
    emergency_donors_notified = models.IntegerField(
        default=0,
        help_text="Number of donors notified for emergency requests"
    )
    emergency_donors_responded = models.IntegerField(
        default=0,
        help_text="Number of donors who responded to emergency requests"
    )
    emergency_expires_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When emergency request expires"
    )
    emergency_first_response_time = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Time of first donor response to emergency"
    )
    emergency_level = models.CharField(
        max_length=20,
        choices=URGENCY_CHOICES,
        default='normal',
        help_text="Emergency level for this request"
    )
    is_emergency = models.BooleanField(
        default=False,
        help_text="Whether this is marked as an emergency request"
    )

    # User who created the request (optional - can be anonymous)
    requested_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='blood_requests',
        help_text="User who created this blood request"
    )

    # Request status
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
        help_text="Current status of the blood request"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether the request is still active/visible"
    )

    # Progress tracking fields
    units_pledged = models.PositiveIntegerField(
        default=0,
        help_text="Total units pledged by donors"
    )
    units_received = models.PositiveIntegerField(
        default=0,
        help_text="Total units actually donated"
    )
    responders_count = models.PositiveIntegerField(
        default=0,
        help_text="Number of donors who pledged"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Blood Request"
        verbose_name_plural = "Blood Requests"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["blood_group"]),
            models.Index(fields=["urgency_level"]),
            models.Index(fields=["status"]),
            models.Index(fields=["is_active"]),
            models.Index(fields=["-created_at"]),
            # Phase 1: GPS and expiration indexes
            models.Index(fields=['location_lat', 'location_lng']),
            models.Index(fields=['expires_at']),
            models.Index(fields=['-urgency_level', '-created_at']),
        ]

    def __str__(self):
        return f"{self.patient_name} - {self.blood_group} ({self.units_needed} units)"

    @property
    def is_urgent(self):
        """Check if request is urgent or critical"""
        return self.urgency_level in ['urgent', 'critical']

    @property
    def units_remaining(self):
        """Calculate units remaining to fulfill the request"""
        return max(0, self.units_needed - self.units_pledged)


class DonorResponse(models.Model):
    """
    Donor pledge with clear status flow for tracking donation progress.

    PHASE 2 STATUS FLOW:
    1. pledged      - Donor submits pledge
    2. shortlisted  - Patient is reviewing (explicit status)
    3. confirmed    - Patient selected donor as PRIMARY (chat opens)
    4. on_the_way  - Donor confirmed they're traveling
    5. arrived      - Donor arrived at location
    6. ready        - Donor ready for donation
    7. completed    - Donation successful and confirmed by patient

    TERMINAL STATUSES:
    - cancelled  - Donor cancelled (before confirmed)
    - rejected   - Patient rejected pledge
    - no_show    - Donor didn't arrive (reported by patient)
    """

    STATUS_CHOICES = [
        ('pledged', 'Pledged'),           # Donor pledged
        ('shortlisted', 'Shortlisted'),   # Patient reviewing
        ('confirmed', 'Confirmed'),       # Patient selected donor (PRIMARY)
        ('on_the_way', 'On The Way'),     # Donor traveling
        ('arrived', 'Arrived'),           # Donor at location
        ('ready', 'Ready for Donation'),  # Donor ready
        ('completed', 'Completed'),       # Donation confirmed
        ('cancelled', 'Cancelled'),       # Donor cancelled
        ('rejected', 'Rejected'),        # Patient rejected
        ('no_show', 'No Show'),          # Donor didn't arrive
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    blood_request = models.ForeignKey(
        BloodRequest,
        on_delete=models.CASCADE,
        related_name='responses',
        help_text="The blood request being responded to"
    )
    donor = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='pledges',
        help_text="User who pledged to donate"
    )
    units_pledged = models.PositiveIntegerField(
        default=1,
        help_text="Number of units pledged"
    )
    units_received = models.PositiveIntegerField(
        default=0,
        help_text="Number of units actually received"
    )
    note = models.TextField(
        blank=True,
        null=True,
        help_text="Note from donor to patient"
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pledged',
        help_text="Current status of the pledge"
    )

    # Patient decision fields
    accepted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When patient accepted this pledge"
    )
    rejected_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When patient rejected this pledge"
    )
    rejection_reason = models.TextField(
        blank=True,
        null=True,
        help_text="Reason for rejection (optional, not shared with donor)"
    )
    patient_note = models.TextField(
        blank=True,
        null=True,
        help_text="Note from patient to donor"
    )

    # Phase 7: Pre-donation verification fields
    verified_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor verified eligibility"
    )
    is_verified = models.BooleanField(
        default=False,
        help_text="Donor has verified eligibility before confirmation"
    )
    verified_availability = models.BooleanField(
        default=False,
        help_text="Donor confirmed availability"
    )
    verified_eligibility = models.BooleanField(
        default=False,
        help_text="Donor confirmed medical eligibility"
    )
    verified_last_donation = models.BooleanField(
        default=False,
        help_text="Donor confirmed last donation date"
    )
    verified_health_questionnaire = models.BooleanField(
        default=False,
        help_text="Donor completed health questionnaire"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Phase 2: Status progression timestamps
    confirmed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When patient confirmed this pledge as primary donor"
    )
    on_the_way_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor confirmed they're on the way"
    )
    arrived_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor arrived at the donation location"
    )
    ready_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When donor marked themselves as ready for donation"
    )
    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the donation was completed"
    )
    no_show_reported_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When patient reported donor as no-show"
    )

    class Meta:
        verbose_name = "Donor Pledge"
        verbose_name_plural = "Donor Pledges"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['blood_request', 'status']),
            models.Index(fields=['donor', 'status']),
            models.Index(fields=['-created_at']),
            models.Index(fields=['status', 'created_at']),
        ]

    def __str__(self):
        donor_info = self.donor.email if self.donor else 'Anonymous'
        return f"{donor_info} - {self.blood_request.blood_group} ({self.units_pledged} units)"

    @property
    def is_pledged(self):
        """Check if pledge is in initial state"""
        return self.status == 'pledged'

    @property
    def is_shortlisted(self):
        """Check if pledge is being reviewed by patient"""
        return self.status == 'shortlisted'

    @property
    def is_confirmed(self):
        """Check if pledge was confirmed by patient"""
        return self.status == 'confirmed'

    @property
    def is_in_progress(self):
        """Check if donation is in progress (on_the_way, arrived, or ready)"""
        return self.status in ['on_the_way', 'arrived', 'ready']

    @property
    def is_completed(self):
        """Check if donation is completed"""
        return self.status == 'completed'

    @property
    def can_be_cancelled_by_donor(self):
        """Check if donor can still cancel"""
        return self.status in ['pledged', 'shortlisted']

    @property
    def can_be_cancelled_by_patient(self):
        """Check if patient can cancel the confirmed donor"""
        return self.status in ['confirmed', 'on_the_way', 'arrived']

    @property
    def days_since_pledge(self):
        """Days since pledge was created"""
        from django.utils import timezone
        return (timezone.now() - self.created_at).days
