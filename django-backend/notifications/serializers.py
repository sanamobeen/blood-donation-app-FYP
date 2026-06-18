from rest_framework import serializers
from .models import DeviceToken


class DeviceTokenSerializer(serializers.ModelSerializer):
    """
    Serializer for DeviceToken model.
    Used for registering and managing FCM tokens.
    """

    class Meta:
        model = DeviceToken
        fields = ['id', 'token', 'device_type', 'device_name', 'created_at', 'is_active']
        read_only_fields = ['id', 'created_at']

    def validate_token(self, value):
        """Ensure token is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Token cannot be empty.")
        return value.strip()

    def validate_device_type(self, value):
        """Ensure device type is valid."""
        valid_types = ['ios', 'android', 'web']
        if value.lower() not in valid_types:
            raise serializers.ValidationError(
                f"Invalid device type. Must be one of: {', '.join(valid_types)}"
            )
        return value.lower()


class DeviceTokenRegisterSerializer(serializers.ModelSerializer):
    """
    Simplified serializer for token registration.
    """

    class Meta:
        model = DeviceToken
        fields = ['token', 'device_type', 'device_name']
