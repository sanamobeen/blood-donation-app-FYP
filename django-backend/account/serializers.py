"""
Serializers for the Blood Donation authentication API.

Provides serialization and validation for:
- User Registration
- User Login
- User Profile
"""
from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils import timezone
from datetime import date
import re
import logging
from .models import CustomUser, UserProfile, PasswordReset

logger = logging.getLogger(__name__)


class UserRegistrationSerializer(serializers.ModelSerializer):
    """
    Serializer for user registration with comprehensive validation.
    """
    password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'},
        help_text="Password (min 8 characters, must include letters and numbers)"
    )
    password_confirm = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'},
        help_text="Confirm password (must match password)"
    )

    class Meta:
        model = CustomUser
        fields = ('email', 'password', 'password_confirm', 'full_name', 'phone_num', 'role')
        extra_kwargs = {
            'email': {'required': True, 'help_text': 'Valid email address'},
            'full_name': {'required': True, 'help_text': 'Full legal name'},
            'phone_num': {'required': False, 'help_text': 'Phone number in format: +999999999'},
            'role': {'required': False, 'help_text': 'User role: donor or patient'}
        }

    def validate_email(self, value):
        """Validate email is unique and properly formatted."""
        value = value.lower().strip()
        if CustomUser.objects.filter(email=value).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value

    def validate_full_name(self, value):
        """Validate full name is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Full name is required.")
        return value.strip()

    def validate_password(self, value):
        """
        Validate password meets Django's password requirements.
        - Minimum 8 characters
        - Cannot be too similar to other personal info
        - Cannot be a common password
        - Cannot be entirely numeric
        """
        if len(value) < 8:
            raise serializers.ValidationError("Password must be at least 8 characters long.")

        # Check if password contains at least one letter and one digit
        if not any(char.isdigit() for char in value):
            raise serializers.ValidationError("Password must contain at least one number.")

        if not any(char.isalpha() for char in value):
            raise serializers.ValidationError("Password must contain at least one letter.")

        # Run Django's built-in password validators
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(str(e))

        return value

    def validate(self, attrs):
        """Validate password confirmation matches."""
        if attrs.get('password') != attrs.get('password_confirm'):
            raise serializers.ValidationError({
                "password_confirm": "Password fields didn't match."
            })
        return attrs

    def create(self, validated_data):
        """Create a new user with validated data."""
        validated_data.pop('password_confirm')

        # Extract password for proper hashing
        password = validated_data.pop('password')

        # Extract role if provided
        role = validated_data.pop('role', None)

        # Create user with role (password is hashed by create_user method)
        user = CustomUser.objects.create_user(
            email=validated_data['email'],
            password=password,
            full_name=validated_data['full_name'],
            phone_num=validated_data.get('phone_num', '')
        )

        # Set role if provided
        if role:
            user.role = role
            user.save()

        return user


class UserLoginSerializer(serializers.Serializer):
    """
    Serializer for user login with comprehensive error messages.
    """
    email = serializers.EmailField(
        required=True,
        help_text="Registered email address"
    )
    password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'},
        help_text="User password"
    )

    def validate(self, attrs):
        """Validate credentials and return authenticated user."""
        email = attrs.get('email').lower().strip()
        password = attrs.get('password')

        if not email or not password:
            raise serializers.ValidationError({
                "detail": "Both email and password are required."
            })

        # Authenticate user (uses custom AUTH_USER_MODEL)
        user = authenticate(username=email, password=password)

        if not user:
            raise serializers.ValidationError({
                "detail": "Invalid email or password."
            })

        if not user.is_active:
            raise serializers.ValidationError({
                "detail": "This account has been deactivated. Please contact support."
            })

        attrs['user'] = user
        return attrs


class UserSerializer(serializers.ModelSerializer):
    """
    Read-only serializer for user profile display.
    """
    phone_verified = serializers.BooleanField(read_only=True)

    class Meta:
        model = CustomUser
        fields = (
            'id', 'email', 'full_name', 'phone_num', 'phone_verified',
            'date_joined', 'last_login', 'role'
        )
        read_only_fields = ('id', 'date_joined', 'last_login', 'phone_verified')


class UserUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating user profile information.
    """
    class Meta:
        model = CustomUser
        fields = ('full_name', 'phone_num', 'role')
        extra_kwargs = {
            'full_name': {'required': False},
            'phone_num': {'required': False},
            'role': {'required': False}
        }

    def validate_phone_num(self, value):
        """Validate phone number format if provided."""
        if value:
            import re
            value = value.strip()
            value = re.sub(r'[\s\-\(\)]', '', value)
            if not re.match(r'^\+?[1-9]\d{6,14}$', value):
                raise serializers.ValidationError(
                    "Phone number must be in international format: +999999999"
                )
            return value
        return value


