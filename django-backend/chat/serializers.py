"""
Serializers for Chat app.

Phase 8: Serializers for conversation and message handling with safety controls.
"""
from rest_framework import serializers
from .models import Conversation, Message, BlockedUser


class MessageSerializer(serializers.ModelSerializer):
    """Serializer for individual messages."""
    sender_name = serializers.CharField(source='sender.full_name', read_only=True)
    sender_picture = serializers.ImageField(source='sender.profile.profile_picture', read_only=True)
    sender_role = serializers.CharField(source='sender.role', read_only=True)
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            'id', 'content', 'message_type', 'is_read', 'read_at',
            'is_deleted', 'created_at', 'updated_at',
            'sender_name', 'sender_picture', 'sender_role', 'is_mine',
            'location_lat', 'location_lng'
        ]

    def get_is_mine(self, obj):
        """Check if message was sent by current user."""
        request = self.context.get('request')
        if request and request.user:
            return obj.sender == request.user
        return False


class ConversationSerializer(serializers.ModelSerializer):
    """Serializer for conversations with participant details."""
    other_participant = serializers.SerializerMethodField()
    other_participant_picture = serializers.SerializerMethodField()
    other_participant_blood_group = serializers.SerializerMethodField()
    last_message_content = serializers.SerializerMethodField()
    last_message_at = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    is_blocked = serializers.SerializerMethodField()
    blood_request = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'other_participant', 'other_participant_picture',
            'other_participant_blood_group', 'last_message_content', 'last_message_at',
            'unread_count', 'is_blocked', 'is_active', 'blood_request',
            'created_at', 'updated_at'
        ]

    def get_other_participant(self, obj):
        """Get the other participant's info."""
        request = self.context.get('request')
        if not request or not request.user:
            return None

        if request.user == obj.patient:
            return {
                'id': str(obj.donor.id),
                'full_name': obj.donor.full_name,
                'email': obj.donor.email,
                'role': obj.donor.role,
            }
        else:
            return {
                'id': str(obj.patient.id),
                'full_name': obj.patient.full_name,
                'email': obj.patient.email,
                'role': obj.patient.role,
            }

    def get_other_participant_picture(self, obj):
        """Get the other participant's profile picture."""
        request = self.context.get('request')
        if not request or not request.user:
            return None

        if request.user == obj.patient:
            profile = getattr(obj.donor, 'profile', None)
        else:
            profile = getattr(obj.patient, 'profile', None)

        if profile and profile.profile_picture:
            return profile.profile_picture.url
        return None

    def get_other_participant_blood_group(self, obj):
        """Get the other participant's blood group."""
        request = self.context.get('request')
        if not request or not request.user:
            return None

        if request.user == obj.patient:
            profile = getattr(obj.donor, 'profile', None)
        else:
            profile = getattr(obj.patient, 'profile', None)

        return profile.blood_group if profile else None

    def get_last_message_content(self, obj):
        """Get the content of the most recent message."""
        last = obj.messages.filter(is_deleted=False).order_by('-created_at').first()
        if last:
            return last.content
        return None

    def get_last_message_at(self, obj):
        """Get the timestamp of the most recent message."""
        if obj.last_message_at:
            return obj.last_message_at.isoformat()
        # Fallback to conversation created_at if no messages yet
        return obj.created_at.isoformat()

    def get_unread_count(self, obj):
        """Get count of unread messages."""
        request = self.context.get('request')
        if not request or not request.user:
            return 0

        return obj.messages.filter(
            is_read=False,
            is_deleted=False
        ).exclude(sender=request.user).count()

    def get_is_blocked(self, obj):
        """Check if conversation is blocked."""
        return obj.blocked_by is not None

    def get_blood_request(self, obj):
        """Get the related blood request info."""
        from blood_requests.serializers import PublicBloodRequestSerializer
        return PublicBloodRequestSerializer(obj.blood_request).data


class CreateMessageSerializer(serializers.Serializer):
    """Serializer for creating a new message."""
    content = serializers.CharField(max_length=5000)
    message_type = serializers.ChoiceField(
        choices=['text', 'location'],
        default='text'
    )
    location_lat = serializers.DecimalField(
        max_digits=9,
        decimal_places=6,
        required=False,
        allow_null=True
    )
    location_lng = serializers.DecimalField(
        max_digits=9,
        decimal_places=6,
        required=False,
        allow_null=True
    )

    def validate(self, data):
        """Validate message data."""
        if data.get('message_type') == 'location':
            if not data.get('location_lat') or not data.get('location_lng'):
                raise serializers.ValidationError(
                    "Location coordinates required for location messages"
                )
        return data


class BlockConversationSerializer(serializers.Serializer):
    """Serializer for blocking a conversation."""
    reason = serializers.CharField(required=False, allow_blank=True, max_length=500)


class ReportMessageSerializer(serializers.Serializer):
    """Serializer for reporting a message."""
    reason = serializers.CharField(required=True, max_length=500)


class UnblockUserSerializer(serializers.Serializer):
    """Serializer for unblocking a user."""
    user_id = serializers.UUIDField(required=True)
