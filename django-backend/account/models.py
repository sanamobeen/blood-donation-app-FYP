from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.core.validators import RegexValidator
from django.utils import timezone
import uuid


class CustomUserManager(BaseUserManager):
    """Custom user manager for email-based authentication."""

    def create_user(self, email, password=None, **extra_fields):
        """Create and save a regular user with the given email and password."""
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        """Create and save a superuser with the given email and password."""
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        return self.create_user(email, password, **extra_fields)


class CustomUser(AbstractUser):
    """
    Custom user model for the Blood Donation app.
    Uses email as the unique identifier instead of username.
    """
    objects = CustomUserManager()
    username = None
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True, db_index=True)
    full_name = models.CharField(max_length=255)
    phone_num = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        validators=[
            RegexValidator(
                regex=r'^\+?1?\d{9,15}$',
                message="Phone number must be entered in the format: '+999999999'. Up to 15 digits allowed."
            )
        ]
    )

    # OTP and phone verification fields
    phone_verified = models.BooleanField(default=False)
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_expires_at = models.DateTimeField(blank=True, null=True)
    otp_attempts = models.IntegerField(default=0)
    otp_last_sent_at = models.DateTimeField(blank=True, null=True)  # Track when OTP was last sent

    # User role
    role = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        choices=[
            ('donor', 'Donor'),
            ('patient', 'Patient'),
            ('admin', 'Admin'),
        ],
        help_text="User role: donor, patient, or admin"
    )

    # Account status
    is_active = models.BooleanField(default=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['full_name']

    class Meta:
        verbose_name = 'User'
        verbose_name_plural = 'Users'
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['phone_num']),
        ]

    def __str__(self):
        return self.email

    def get_full_name(self):
        return self.full_name

    def get_short_name(self):
        return self.full_name.split()[0] if self.full_name else ""

    def generate_otp(self):
        """Generate a 6-digit OTP code"""
        import random
        from django.utils import timezone
        from datetime import timedelta

        self.otp_code = f"{random.randint(100000, 999999)}"
        self.otp_expires_at = timezone.now() + timedelta(minutes=10)
        self.otp_attempts = 0
        self.otp_last_sent_at = timezone.now()  # Track when OTP was sent
        self.save(update_fields=['otp_code', 'otp_expires_at', 'otp_attempts', 'otp_last_sent_at'])
        return self.otp_code

    def can_request_otp(self):
        """
        Check if user can request a new OTP (resend cooldown).

        Returns:
            tuple: (can_request, seconds_remaining)
        """
        from django.utils import timezone
        from datetime import timedelta

        if not self.otp_last_sent_at:
            return True, 0

        cooldown_end = self.otp_last_sent_at + timedelta(seconds=60)  # 60 second cooldown
        time_remaining = (cooldown_end - timezone.now()).total_seconds()

        if time_remaining > 0:
            return False, int(time_remaining)

        return True, 0

    def verify_otp(self, code):
        """Verify the OTP code"""
        from django.utils import timezone

        if not self.otp_code or not self.otp_expires_at:
            return False, "No OTP generated. Please request a new one."

        if timezone.now() > self.otp_expires_at:
            return False, "OTP has expired. Please request a new one."

        if self.otp_attempts >= 3:
            return False, "Too many failed attempts. Please request a new OTP."

        if code != self.otp_code:
            self.otp_attempts += 1
            self.save(update_fields=['otp_attempts'])
            remaining = 3 - self.otp_attempts
            return False, f"Invalid OTP. {remaining} attempts remaining."

        # OTP is correct, mark phone as verified
        self.phone_verified = True
        self.otp_code = None
        self.otp_expires_at = None
        self.otp_attempts = 0
        self.save(update_fields=['phone_verified', 'otp_code', 'otp_expires_at', 'otp_attempts'])
        return True, "Phone verified successfully"

    def clear_otp(self):
        """Clear OTP data"""
        self.otp_code = None
        self.otp_expires_at = None
        self.otp_attempts = 0
        self.save(update_fields=['otp_code', 'otp_expires_at', 'otp_attempts'])


