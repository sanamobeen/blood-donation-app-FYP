"""
Serializers for the Blood Requests app.
"""
from rest_framework import serializers
from .models import BloodRequest, DonorResponse
import re


class BloodRequestSerializer(serializers.ModelSerializer):
    """
    Serializer for creating and updating blood requests.
    """

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'patient_name',
            'blood_group',
            'units_needed',
            'units_pledged',
            'units_received',
            'responders_count',
            'urgency_level',
            'contact_number',
            'additional_notes',
            'hospital_name',
            'location',
            # Phase 1: GPS fields
            'location_lat',
            'location_lng',
            'expires_at',
            'status',
            'is_active',
            'created_at',
            'updated_at',
            'requested_by',  # Added to track who created the request
            # Emergency/SOS fields
            'broadcast_radius',
            'emergency_donors_notified',
            'emergency_donors_responded',
            'emergency_expires_at',
            'emergency_first_response_time',
            'emergency_level',
            'is_emergency',
            'active_donor_pledge_id',
        ]
        read_only_fields = ['id', 'status', 'expires_at', 'created_at', 'updated_at', 'requested_by', 'broadcast_radius', 'emergency_donors_notified', 'emergency_donors_responded', 'emergency_expires_at', 'emergency_first_response_time', 'emergency_level', 'is_emergency', 'active_donor_pledge_id']

    def validate_patient_name(self, value):
        """Validate patient name is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Patient name is required.")
        return value.strip()

    def validate_units_needed(self, value):
        """Validate units needed is positive."""
        if value <= 0:
            raise serializers.ValidationError("Units needed must be at least 1.")
        if value > 50:
            raise serializers.ValidationError("Units needed cannot exceed 50.")
        return value

    def validate_contact_number(self, value):
        """Validate contact number format."""
        if value:
            value = value.strip()
            value = re.sub(r'[\s\-\(\)]', '', value)
            # Allow international format (+...) or local format starting with 0
            if not re.match(r'^(\+[1-9]\d{6,14}|0\d{9,14})$', value):
                raise serializers.ValidationError(
                    "Phone number must be in international format (+999999999) or local format starting with 0"
                )
        return value

    def create(self, validated_data):
        """Create a new blood request."""
        # If user is authenticated, associate the request with them
        request = self.context.get('request')
        # Debug logging
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Blood request create - User authenticated: {request.user.is_authenticated if request else 'No request'}")
        if request and request.user.is_authenticated:
            logger.info(f"Setting requested_by to user: {request.user.email}")
            validated_data['requested_by'] = request.user
        else:
            logger.warning("Creating blood request without authenticated user")
        return BloodRequest.objects.create(**validated_data)


class BloodRequestUpdateSerializer(serializers.ModelSerializer):
    """
    Serializer for updating blood requests (status and is_active fields).
    """

    class Meta:
        model = BloodRequest
        fields = ['status', 'is_active', 'additional_notes']
        partial = True


class DetailedBloodRequestSerializer(serializers.ModelSerializer):
    """
    Detailed serializer for blood request creators (includes pledge progress).
    Shows units_pledged, units_received, and responders_count to the request creator.
    """
    is_urgent = serializers.BooleanField(read_only=True)
    requester_name = serializers.SerializerMethodField()
    requester_profile_picture = serializers.SerializerMethodField()
    requested_by_id = serializers.UUIDField(source='requested_by.id', read_only=True, allow_null=True)
    units_remaining = serializers.SerializerMethodField()
    expires_soon = serializers.SerializerMethodField()

    def get_requester_name(self, obj):
        """Get requester name safely, handling None case."""
        if obj.requested_by:
            return obj.requested_by.full_name or obj.requested_by.email
        return None

    def get_requester_profile_picture(self, obj):
        """Get requester profile picture safely, handling None case."""
        if obj.requested_by and hasattr(obj.requested_by, 'profile'):
            return obj.requested_by.profile.profile_picture if obj.requested_by.profile.profile_picture else None
        return None

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'patient_name',
            'blood_group',
            'units_needed',
            'units_pledged',
            'units_received',
            'responders_count',
            'units_remaining',
            'urgency_level',
            'is_urgent',
            'contact_number',
            'hospital_name',
            'location',
            # Phase 1: GPS fields
            'location_lat',
            'location_lng',
            'expires_at',
            'expires_soon',
            'additional_notes',
            'status',
            'is_active',
            'created_at',
            'updated_at',
            'requester_name',
            'requester_profile_picture',
            'requested_by_id',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'is_urgent', 'requester_name', 'requester_profile_picture', 'units_remaining', 'requested_by_id', 'expires_soon']

    def get_units_remaining(self, obj):
        """Calculate units remaining to fulfill the request."""
        return max(0, obj.units_needed - obj.units_pledged)

    def get_expires_soon(self, obj):
        """Check if request expires within 1 hour."""
        if not obj.expires_at:
            return False
        from django.utils import timezone
        from datetime import timedelta
        return obj.expires_at <= timezone.now() + timedelta(hours=1)


class PublicBloodRequestSerializer(serializers.ModelSerializer):
    """
    Public serializer for blood requests (limited fields for public listing).
    """
    is_urgent = serializers.BooleanField(read_only=True)
    requester_name = serializers.SerializerMethodField()
    requester_profile_picture = serializers.SerializerMethodField()
    requested_by_id = serializers.UUIDField(source='requested_by.id', read_only=True, allow_null=True)
    expires_soon = serializers.SerializerMethodField()

    def get_requester_name(self, obj):
        """Get requester name safely, handling None case."""
        if obj.requested_by:
            return obj.requested_by.full_name or obj.requested_by.email
        return None

    def get_requester_profile_picture(self, obj):
        """Get requester profile picture safely, handling None case."""
        if obj.requested_by and hasattr(obj.requested_by, 'profile'):
            return obj.requested_by.profile.profile_picture if obj.requested_by.profile.profile_picture else None
        return None

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'patient_name',
            'blood_group',
            'units_needed',
            # NOTE: units_pledged, units_received, responders_count hidden from donors
            'urgency_level',
            'is_urgent',
            'contact_number',
            'hospital_name',
            'location',
            # Phase 1: GPS fields
            'location_lat',
            'location_lng',
            'expires_at',
            'expires_soon',
            'additional_notes',
            'status',
            'is_active',
            'created_at',
            'requester_name',
            'requester_profile_picture',
            'requested_by_id',
        ]
        read_only_fields = ['id', 'created_at', 'is_urgent', 'requester_name', 'requester_profile_picture', 'requested_by_id', 'expires_soon']

    def get_expires_soon(self, obj):
        """Check if request expires within 1 hour."""
        if not obj.expires_at:
            return False
        from django.utils import timezone
        from datetime import timedelta
        return obj.expires_at <= timezone.now() + timedelta(hours=1)


class DonorResponseSerializer(serializers.ModelSerializer):
    """
    Serializer for donor pledges/responses with full details for patient.
    """
    donor_name = serializers.CharField(source='donor.full_name', read_only=True)
    donor_email = serializers.EmailField(source='donor.email', read_only=True)
    donor_phone = serializers.CharField(source='donor.phone_number', read_only=True)
    donor_blood_group = serializers.SerializerMethodField()
    donor_city = serializers.SerializerMethodField()
    donor_location = serializers.SerializerMethodField()
    donor_age = serializers.SerializerMethodField()
    donor_last_donation = serializers.SerializerMethodField()
    blood_group = serializers.CharField(source='blood_request.blood_group', read_only=True)
    patient_name = serializers.CharField(source='blood_request.patient_name', read_only=True)
    hospital_name = serializers.CharField(source='blood_request.hospital_name', read_only=True)
    status_display = serializers.CharField(read_only=True)
    days_waiting = serializers.IntegerField(read_only=True)

    def get_donor_blood_group(self, obj):
        """Get donor blood group safely."""
        if obj.donor and hasattr(obj.donor, 'profile') and obj.donor.profile:
            return obj.donor.profile.blood_group
        return None

    def get_donor_city(self, obj):
        """Get donor city safely."""
        if obj.donor and hasattr(obj.donor, 'profile') and obj.donor.profile:
            return obj.donor.profile.city
        return None

    def get_donor_location(self, obj):
        """Get donor location safely."""
        if obj.donor and hasattr(obj.donor, 'profile') and obj.donor.profile:
            return obj.donor.profile.address
        return None

    def get_donor_age(self, obj):
        """Get donor age safely (calculated from date_of_birth)."""
        if obj.donor and hasattr(obj.donor, 'profile') and obj.donor.profile:
            if obj.donor.profile.date_of_birth:
                from datetime import date
                today = date.today()
                born = obj.donor.profile.date_of_birth
                return today.year - born.year - ((today.month, today.day) < (born.month, born.day))
        return None

    def get_donor_last_donation(self, obj):
        """Get donor last donation date safely."""
        # Note: UserProfile model doesn't have last_donation_date field
        # This field is not currently tracked in the database
        return None

    class Meta:
        model = DonorResponse
        fields = [
            'id',
            'blood_request',
            'donor',
            'donor_name',
            'donor_email',
            'donor_phone',
            'donor_blood_group',
            'donor_city',
            'donor_location',
            'donor_age',
            'donor_last_donation',
            'blood_group',
            'patient_name',
            'hospital_name',
            'units_pledged',
            'units_received',
            'note',
            'status',
            'status_display',
            'accepted_at',
            'rejected_at',
            'patient_note',
            'created_at',
            'updated_at',
            'completed_at',
            'days_waiting',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'completed_at', 'accepted_at', 'rejected_at']

    def get_status_display(self, obj):
        return obj.get_status_display()

    def get_days_waiting(self, obj):
        """Calculate days since pledge was created"""
        from django.utils import timezone
        return (timezone.now() - obj.created_at).days


class DonorResponsePublicSerializer(serializers.ModelSerializer):
    """
    Public serializer for donor pledges (limited info for privacy).
    """
    donor_name = serializers.CharField(source='donor.full_name', read_only=True)
    blood_group = serializers.CharField(source='blood_request.blood_group', read_only=True)
    status_display = serializers.CharField(read_only=True)

    class Meta:
        model = DonorResponse
        fields = [
            'id',
            'donor_name',
            'blood_group',
            'units_pledged',
            'note',
            'status',
            'status_display',
            'created_at',
            'accepted_at',
        ]
        read_only_fields = ['id', 'created_at', 'accepted_at']


class DonorResponseCreateSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for creating a pledge.
    """
    class Meta:
        model = DonorResponse
        fields = [
            'units_pledged',
            'note',
        ]

    def validate_units_pledged(self, value):
        """Validate units pledged is positive."""
        if value <= 0:
            raise serializers.ValidationError("Units pledged must be at least 1.")
        return value


class AcceptPledgeSerializer(serializers.Serializer):
    """
    Serializer for accepting a pledge (optional note from patient).
    """
    patient_note = serializers.CharField(required=False, allow_blank=True, max_length=500)


class RejectPledgeSerializer(serializers.Serializer):
    """
    Serializer for rejecting a pledge (optional reason for internal tracking).
    """
    reason = serializers.CharField(required=False, allow_blank=True, max_length=500)


class ConfirmDonationSerializer(serializers.Serializer):
    """
    Serializer for confirming donation received from donor.
    """
    units_received = serializers.IntegerField(min_value=1, max_value=50)
    patient_note = serializers.CharField(required=False, allow_blank=True, max_length=500)


class BatchAcceptPledgesSerializer(serializers.Serializer):
    """
    Serializer for batch accepting multiple pledges.
    """
    pledge_ids = serializers.ListField(
        child=serializers.UUIDField(),
        min_length=1,
        max_length=50
    )
    patient_note = serializers.CharField(required=False, allow_blank=True, max_length=500)
