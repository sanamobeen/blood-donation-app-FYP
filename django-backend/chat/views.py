"""
API Views for Chat app.

Phase 8: Chat endpoints with safety controls (block, report, limits).
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
from django.db.models import Q
import datetime
import logging

from account.models import CustomUser
from .models import Conversation, Message, BlockedUser
from .serializers import (
    MessageSerializer,
    ConversationSerializer,
    CreateMessageSerializer,
    BlockConversationSerializer,
    ReportMessageSerializer
)

logger = logging.getLogger(__name__)


def success_response(message, data=None, status_code=200):
    """Create a standardized success response."""
    response = {'success': True, 'message': message}
    if data:
        response.update(data)
    return Response(response, status=status_code)


def error_response(message, errors=None, status_code=400):
    """Create a standardized error response."""
    response = {'success': False, 'message': message}
    if errors:
        response['errors'] = errors
    return Response(response, status=status_code)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_conversation(request):
    """
    Create a new conversation between patient and donor for a blood request.

    POST /api/chat/conversations/create/

    Body: {
        "blood_request_id": "uuid",
        "participant_id": "uuid"  # The other user's ID
    }
    """
    try:
        from blood_requests.models import BloodRequest

        blood_request_id = request.data.get('blood_request_id')
        participant_id = request.data.get('participant_id')

        if not blood_request_id or not participant_id:
            return error_response('blood_request_id and participant_id are required.')

        try:
            blood_request = BloodRequest.objects.get(id=blood_request_id)
            participant = CustomUser.objects.get(id=participant_id)
        except BloodRequest.DoesNotExist:
            return error_response('Blood request not found.', status_code=404)
        except CustomUser.DoesNotExist:
            return error_response('Participant not found.', status_code=404)

        # Determine who is patient and who is donor
        # The request creator (requested_by) is the patient
        patient = blood_request.requested_by
        donor = participant

        # If current user is not the patient, they might be the donor
        if request.user != patient:
            # In this case, participant should be the patient
            patient = participant
            donor = request.user

        # Check if conversation already exists
        existing_conversation = Conversation.objects.filter(
            patient=patient,
            donor=donor,
            blood_request=blood_request,
            is_active=True
        ).first()

        if existing_conversation:
            return success_response(
                'Conversation already exists.',
                {'conversation': ConversationSerializer(existing_conversation, context={'request': request}).data}
            )

        # Create new conversation
        conversation = Conversation.objects.create(
            blood_request=blood_request,
            patient=patient,
            donor=donor
        )

        logger.info(f"Conversation created: {conversation.id} between {patient.email} and {donor.email}")

        return success_response(
            'Conversation created.',
            {'conversation': ConversationSerializer(conversation, context={'request': request}).data},
            status_code=201
        )

    except Exception as e:
        logger.error(f"Error creating conversation: {str(e)}", exc_info=True)
        return error_response('Failed to create conversation.', status_code=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_conversations(request):
    """
    Get all conversations for current user.

    GET /api/chat/conversations/

    Returns conversations with participant details and message counts.
    """
    try:
        conversations = Conversation.objects.filter(
            is_active=True
        ).filter(
            Q(patient=request.user) | Q(donor=request.user)
        ).select_related('patient', 'donor', 'blood_request').order_by('-updated_at')

        serializer = ConversationSerializer(
            conversations,
            many=True,
            context={'request': request}
        )

        return success_response(
            'Conversations retrieved.',
            {
                'conversations': serializer.data,
                'count': conversations.count()
            }
        )

    except Exception as e:
        logger.error(f"Error getting conversations: {str(e)}", exc_info=True)
        return error_response('Failed to retrieve conversations.', status_code=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_messages(request, conversation_id):
    """
    Get messages for a conversation.

    GET /api/chat/conversations/{conversation_id}/messages/

    Returns non-deleted messages and marks them as read.
    """
    try:
        conversation = Conversation.objects.get(
            id=conversation_id,
            is_active=True
        )

        # Verify user is part of conversation
        if conversation.patient != request.user and conversation.donor != request.user:
            return error_response('Not authorized.', status_code=403)

        # Check if blocked
        if conversation.blocked_by:
            return error_response('Conversation is blocked.', status_code=403)

        # Get messages (non-deleted only)
        messages = conversation.messages.filter(
            is_deleted=False
        ).order_by('created_at')

        # Mark messages as read
        messages.exclude(sender=request.user).update(is_read=True, read_at=timezone.now())

        serializer = MessageSerializer(
            messages,
            many=True,
            context={'request': request}
        )

        return success_response(
            'Messages retrieved.',
            {'messages': serializer.data}
        )

    except Conversation.DoesNotExist:
        return error_response('Conversation not found.', status_code=404)
    except Exception as e:
        logger.error(f"Error getting messages: {str(e)}", exc_info=True)
        return error_response('Failed to retrieve messages.', status_code=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_message(request, conversation_id):
    """
    Send a new message with spam limits.

    POST /api/chat/conversations/{conversation_id}/send/

    Message limit: 30 messages per hour per user.
    """
    try:
        conversation = Conversation.objects.get(
            id=conversation_id,
            is_active=True
        )

        # Verify user is part of conversation
        if conversation.patient != request.user and conversation.donor != request.user:
            return error_response('Not authorized.', status_code=403)

        # Check if blocked
        if conversation.blocked_by:
            return error_response('Conversation is blocked.', status_code=403)

        # Spam check: limit messages per hour
        one_hour_ago = timezone.now() - datetime.timedelta(hours=1)
        recent_messages = Message.objects.filter(
            conversation=conversation,
            sender=request.user,
            created_at__gte=one_hour_ago
        ).count()

        MAX_MESSAGES_PER_HOUR = 30
        if recent_messages >= MAX_MESSAGES_PER_HOUR:
            return error_response(
                f'Message limit reached ({MAX_MESSAGES_PER_HOUR}/hour). Please wait.',
                status_code=429
            )

        # Validate message
        serializer = CreateMessageSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response('Invalid message.', errors=serializer.errors)

        # Create message
        message = Message.objects.create(
            conversation=conversation,
            sender=request.user,
            content=serializer.validated_data['content'],
            message_type=serializer.validated_data.get('message_type', 'text'),
            location_lat=serializer.validated_data.get('location_lat'),
            location_lng=serializer.validated_data.get('location_lng')
        )

        # Update conversation message counts
        if request.user == conversation.patient:
            conversation.patient_message_count += 1
        else:
            conversation.donor_message_count += 1
        conversation.last_message_at = timezone.now()
        conversation.save()

        # Send notification to recipient (throttled)
        recipient = conversation.donor if request.user == conversation.patient else conversation.patient

        # Only notify if not too frequent (every 5th message or first in a while)
        if recent_messages % 5 == 0:
            try:
                from notifications.views import send_push_notification
                send_push_notification(
                    user=recipient,
                    title='New Message',
                    message=f'{request.user.full_name or request.user.email} sent you a message.',
                    notif_type='new_message',
                    data={
                        'conversation_id': str(conversation.id),
                        'sender_id': str(request.user.id),
                        'sender_name': request.user.full_name or request.user.email,
                    },
                    send_push=True  # Enable FCM push notification
                )
                logger.info(f"Push notification sent to {recipient.email} for new message")
            except Exception as e:
                logger.warning(f"Failed to send push notification: {e}")

        logger.info(f"Message sent in conversation {conversation_id} by {request.user.email}")

        return success_response(
            'Message sent.',
            {'message': MessageSerializer(message, context={'request': request}).data},
            status_code=201
        )

    except Conversation.DoesNotExist:
        return error_response('Conversation not found.', status_code=404)
    except Exception as e:
        logger.error(f"Error sending message: {str(e)}", exc_info=True)
        return error_response('Failed to send message.', status_code=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def block_conversation(request, conversation_id):
    """
    Block a conversation (safety feature).

    POST /api/chat/conversations/{conversation_id}/block/
    """
    try:
        conversation = Conversation.objects.get(id=conversation_id)

        # Verify user is part of conversation
        if conversation.patient != request.user and conversation.donor != request.user:
            return error_response('Not authorized.', status_code=403)

        # Validate reason
        serializer = BlockConversationSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response('Invalid data.', errors=serializer.errors)

        # Block conversation
        conversation.is_active = False
        conversation.blocked_by = request.user
        conversation.blocked_at = timezone.now()
        conversation.block_reason = serializer.validated_data.get('reason', '')
        conversation.save()

        # Add to blocked list
        other_user = conversation.donor if request.user == conversation.patient else conversation.patient
        BlockedUser.objects.get_or_create(
            blocker=request.user,
            blocked=other_user,
            defaults={'reason': conversation.block_reason}
        )

        logger.info(f"Conversation {conversation_id} blocked by {request.user.email}")

        return success_response('Conversation blocked.')

    except Conversation.DoesNotExist:
        return error_response('Conversation not found.', status_code=404)
    except Exception as e:
        logger.error(f"Error blocking conversation: {str(e)}", exc_info=True)
        return error_response('Failed to block conversation.', status_code=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def report_message(request, message_id):
    """
    Report a message for abuse.

    POST /api/chat/messages/{message_id}/report/
    """
    try:
        message = Message.objects.get(id=message_id)

        # Verify user is part of conversation
        if message.conversation.patient != request.user and message.conversation.donor != request.user:
            return error_response('Not authorized.', status_code=403)

        # Validate report
        serializer = ReportMessageSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response('Invalid data.', errors=serializer.errors)

        # Mark as reported
        message.reported = True
        message.report_reason = serializer.validated_data['reason']
        message.save()

        logger.warning(f"Message {message_id} reported by {request.user.email}: {message.report_reason}")

        return success_response('Message reported. We will review it shortly.')

    except Message.DoesNotExist:
        return error_response('Message not found.', status_code=404)
    except Exception as e:
        logger.error(f"Error reporting message: {str(e)}", exc_info=True)
        return error_response('Failed to report message.', status_code=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unblock_user(request):
    """
    Unblock a user.

    POST /api/chat/unblock/

    Body: {"user_id": "uuid"}
    """
    try:
        from account.models import CustomUser

        user_id = request.data.get('user_id')
        if not user_id:
            return error_response('user_id is required.')

        try:
            blocked_user = CustomUser.objects.get(id=user_id)
        except CustomUser.DoesNotExist:
            return error_response('User not found.', status_code=404)

        # Delete the block entry
        deleted = BlockedUser.objects.filter(
            blocker=request.user,
            blocked=blocked_user
        ).delete()

        if deleted[0] > 0:
            logger.info(f"User {request.user.email} unblocked {blocked_user.email}")
            return success_response('User unblocked.')
        else:
            return error_response('Block not found.', status_code=404)

    except Exception as e:
        logger.error(f"Error unblocking user: {str(e)}", exc_info=True)
        return error_response('Failed to unblock user.', status_code=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def unread_count(request):
    """
    Get total unread message count for the current user.

    GET /api/chat/unread-count/

    Response (200 OK):
    {
        "success": true,
        "unread_count": 5
    }
    """
    try:
        # Get all conversations where user is a participant
        conversations = Conversation.objects.filter(
            is_active=True
        ).filter(
            Q(patient=request.user) | Q(donor=request.user)
        )

        # Count unread messages (excluding messages sent by the user)
        total_unread = 0
        for conversation in conversations:
            total_unread += conversation.messages.filter(
                is_read=False,
                is_deleted=False
            ).exclude(sender=request.user).count()

        return success_response(
            message='Unread count retrieved',
            data={'unread_count': total_unread}
        )

    except Exception as e:
        logger.error(f"Error getting unread count: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to get unread count.',
            status_code=500
        )
