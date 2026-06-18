"""
Firebase Cloud Messaging (FCM) service for sending push notifications.

This module handles all FCM operations including:
- Sending notifications to single devices
- Sending notifications to multiple devices
- Sending notifications to users near a location
- Token cleanup for invalid tokens
"""
import logging
import json
from typing import List, Dict, Optional
from math import radians, sin, cos, sqrt, asin

from firebase_admin import messaging, exceptions
from django.conf import settings

from account.models import CustomUser
from account.models import UserProfile
from notifications.models import DeviceToken


logger = logging.getLogger(__name__)


# Initialize Firebase Admin SDK (will be called in settings.py or app ready)
_firebase_initialized = False


def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    global _firebase_initialized
    if not _firebase_initialized:
        try:
            from firebase_admin import credentials, initialize_app

            # Check if credentials are provided
            firebase_credentials = getattr(settings, 'FIREBASE_CREDENTIALS', None)

            if firebase_credentials:
                cred = credentials.Certificate(firebase_credentials)
                initialize_app(cred)
                _firebase_initialized = True
                logger.info("Firebase Admin SDK initialized successfully")
            else:
                logger.warning("Firebase credentials not configured. FCM will not work.")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase: {str(e)}")


def send_push_notification(
    token: str,
    title: str,
    body: str,
    data: Optional[Dict] = None,
    image_url: Optional[str] = None
) -> bool:
    """
    Send a push notification to a single device.

    Args:
        token: FCM device token
        title: Notification title
        body: Notification body text
        data: Additional data payload (optional)
        image_url: URL of notification image (optional)

    Returns:
        bool: True if notification was sent successfully
    """
    if not _firebase_initialized:
        logger.warning("Firebase not initialized, skipping notification")
        return False

    try:
        # Build the message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
                image=image_url,
            ),
            data=data or {},
            token=token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='sos_alerts',
                    sound='default',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        badge=1,
                        sound='default',
                        category='sos_alert',
                    ),
                ),
            ),
        )

        # Send the message
        response = messaging.send(message)
        logger.info(f"Notification sent successfully: {response}")
        return True

    except exceptions.InvalidArgumentError as e:
        logger.error(f"Invalid FCM token: {str(e)}")
        # Mark token as inactive
        try:
            device_token = DeviceToken.objects.get(token=token)
            device_token.is_active = False
            device_token.save()
            logger.info(f"Marked inactive token: {token}")
        except DeviceToken.DoesNotExist:
            pass
        return False

    except exceptions.UnregisteredError:
        logger.warning(f"Token no longer registered: {token}")
        # Delete the token
        DeviceToken.objects.filter(token=token).delete()
        return False

    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")
        return False


def send_push_notification_to_multiple(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict] = None,
    image_url: Optional[str] = None
) -> int:
    """
    Send a push notification to multiple devices.

    Args:
        tokens: List of FCM device tokens
        title: Notification title
        body: Notification body text
        data: Additional data payload (optional)
        image_url: URL of notification image (optional)

    Returns:
        int: Number of notifications sent successfully
    """
    if not tokens:
        return 0

    if not _firebase_initialized:
        logger.warning("Firebase not initialized, skipping notification")
        return 0

    success_count = 0

    # Build multicast message
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
            image=image_url,
        ),
        data=data or {},
        tokens=tokens,
        android=messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                channel_id='sos_alerts',
                sound='default',
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    badge=1,
                    sound='default',
                    category='sos_alert',
                ),
            ),
        ),
    )

    try:
        # Send the multicast message
        response = messaging.send_each_for_multicast(message)

        # Handle responses
        for idx, resp in enumerate(response.responses):
            if resp.success:
                success_count += 1
            else:
                # Handle invalid tokens
                if resp.exception and isinstance(
                    resp.exception,
                    (exceptions.InvalidArgumentError, exceptions.UnregisteredError)
                ):
                    try:
                        device_token = DeviceToken.objects.get(token=tokens[idx])
                        if isinstance(resp.exception, exceptions.UnregisteredError):
                            device_token.delete()
                        else:
                            device_token.is_active = False
                            device_token.save()
                    except DeviceToken.DoesNotExist:
                        pass

        logger.info(f"Multicast notification sent: {success_count}/{len(tokens)} successful")
        return success_count

    except Exception as e:
        logger.error(f"Failed to send multicast notification: {str(e)}")
        return success_count