class UserProfile(models.Model):
    """
    Simplified profile model for blood donation users.
    Contains essential information for blood donation setup.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='profile'
    )

    # User Role (mirrored from CustomUser for easier access)
    role = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        choices=[
            ('donor', 'Donor'),
            ('patient', 'Patient'),
            ('admin', 'Admin'),
        ],
        help_text="User role: donor, patient, or admin"
    )

    # Blood Donation Information
    blood_group = models.CharField(
        max_length=5,
        blank=True,
        null=True,
        choices=[
            ('A+', 'A+'),
            ('A-', 'A-'),
            ('B+', 'B+'),
            ('B-', 'B-'),
            ('AB+', 'AB+'),
            ('AB-', 'AB-'),
            ('O+', 'O+'),
            ('O-', 'O-'),
        ],
        help_text="Blood group of the user"
    )

    # Personal Information
    date_of_birth = models.DateField(
        blank=True,
        null=True,
        help_text="User's date of birth"
    )
    gender = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        choices=[
            ('male', 'Male'),
            ('female', 'Female'),
            ('other', 'Other'),
            ('prefer_not_to_say', 'Prefer not to say'),
        ]
    )
    weight = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        blank=True,
        null=True,
        help_text="Weight in kg"
    )

    # Location Information
    city = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        help_text="City of residence"
    )
    location_lat = models.DecimalField(
        max_digits=15,
        decimal_places=12,
        blank=True,
        null=True,
        help_text="Latitude coordinate (-90 to 90)"
    )
    location_lng = models.DecimalField(
        max_digits=15,
        decimal_places=12,
        blank=True,
        null=True,
        help_text="Longitude coordinate (-180 to 180)"
    )
    address = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="Full address or location name from location picker"
    )

    # Profile Picture
    profile_picture = models.URLField(
        blank=True,
        null=True,
        help_text="URL of the user's profile picture"
    )
    profile_picture_updated_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Timestamp of last profile picture update"
    )

    # Push Notification
    fcm_token = models.CharField(
        max_length=500,
        blank=True,
        null=True,
        help_text="FCM device token for push notifications",
        db_index=True
    )
    fcm_token_updated_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Timestamp of last FCM token update"
    )

    # Donation Availability
    is_available_for_donation = models.BooleanField(
        default=True,
        help_text="Whether the donor is currently available for blood donation"
    )
    last_donation_date = models.DateField(
        blank=True,
        null=True,
        help_text="Date of last blood donation"
    )

    # Donor Availability Schedule (Day and Time slots)
    available_all_day = models.BooleanField(
        default=False,
        help_text="Whether the donor is available all day, every day"
    )
    availability = models.JSONField(
        blank=True,
        null=True,
        help_text="Donor availability schedule by day and time slots. Format: {'monday': ['8am_10am', '4pm_6pm'], 'tuesday': [...], ...}"
    )

    # Health Quiz Status
    health_quiz_completed = models.BooleanField(
        default=False,
        help_text="Whether the user has completed the health eligibility quiz"
    )
    health_quiz_completed_at = models.DateTimeField(
        blank=True,
        null=True,
        help_text="Timestamp when health quiz was completed"
    )

    class Meta:
        verbose_name = 'User Profile'
        verbose_name_plural = 'User Profiles'
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['role']),
            models.Index(fields=['blood_group']),
            models.Index(fields=['city']),
            models.Index(fields=['location_lat', 'location_lng']),
        ]

    def __str__(self):
        return f"Profile of {self.user.email}"

    def save(self, *args, **kwargs):
        # Sync role from user if not set or different
        if self.user and self.user.role:
            if self.role != self.user.role:
                self.role = self.user.role
        super().save(*args, **kwargs)


class PasswordReset(models.Model):
    """
    Password reset tokens for users who forgot their password.
    Tokens expire after 1 hour for security.
    """

    id = models.AutoField(primary_key=True)
    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name="password_resets",
        verbose_name="User"
    )
    token = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        verbose_name="Reset Token",
        help_text="Unique token for password reset",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="Created At",
        help_text="Token creation timestamp",
    )
    is_used = models.BooleanField(
        default=False,
        verbose_name="Used",
        help_text="Whether the token has been used"
    )

    class Meta:
        verbose_name = "Password Reset"
        verbose_name_plural = "Password Resets"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["token"]),
            models.Index(fields=["user", "is_used"]),
        ]

    def __str__(self) -> str:
        return f"{self.user.email} - {self.token}"

    def is_valid(self) -> bool:
        """
        Check if token is valid (not used and not expired - 1 hour).
        Returns True if token can be used for password reset.
        """
        if self.is_used:
            return False
        expiration_time = timezone.now() - timezone.timedelta(hours=1)
        return self.created_at > expiration_time
