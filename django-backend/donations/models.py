"""
Models for Donations app.
"""
from django.db import models
import uuid


class Donation(models.Model):
    """
    Donation model representing blood donation records.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Foreign Keys
    donor = models.ForeignKey(
        'account.CustomUser',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='donations',
        help_text="User who made the donation"
    )
    blood_request = models.ForeignKey(
        'blood_requests.BloodRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='donations',
        help_text="Associated blood request (if any)"
    )

    # Donation Details
    blood_type = models.ForeignKey(
        'blood_types.BloodType',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='donations',
        help_text="Blood type donated"
    )
    units = models.PositiveIntegerField(
        default=1,
        help_text="Number of units donated"
    )
    donation_date = models.DateField(
        help_text="Date of donation"
    )
    donation_center = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Name of donation center/hospital"
    )
    donation_center_address = models.TextField(
        blank=True,
        null=True,
        help_text="Address of donation center"
    )

    # Health Data
    hemoglobin_level = models.FloatField(
        null=True,
        blank=True,
        help_text="Hemoglobin level at time of donation"
    )
    blood_pressure = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        help_text="Blood pressure reading (e.g., 120/80)"
    )
    health_status = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        help_text="General health status"
    )
    notes = models.TextField(
        blank=True,
        null=True,
        help_text="Additional notes about the donation"
    )

    # Certificate
    certificate_number = models.CharField(
        max_length=50,
        unique=True,
        null=True,
        blank=True,
        help_text="Unique certificate number"
    )
    certificate_issued = models.BooleanField(
        default=False,
        help_text="Whether donation certificate has been issued"
    )

    # Patient Acknowledgment
    acknowledged_by_patient = models.BooleanField(
        default=False,
        help_text="Whether patient has acknowledged this donation"
    )
    acknowledged_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When patient acknowledged the donation"
    )

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Donation"
        verbose_name_plural = "Donations"
        ordering = ['-donation_date', '-created_at']
        indexes = [
            models.Index(fields=['donor', '-donation_date']),
            models.Index(fields=['blood_request']),
            models.Index(fields=['donation_date']),
        ]

    def __str__(self):
        donor_email = self.donor.email if self.donor else 'Unknown'
        return f"{donor_email} - {self.blood_type} ({self.donation_date})"

    def generate_certificate_number(self):
        """Generate a unique certificate number."""
        import random
        import string
        from datetime import datetime

        if self.certificate_number:
            return self.certificate_number

        # Generate format: DN-2024-XXXX (Year + random)
        year = datetime.now().year
        random_str = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        self.certificate_number = f"DN-{year}-{random_str}"
        self.save(update_fields=['certificate_number'])
        return self.certificate_number

    @property
    def can_be_acknowledged_by(self, user):
        """Check if user can acknowledge this donation (must be the requester of the blood request)"""
        if not self.blood_request:
            return False
        return self.blood_request.requested_by == user

    @property
    def is_fulfilled(self):
        """Check if donation is fulfilled (acknowledged and certificate issued)"""
        return self.acknowledged_by_patient and self.certificate_issued
