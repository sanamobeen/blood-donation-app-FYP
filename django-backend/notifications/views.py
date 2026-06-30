"""
API Views for Push Notifications.

Provides endpoints for:
- Registering FCM device tokens
- Listing user's device tokens
- Unregistering/deleting device tokens
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from .models import DeviceToken
from .serializers import DeviceTokenSerializer, DeviceTokenRegisterSerializer


logger = logging.getLogger(__name__)


def success_response(message, data=None, status_code=status.HTTP_200_OK):
    """Create a standardized success response."""
    response_data = {'success': True, 'message': message}
    if data:
        response_data.update(data)
    return Response(response_data, status=status_code)


def error_response(message, errors=None, status_code=status.HTTP_400_BAD_REQUEST):
    """Create a standardized error response."""
    response_data = {'success': False, 'message': message}
    if errors:
        response_data['errors'] = errors
    return Response(response_data, status=status_code)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_device_token(request):
    """
    Register a new FCM device token for push notifications.

    POST /api/notifications/register-token/

    Headers:
        Authorization: Bearer <access_token>

    Request Body:
        {
            "token": "fcm_device_token_here",
            "device_type": "android",  # or "ios", "web"
            "device_name": "Samsung Galaxy S21"  # optional
        }

    Response (201 Created):
        {
            "success": true,
            "message": "Device token registered successfully",
            "data": {
                "token": {
                    "id": "uuid",
                    "token": "fcm_device_token_here",
                    "device_type": "android",
                    "device_name": "Samsung Galaxy S21",
                    "is_active": true,
                    "created_at": "2024-06-05T12:00:00Z"
                }
            }
        }
    """
    try:
        serializer = DeviceTokenRegisterSerializer(
            data=request.data,
            context={'request': request}
        )

        if serializer.is_valid():
            # Check if token already exists for this user
            existing_token = DeviceToken.objects.filter(
                user=request.user,
                token=serializer.validated_data['token']
            ).first()

            if existing_token:
                # Update existing token
                existing_token.device_type = serializer.validated_data['device_type']
                existing_token.device_name = serializer.validated_data.get('device_name', '')
                existing_token.is_active = True
                existing_token.save()

                logger.info(f"Updated existing device token for user {request.user.email}")

                return success_response(
                    message='Device token updated successfully.',
                    data={
                        'token': DeviceTokenSerializer(existing_token).data
                    },
                    status_code=status.HTTP_200_OK
                )

            # Create new token
            device_token = serializer.save(user=request.user)

            logger.info(f"Registered new device token for user {request.user.email}")

            return success_response(
                message='Device token registered successfully.',
                data={
                    'token': DeviceTokenSerializer(device_token).data
                },
                status_code=status.HTTP_201_CREATED
            )

        logger.warning(f"Device token registration failed: {serializer.errors}")
        return error_response(
            message='Failed to register device token.',
            errors=serializer.errors
        )

    except Exception as e:
        logger.error(f"Error registering device token: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while registering the device token.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_user_tokens(request):
    """
    List all device tokens for the authenticated user.

    GET /api/notifications/tokens/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
        {
            "success": true,
            "message": "Found 2 device tokens",
            "data": {
                "tokens": [
                    {
                        "id": "uuid",
                        "token": "...",
                        "device_type": "android",
                        "device_name": "Samsung Galaxy S21",
                        "is_active": true,
                        "created_at": "2024-06-05T12:00:00Z"
                    }
                ],
                "count": 2
            }
        }
    """
    try:
        tokens = DeviceToken.objects.filter(
            user=request.user
        ).order_by('-created_at')

        serializer = DeviceTokenSerializer(tokens, many=True)

        return success_response(
            message=f'Found {tokens.count()} device token(s).',
            data={
                'tokens': serializer.data,
                'count': tokens.count()
            }
        )

    except Exception as e:
        logger.error(f"Error listing device tokens: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to retrieve device tokens.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_device_token(request, token_id):
    """
    Delete/unregister a specific device token.

    DELETE /api/notifications/token/{token_id}/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
        {
            "success": true,
            "message": "Device token deleted successfully"
        }
    """
    try:
        device_token = DeviceToken.objects.get(
            id=token_id,
            user=request.user
        )

        device_token.delete()

        logger.info(f"Deleted device token {token_id} for user {request.user.email}")

        return success_response(
            message='Device token deleted successfully.'
        )

    except DeviceToken.DoesNotExist:
        return error_response(
            message='Device token not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )

    except Exception as e:
        logger.error(f"Error deleting device token: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to delete device token.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def deactivate_all_tokens(request):
    """
    Deactivate all device tokens for the authenticated user.
    Useful when logging out.

    POST /api/notifications/deactivate-all/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
        {
            "success": true,
            "message": "Deactivated 2 device tokens"
        }
    """
    try:
        count = DeviceToken.objects.filter(
            user=request.user,
            is_active=True
        ).update(is_active=False)

        logger.info(f"Deactivated {count} device tokens for user {request.user.email}")

        return success_response(
            message=f'Deactivated {count} device token(s).'
        )

    except Exception as e:
        logger.error(f"Error deactivating tokens: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to deactivate device tokens.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def test_notification(request):
    """
    Send a test push notification to the user's devices.
    Useful for testing notification setup.

    POST /api/notifications/test/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
        {
            "success": true,
            "message": "Test notification sent to 2 devices"
        }
    """
    try:
        from .services.fcm_service import send_push_notification_to_multiple

        # Get user's active tokens
        tokens = list(
            DeviceToken.objects.filter(
                user=request.user,
                is_active=True
            ).values_list('token', flat=True)
        )

        if not tokens:
            return error_response(
                message='No active device tokens found. Please register a device first.'
            )

        # Send test notification
        count = send_push_notification_to_multiple(
            tokens=tokens,
            title='Test Notification',
            body='This is a test notification from the Blood Donation app.',
            data={'type': 'test'}
        )

        return success_response(
            message=f'Test notification sent to {count} device(s).'
        )

    except Exception as e:
        logger.error(f"Error sending test notification: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to send test notification.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# ================================
# Notification List & Management
# ================================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_notifications(request):
    """
    Get all notifications for the current user.

    GET /api/notifications/

    Query params:
        unread_only=true - Get only unread notifications
        limit=20 - Limit number of results

    Response (200 OK):
        {
            "success": true,
            "count": 15,
            "results": [...]
        }
    """
    try:
        from .models import Notification

        notifications = Notification.objects.filter(user=request.user)

        # Filter by unread if requested
        unread_only = request.query_params.get('unread_only', '').lower() == 'true'
        if unread_only:
            notifications = notifications.filter(is_read=False)

        # Order by most recent
        notifications = notifications.order_by('-created_at')

        # Apply limit
        limit = int(request.query_params.get('limit', 50))
        notifications = notifications[:limit]

        # Get unread count
        unread_count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).count()

        # Serialize
        results = []
        for notif in notifications:
            results.append({
                'id': str(notif.id),
                'title': notif.title,
                'message': notif.message,
                'type': notif.type,
                'is_read': notif.is_read,
                'read_at': notif.read_at.isoformat() if notif.read_at else None,
                'created_at': notif.created_at.isoformat(),
                'related_request_id': str(notif.related_request_id) if notif.related_request_id else None,
                'related_pledge_id': str(notif.related_pledge_id) if notif.related_pledge_id else None,
                'related_conversation_id': str(notif.related_conversation_id) if notif.related_conversation_id else None,
                'data': notif.data,  # Include notification data (donor details, etc.)
            })

        return success_response(
            message=f'Found {len(results)} notification(s).',
            data={
                'notifications': results,
                'unread_count': unread_count
            }
        )

    except Exception as e:
        logger.error(f"Error listing notifications: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to retrieve notifications.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def unread_count(request):
    """
    Get unread notifications count.

    GET /api/notifications/unread-count/

    Response (200 OK):
        {
            "success": true,
            "unread_count": 5
        }
    """
    try:
        from .models import Notification

        count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).count()

        return success_response(
            message='Unread count retrieved',
            data={'unread_count': count}
        )

    except Exception as e:
        logger.error(f"Error getting unread count: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to get unread count.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_notification_read(request, notification_id):
    """
    Mark a notification as read.

    POST /api/notifications/{id}/mark-read/

    Response (200 OK):
        {
            "success": true,
            "message": "Notification marked as read"
        }
    """
    try:
        from .models import Notification
        from django.utils import timezone

        try:
            notification = Notification.objects.get(
                id=notification_id,
                user=request.user
            )
            notification.is_read = True
            notification.read_at = timezone.now()
            notification.save()

            return success_response(message='Notification marked as read.')
        except Notification.DoesNotExist:
            return error_response(
                message='Notification not found.',
                status_code=status.HTTP_404_NOT_FOUND
            )

    except Exception as e:
        logger.error(f"Error marking notification as read: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to mark notification as read.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_all_read(request):
    """
    Mark all notifications as read for the current user.

    POST /api/notifications/mark-all-read/

    Response (200 OK):
        {
            "success": true,
            "message": "Marked 15 notifications as read"
        }
    """
    try:
        from .models import Notification
        from django.utils import timezone

        count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).update(
            is_read=True,
            read_at=timezone.now()
        )

        return success_response(message=f'Marked {count} notification(s) as read.')

    except Exception as e:
        logger.error(f"Error marking all as read: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to mark all as read.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


def send_push_notification(
    user,
    title: str,
    message: str,
    notif_type: str = 'general',
    data=None,
    send_push: bool = True
):
    """
    Helper function to create and send a notification to a user.

    Args:
        user: CustomUser instance
        title: Notification title
        message: Notification message
        notif_type: Type of notification (pledge, message, request_updated, etc.)
        data: Optional dict with related IDs
        send_push: Whether to send push notification

    Returns:
        Notification object
    """
    from .models import Notification

    # Create notification record
    notification = Notification.objects.create(
        user=user,
        title=title,
        message=message,
        type=notif_type,
        related_request_id=data.get('request_id') if data else None,
        related_pledge_id=data.get('pledge_id') if data else None,
        related_conversation_id=data.get('conversation_id') if data else None,
        data=data,  # Include full data (donor details, location, etc.)
    )

    # Send push notification if enabled
    if send_push:
        try:
            # Get user's active FCM tokens from both DeviceToken and UserProfile
            tokens = list(DeviceToken.objects.filter(
                user=user,
                is_active=True
            ).values_list('token', flat=True))

            # Also check UserProfile for fcm_token (legacy support)
            try:
                if hasattr(user, 'profile') and user.profile and user.profile.fcm_token:
                    profile_token = user.profile.fcm_token
                    if profile_token and profile_token not in tokens:
                        tokens.append(profile_token)
            except:
                pass

            if tokens:
                from account.fcm_service import send_to_multicast

                # Prepare notification data
                push_data = {
                    'type': notif_type,
                    'notification_id': str(notification.id),
                }
                if data:
                    push_data.update(data)

                # Determine channel based on type
                channel = 'sos_critical' if notif_type in ['sos_alert', 'pledge_accepted'] else 'sos_alerts'

                # Send notification
                send_to_multicast(
                    registration_tokens=tokens,
                    title=title,
                    body=message,
                    data=push_data,
                    android_channel_id=channel,
                    priority='high' if notif_type in ['sos_alert', 'pledge_accepted'] else 'normal',
                )

                logger.info(f"Sent push notification to {len(tokens)} device(s) for user {user.email}")

        except Exception as e:
            logger.error(f"Failed to send push notification: {str(e)}")

    return notification
