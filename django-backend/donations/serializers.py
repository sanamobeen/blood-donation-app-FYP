"""
Serializers for Donations app.
"""
from rest_framework import serializers
from .models import Donation


class DonationSerializer(serializers.ModelSerializer):
    """
    Serializer for Donation model.
    """
    blood_type_code = serializers.CharField(source='blood_type.code', read_only=True)
    blood_type_name = serializers.CharField(source='blood_type.name', read_only=True)
    hospital_name = serializers.CharField(source='blood_request.hospital_name', read_only=True)
    patient_name = serializers.CharField(source='blood_request.patient_name', read_only=True)
    donor_email = serializers.CharField(source='donor.email', read_only=True)
    donor_name = serializers.CharField(source='donor.full_name', read_only=True)
    is_fulfilled = serializers.BooleanField(read_only=True)
    can_be_acknowledged_by = serializers.SerializerMethodField()

    class Meta:
        model = Donation
        fields = [
            'id',
            'donor',
            'donor_email',
            'donor_name',
            'blood_request',
            'hospital_name',
            'patient_name',
            'blood_type',
            'blood_type_code',
            'blood_type_name',
            'units',
            'donation_date',
            'donation_center',
            'donation_center_address',
            'hemoglobin_level',
            'blood_pressure',
            'health_status',
            'notes',
            'acknowledged_by_patient',
            'acknowledged_at',
            'is_fulfilled',
            'can_be_acknowledged_by',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'is_fulfilled']

    def get_can_be_acknowledged_by(self, obj):
        """Check if current user can acknowledge this donation."""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.can_be_acknowledged_by(request.user)
        return False

    def create(self, validated_data):
        """Create a new donation record."""
        # If user is authenticated, associate the donation with them
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['donor'] = request.user
        return Donation.objects.create(**validated_data)


class DonationCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating a donation record.
    """
    blood_type = serializers.IntegerField(required=False)  # ID of BloodType

    class Meta:
        model = Donation
        fields = [
            'blood_request',
            'blood_type',
            'units',
            'donation_date',
            'donation_center',
            'donation_center_address',
            'hemoglobin_level',
            'blood_pressure',
            'health_status',
            'notes',
        ]

    def validate(self, attrs):
        """Validate donation data."""
        units = attrs.get('units', 1)
        if units <= 0:
            raise serializers.ValidationError("Units must be at least 1.")
        if units > 5:
            raise serializers.ValidationError("Cannot donate more than 5 units at once.")
        return attrs