class PasswordChangeSerializer(serializers.Serializer):
    """
    Serializer for changing user password.
    """
    old_password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'}
    )
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'}
    )
    new_password_confirm = serializers.CharField(
        required=True,
        write_only=True,
        style={'input_type': 'password'}
    )

    def validate_old_password(self, value):
        """Verify old password is correct."""
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Current password is incorrect.")
        return value

    def validate_new_password(self, value):
        """Validate new password meets requirements."""
        if len(value) < 8:
            raise serializers.ValidationError("Password must be at least 8 characters long.")
        if not any(char.isdigit() for char in value):
            raise serializers.ValidationError("Password must contain at least one number.")
        if not any(char.isalpha() for char in value):
            raise serializers.ValidationError("Password must contain at least one letter.")
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(str(e))
        return value

    def validate(self, attrs):
        """Ensure new passwords match."""
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({
                "new_password_confirm": "New password fields didn't match."
            })
        return attrs


class ForgotPasswordSerializer(serializers.Serializer):
    """Serializer for forgot password requests"""
    email = serializers.EmailField(required=True, help_text="User's email address")

    def validate_email(self, value):
        """Validate that email exists in the system"""
        email = value.strip().lower()
        if not CustomUser.objects.filter(email=email).exists():
            logger.warning(f"Password reset requested for non-existent email: {email}")
            raise serializers.ValidationError(
                "No account found with this email address. Please check your email or register a new account."
            )
        return email


def validate_password_strength(password: str) -> str:
    """
    Custom password strength validator following security best practices.
    Ensures password meets complexity requirements for enterprise security.
    """
    if len(password) < 8:
        raise serializers.ValidationError("Password must be at least 8 characters long")

    if len(password) > 128:
        raise serializers.ValidationError("Password must not exceed 128 characters")

    if not re.search(r"[A-Z]", password):
        raise serializers.ValidationError(
            "Password must contain at least one uppercase letter"
        )

    if not re.search(r"[a-z]", password):
        raise serializers.ValidationError(
            "Password must contain at least one lowercase letter"
        )

    if not re.search(r"\d", password):
        raise serializers.ValidationError(
            "Password must contain at least one number"
        )

    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        raise serializers.ValidationError(
            "Password must contain at least one special character"
        )

    # Check for common patterns
    common_patterns = ["password", "123456", "qwerty", "admin", "welcome"]
    password_lower = password.lower()
    if any(pattern in password_lower for pattern in common_patterns):
        raise serializers.ValidationError(
            "Password contains common patterns and is not secure enough"
        )

    return password


