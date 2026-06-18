"""
Serializers for the SOS (Emergency) app.
"""
from rest_framework import serializers
from .models import SOSRequest, SOSResponse
from account.models import CustomUser


class SOSRequestSerializer(serializers.ModelSerializer):
    """
    Serializer for creating SOS requests.
    """
    requester_name = serializers.CharField(source='requester.full_name', read_only=True)
    requester_email = serializers.EmailField(source='requester.email', read_only=True)
    time_remaining_minutes = serializers.IntegerField(read_only=True)
    is_active = serializers.BooleanField(read_only=True)

    class Meta:
        model = SOSRequest
        fields = [
            'id', 'requester', 'requester_name', 'requester_email',
            'blood_type', 'patient_name', 'age', 'gender',
            'hospital_name', 'hospital_address', 'hospital_lat', 'hospital_lng',
            'contact_phone', 'units_needed', 'status', 'responders_count',
            'resolution_note', 'resolved_at', 'time_remaining_minutes', 'is_active',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'requester', 'status', 'responders_count', 'created_at', 'updated_at']

    def validate_age(self, value):
        """Validate age is reasonable"""
        if value < 0 or value > 120:
            raise serializers.ValidationError("Please enter a valid age.")
        return value

    def validate_units_needed(self, value):
        """Validate units needed"""
        if value < 1:
            raise serializers.ValidationError("At least 1 unit is required.")
        if value > 10:
            raise serializers.ValidationError("For large requirements, please contact hospital directly.")
        return value

    def create(self, validated_data):
        """Create SOS request for the authenticated user"""
        user = self.context['request'].user
        validated_data['requester'] = user
        return super().create(validated_data)


class PublicSOSRequestSerializer(serializers.ModelSerializer):
    """
    Public serializer for SOS requests (limited fields).
    """
    requester_name = serializers.CharField(source='requester.full_name', read_only=True)
    blood_type_display = serializers.CharField(source='get_blood_type_display', read_only=True)
    time_remaining_minutes = serializers.IntegerField(read_only=True)
    is_active = serializers.BooleanField(read_only=True)

    class Meta:
        model = SOSRequest
        fields = [
            'id', 'requester_name', 'blood_type', 'blood_type_display',
            'hospital_name', 'hospital_lat', 'hospital_lng',
            'units_needed', 'status', 'responders_count',
            'time_remaining_minutes', 'is_active', 'created_at'
        ]


class SOSResponseSerializer(serializers.ModelSerializer):
    """
    Serializer for SOS responses.
    """
    responder_name = serializers.CharField(source='responder.full_name', read_only=True)
    responder_email = serializers.EmailField(source='responder.email', read_only=True)

    class Meta:
        model = SOSResponse
        fields = [
            'id', 'sos_request', 'responder', 'responder_name', 'responder_email',
            'can_help', 'estimated_arrival_minutes', 'note', 'created_at'
        ]
        read_only_fields = ['id', 'responder', 'created_at']

    def create(self, validated_data):
        """Create response for the authenticated user"""
        user = self.context['request'].user
        validated_data['responder'] = user

        # Increment responders count on SOS request
        sos_request = validated_data['sos_request']
        sos_request.responders_count += 1
        sos_request.save(update_fields=['responders_count'])

        return super().create(validated_data)