def get_nearby_user_tokens(
    center_lat: float,
    center_lng: float,
    radius_km: int,
    blood_type: Optional[str] = None,
    exclude_user_id: Optional[str] = None
) -> List[str]:
    """
    Get FCM tokens for users near a location.

    Uses the Haversine formula to calculate distance.

    Args:
        center_lat: Center latitude
        center_lng: Center longitude
        radius_km: Search radius in kilometers
        blood_type: Optional blood type filter
        exclude_user_id: User ID to exclude (e.g., SOS creator)

    Returns:
        List of FCM tokens for nearby users
    """
    tokens = []

    try:
        # Get all active device tokens
        device_tokens = DeviceToken.objects.filter(is_active=True).select_related('user')

        for device_token in device_tokens:
            # Exclude specific user if provided
            if exclude_user_id and str(device_token.user.id) == exclude_user_id:
                continue

            # Get user profile with location
            try:
                profile = device_token.user.profile
                if not profile.location_lat or not profile.location_lng:
                    continue

                # Filter by blood type if specified
                if blood_type and profile.blood_group != blood_type:
                    continue

                # Filter by availability
                if not profile.is_available_for_donation:
                    continue

                # Calculate distance using Haversine formula
                lat1 = radians(float(center_lat))
                lat2 = radians(float(profile.location_lat))
                lng1 = radians(float(center_lng))
                lng2 = radians(float(profile.location_lng))

                dlat = lat2 - lat1
                dlng = lng2 - lng1

                a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlng / 2)**2
                c = 2 * asin(sqrt(a))
                distance_km = 6371 * c  # Earth's radius in km

                # Add if within radius
                if distance_km <= radius_km:
                    tokens.append(device_token.token)

            except UserProfile.DoesNotExist:
                continue

        logger.info(f"Found {len(tokens)} nearby user tokens within {radius_km}km")
        return tokens

    except Exception as e:
        logger.error(f"Error getting nearby user tokens: {str(e)}")
        return []


def notify_nearby_users_sos_created(sos_request, radius_km: int = 50) -> int:
    """
    Notify nearby users when a new SOS request is created.

    Args:
        sos_request: SOSRequest instance
        radius_km: Notification radius in kilometers

    Returns:
        int: Number of notifications sent
    """
    if not sos_request.hospital_lat or not sos_request.hospital_lng:
        logger.warning("SOS request has no location, skipping notifications")
        return 0

    # Get nearby user tokens (filter by blood type match)
    tokens = get_nearby_user_tokens(
        center_lat=float(sos_request.hospital_lat),
        center_lng=float(sos_request.hospital_lng),
        radius_km=radius_km,
        blood_type=sos_request.blood_type,
        exclude_user_id=str(sos_request.requester.id)
    )

    if not tokens:
        logger.info("No nearby users found for SOS notification")
        return 0

    # Prepare notification data
    data = {
        'type': 'sos_created',
        'sos_id': str(sos_request.id),
        'blood_type': sos_request.blood_type,
        'hospital_name': sos_request.hospital_name,
        'units_needed': str(sos_request.units_needed),
        'urgency': sos_request.urgency if hasattr(sos_request, 'urgency') else 'critical',
        'latitude': str(sos_request.hospital_lat),
        'longitude': str(sos_request.hospital_lng),
    }

    title = f"🆘 SOS: {sos_request.blood_type} Blood Needed!"
    body = f"{sos_request.units_needed} unit(s) needed at {sos_request.hospital_name}. Please help if nearby."

    return send_push_notification_to_multiple(
        tokens=tokens,
        title=title,
        body=body,
        data=data
    )


def notify_sos_creator_new_response(sos_request, responder_name: str) -> bool:
    """
    Notify SOS creator when someone responds to their SOS.

    Args:
        sos_request: SOSRequest instance
        responder_name: Name of the responder

    Returns:
        bool: True if notification was sent successfully
    """
    # Get creator's device tokens
    tokens = list(
        DeviceToken.objects.filter(
            user=sos_request.requester,
            is_active=True
        ).values_list('token', flat=True)
    )

    if not tokens:
        logger.info(f"No device tokens found for SOS creator {sos_request.requester.email}")
        return False

    data = {
        'type': 'sos_responded',
        'sos_id': str(sos_request.id),
        'responder_name': responder_name,
    }

    title = "Someone is coming to help!"
    body = f"{responder_name} is responding to your SOS request."

    success_count = send_push_notification_to_multiple(
        tokens=tokens,
        title=title,
        body=body,
        data=data
    )

    return success_count > 0


def notify_sos_responders_status_change(sos_request, new_status: str) -> int:
    """
    Notify all responders when SOS status changes.

    Args:
        sos_request: SOSRequest instance
        new_status: New status (resolved, cancelled)

    Returns:
        int: Number of notifications sent
    """
    # Get all responders
    responder_ids = sos_request.responses.values_list('responder_id', flat=True)

    # Get their device tokens
    tokens = list(
        DeviceToken.objects.filter(
            user_id__in=responder_ids,
            is_active=True
        ).values_list('token', flat=True)
    )

    if not tokens:
        logger.info("No device tokens found for SOS responders")
        return 0

    data = {
        'type': f'sos_{new_status}',
        'sos_id': str(sos_request.id),
    }

    if new_status == 'resolved':
        title = "SOS Request Resolved"
        body = f"The SOS request at {sos_request.hospital_name} has been resolved."
    else:  # cancelled
        title = "SOS Request Cancelled"
        body = f"The SOS request at {sos_request.hospital_name} has been cancelled."

    return send_push_notification_to_multiple(
        tokens=tokens,
        title=title,
        body=body,
        data=data
    )