class ResetPasswordSerializer(serializers.Serializer):
    """Serializer for resetting password with token"""
    email = serializers.EmailField(required=True, help_text="User's email address")
    token = serializers.UUIDField(required=True, help_text="Password reset token")
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        validators=[validate_password, validate_password_strength],
        help_text="New password",
    )
    confirm_password = serializers.CharField(
        required=True, write_only=True, help_text="Confirm new password"
    )

    def validate(self, attrs):
        """Validate token, password confirmation, and user email"""
        if attrs["new_password"] != attrs["confirm_password"]:
            raise serializers.ValidationError(
                {
                    "new_password": "Password fields didn't match.",
                    "confirm_password": "Passwords must be identical",
                }
            )

        email = attrs["email"].strip().lower()
        try:
            user = CustomUser.objects.get(email=email)
            attrs["user"] = user
        except CustomUser.DoesNotExist:
            raise serializers.ValidationError(
                {"email": "No user found with this email address"}
            )

        # Import here to avoid circular imports
        from .models import PasswordReset

        try:
            reset = PasswordReset.objects.get(token=attrs["token"], user=user)
            if not reset.is_valid():
                raise serializers.ValidationError(
                    {"token": "Token has expired or already used. Please request a new one."}
                )
            attrs["reset"] = reset
        except PasswordReset.DoesNotExist:
            raise serializers.ValidationError(
                {"token": "Invalid token. Please request a new password reset."}
            )

        return attrs


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for user profile - matches the profile page design.
    """
    user_full_name = serializers.CharField(source='user.full_name', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    age = serializers.SerializerMethodField()
    profile_picture_url = serializers.CharField(read_only=True)

    class Meta:
        model = UserProfile
        fields = [
            'id', 'user_full_name', 'email', 'username',
            'blood_group', 'age', 'gender', 'weight',
            'location_lat', 'location_lng', 'city', 'address',
            'date_of_birth', 'profile_picture', 'profile_picture_url'
        ]
        read_only_fields = ['id', 'user_full_name', 'email', 'username', 'age', 'profile_picture_url']

    def get_age(self, obj):
        """Calculate age from date of birth."""
        if obj.date_of_birth:
            today = date.today()
            return today.year - obj.date_of_birth.year - (
                (today.month, today.day) < (obj.date_of_birth.month, obj.date_of_birth.day)
            )
        return None

    def validate_date_of_birth(self, value):
        """Validate date of birth - user must be at least 18 years old."""
        if value:
            today = date.today()
            age = today.year - value.year - (
                (today.month, today.day) < (value.month, value.day)
            )
            if age < 18:
                raise serializers.ValidationError(
                    "You must be at least 18 years old to donate blood."
                )
            if age > 65:
                raise serializers.ValidationError(
                    "Maximum age for blood donation is 65 years."
                )
        return value

    def validate_weight(self, value):
        """Validate weight - minimum 50kg required for donation."""
        if value is not None:
            if value < 50:
                raise serializers.ValidationError(
                    "Minimum weight required for blood donation is 50kg."
                )
            if value > 200:
                raise serializers.ValidationError(
                    "Please enter a valid weight (maximum 200kg)."
                )
        return value

    def validate_blood_group(self, value):
        """Validate blood group."""
        valid_blood_groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        if value and value not in valid_blood_groups:
            raise serializers.ValidationError(
                f"Invalid blood group. Must be one of: {', '.join(valid_blood_groups)}"
            )
        return value


class UserProfileCreateSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for creating a new user profile.
    """
    class Meta:
        model = UserProfile
        fields = [
            'blood_group', 'date_of_birth',
            'gender', 'weight',
            'location_lat', 'location_lng', 'city', 'address',
            'profile_picture'
        ]

    def validate_gender(self, value):
        """Normalize gender value to lowercase."""
        if value:
            # Normalize to lowercase to match model choices
            value = value.lower().strip()
            valid_genders = ['male', 'female', 'other', 'prefer_not_to_say']
            if value not in valid_genders:
                raise serializers.ValidationError(
                    f"Invalid gender. Must be one of: {', '.join(valid_genders)}"
                )
        return value

    def validate_date_of_birth(self, value):
        """Validate date of birth - user must be at least 18 years old."""
        if value:
            today = date.today()
            age = today.year - value.year - (
                (today.month, today.day) < (value.month, value.day)
            )
            if age < 18:
                raise serializers.ValidationError(
                    "You must be at least 18 years old to donate blood."
                )
            if age > 65:
                raise serializers.ValidationError(
                    "Maximum age for blood donation is 65 years."
                )
        return value

    def validate_weight(self, value):
        """Validate weight - minimum 50kg required for donation."""
        if value is not None and value < 50:
            raise serializers.ValidationError(
                "Minimum weight required for blood donation is 50kg."
            )
        return value

    def validate_blood_group(self, value):
        """Validate blood group."""
        valid_blood_groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        if value and value not in valid_blood_groups:
            raise serializers.ValidationError(
                f"Invalid blood group. Must be one of: {', '.join(valid_blood_groups)}"
            )
        return value

    def create(self, validated_data):
        """Create user profile for the authenticated user."""
        user = self.context['request'].user
        profile = UserProfile.objects.create(user=user, **validated_data)
        return profile


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for updating user profile.
    """
    class Meta:
        model = UserProfile
        fields = [
            'blood_group', 'date_of_birth',
            'gender', 'weight',
            'location_lat', 'location_lng', 'city', 'address',
            'profile_picture'
        ]

    def validate_gender(self, value):
        """Normalize gender value to lowercase."""
        if value:
            # Normalize to lowercase to match model choices
            value = value.lower().strip()
            valid_genders = ['male', 'female', 'other', 'prefer_not_to_say']
            if value not in valid_genders:
                raise serializers.ValidationError(
                    f"Invalid gender. Must be one of: {', '.join(valid_genders)}"
                )
        return value

    def validate_date_of_birth(self, value):
        """Validate date of birth - user must be at least 18 years old."""
        if value:
            today = date.today()
            age = today.year - value.year - (
                (today.month, today.day) < (value.month, value.day)
            )
            if age < 18:
                raise serializers.ValidationError(
                    "You must be at least 18 years old to donate blood."
                )
            if age > 65:
                raise serializers.ValidationError(
                    "Maximum age for blood donation is 65 years."
                )
        return value

    def validate_weight(self, value):
        """Validate weight - minimum 50kg required for donation."""
        if value is not None and value < 50:
            raise serializers.ValidationError(
                "Minimum weight required for blood donation is 50kg."
            )
        return value

    def validate_blood_group(self, value):
        """Validate blood group."""
        valid_blood_groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        if value and value not in valid_blood_groups:
            raise serializers.ValidationError(
                f"Invalid blood group. Must be one of: {', '.join(valid_blood_groups)}"
            )
        return value

    def update(self, instance, validated_data):
        """Update profile."""
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance


class PublicProfileSerializer(serializers.ModelSerializer):
    """
    Public serializer for user profile (limited fields for privacy).
    """
    user_full_name = serializers.CharField(source='user.full_name', read_only=True)
    age = serializers.SerializerMethodField()

    class Meta:
        model = UserProfile
        fields = [
            'id', 'user_full_name', 'blood_group', 'age', 'city'
        ]

    def get_age(self, obj):
        """Calculate age from date of birth."""
        if obj.date_of_birth:
            today = date.today()
            return today.year - obj.date_of_birth.year - (
                (today.month, today.day) < (obj.date_of_birth.month, obj.date_of_birth.day)
            )
        return None


class DonationRecordSerializer(serializers.Serializer):
    """
    Serializer for recording a blood donation.
    """
    def validate(self, attrs):
        """Validate that user is eligible to donate."""
        user = self.context['request'].user
        try:
            profile = user.profile
            if not profile.is_eligible:
                raise serializers.ValidationError(
                    f"You are not eligible to donate yet. Next eligible date: {profile.next_eligible_date}"
                )
            if not profile.is_available_for_donation:
                raise serializers.ValidationError(
                    "Please mark yourself as available for donation first."
                )
        except UserProfile.DoesNotExist:
            raise serializers.ValidationError(
                "Please complete your profile before recording a donation."
            )
        return attrs

    def create(self, validated_data):
        """Record donation for user."""
        user = self.context['request'].user
        profile = user.profile
        profile.record_donation()
        return profile


class MedicalInfoUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating medical information (medications, allergies, health conditions).
    """
    class Meta:
        model = UserProfile
        fields = ['medications', 'allergies', 'health_conditions']

    def validate_medications(self, value):
        """Validate medications list."""
        if not isinstance(value, list):
            raise serializers.ValidationError("Medications must be a list.")
        return value

    def validate_allergies(self, value):
        """Validate allergies list."""
        if not isinstance(value, list):
            raise serializers.ValidationError("Allergies must be a list.")
        return value

    def validate_health_conditions(self, value):
        """Validate health conditions list."""
        if not isinstance(value, list):
            raise serializers.ValidationError("Health conditions must be a list.")
        return value

    def update(self, instance, validated_data):
        """Update medical info fields."""
        instance.medications = validated_data.get('medications', instance.medications)
        instance.allergies = validated_data.get('allergies', instance.allergies)
        instance.health_conditions = validated_data.get('health_conditions', instance.health_conditions)
        instance.save()
        return instance
