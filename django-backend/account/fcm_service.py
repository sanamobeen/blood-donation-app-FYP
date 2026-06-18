"""
Firebase Cloud Messaging (FCM) Service for Push Notifications

Handles sending push notifications to mobile devices for SOS alerts and other features.
"""
import logging
import json
from typing import List, Dict, Any, Optional
from firebase_admin import messaging, credentials
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured

logger = logging.getLogger(__name__)

# Initialize FCM app
_fcm_app = None


def get_fcm_app():
    """
    Get or initialize Firebase FCM app instance.

    Returns:
        firebase_admin.messaging.App: FCM app instance
    """
    global _fcm_app

    if _fcm_app is None:
        try:
            # Check if Firebase credentials are configured
            if hasattr(settings, 'FIREBASE_CREDENTIALS'):
                # From dictionary
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
            elif hasattr(settings, 'FIREBASE_CREDENTIALS_PATH'):
                # From file path
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
            else:
                # For development, try to initialize without credentials
                # This will work for development but needs proper credentials in production
                logger.warning("Firebase credentials not configured. FCM will not work properly.")
                # Create app without credentials (will fail in production)
                cred = None

            if cred:
                _fcm_app = messaging.initialize_app(cred, app=getattr(settings, 'FIREBASE_PROJECT_ID', None))
            else:
                # Initialize without credentials (for development only)
                _fcm_app = messaging.initialize_app()

        except Exception as e:
            logger.error(f"Failed to initialize Firebase FCM: {str(e)}")
            raise ImproperlyConfigured(
                "Firebase FCM not configured. Please set FIREBASE_CREDENTIALS in settings."
            )

    return _fcm_app


def send_to_device(
    registration_token: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    image: Optional[str] = None,
    android_channel_id: str = "default",
    priority: str = "high",
) -> bool:
    """
    Send a notification to a single device.

    Args:
        registration_token: FCM device token
        title: Notification title
        body: Notification body
        data: Optional custom data payload
        image: Optional notification image URL
        android_channel_id: Android notification channel ID
        priority: Message priority (HIGH or NORMAL)

    Returns:
        bool: True if successful, False otherwise
    """
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
                image=image,
            ),
            data=data or {},
            android=messaging.AndroidConfig(
                notification=messaging.AndroidNotification(
                    channel_id=android_channel_id,
                    sound='default',
                ),
                priority=priority,
            ),
            token=registration_token,
        )

        response = messaging.send(message, app=get_fcm_app())
        logger.info(f"Successfully sent message to token {registration_token[:20]}...")
        return True

    except messaging.InvalidArgumentError as e:
        logger.error(f"Invalid FCM token: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"Failed to send FCM message: {str(e)}")
        return False


def send_to_multicast(
    registration_tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    image: Optional[str] = None,
    android_channel_id: str = "sos_critical",
    priority: str = "high",
) -> Dict[str, Any]:
    """
    Send a notification to multiple devices (multicast).

    Args:
        registration_tokens: List of FCM device tokens
        title: Notification title
        body: Notification body
        data: Optional custom data payload
        image: Optional notification image URL
        android_channel_id: Android notification channel ID
        priority: Message priority

    Returns:
        dict: Response with success_count, failure_count, failed_tokens
    """
    if not registration_tokens:
        return {
            'success_count': 0,
            'failure_count': 0,
            'failed_tokens': [],
            'total_tokens': 0
        }

    # Remove duplicate tokens
    unique_tokens = list(set(registration_tokens))

    message = messaging.MulticastMessage(
        notifications=[
            messaging.Notification(
                title=title,
                body=body,
                image=image,
            )
        ],
        data=data or {},
        android=messaging.AndroidConfig(
            notification=messaging.AndroidNotification(
                channel_id=android_channel_id,
                priority=priority,
                sound='alarm',
                vibrate=True,
                led=True,
            ),
            priority=priority,
        ),
        tokens=unique_tokens,
    )

    try:
        # FCM supports up to 500 tokens per multicast request
        # For larger lists, we need to send in batches
        batch_response = messaging.send_each_for_multicast(message, app=get_fcm_app())

        success_count = batch_response.success_count
        failure_count = batch_response.failure_count

        # Get failed tokens
        failed_tokens = []
        if hasattr(batch_response, 'responses'):
            for idx, response in enumerate(batch_response.responses):
                if not response.success:
                    failed_tokens.append(unique_tokens[idx])

        logger.info(f"Multicast message sent: {success_count} success, {failure_count} failed")

        return {
            'success_count': success_count,
            'failure_count': failure_count,
            'failed_tokens': failed_tokens,
            'total_tokens': len(unique_tokens)
        }

    except Exception as e:
        logger.error(f"Failed to send multicast FCM message: {str(e)}")
        return {
            'success_count': 0,
            'failure_count': len(unique_tokens),
            'failed_tokens': unique_tokens,
            'total_tokens': len(unique_tokens)
        }


def send_sos_notification(
    registration_token: str,
    blood_type: str,
    hospital_name: str,
    hospital_address: str,
    distance_km: float,
    sos_id: str,
    urgency: str = "critical",
) -> bool:
    """
    Send an SOS notification to a single donor.

    Args:
        registration_token: FCM device token
        blood_type: Required blood type
        hospital_name: Hospital name
        hospital_address: Hospital address
        distance_km: Distance from donor to hospital
        sos_id: SOS alert ID
        urgency: Urgency level (critical, urgent, normal)

    Returns:
        bool: True if successful, False otherwise
    """
    # Create urgency indicator
    urgency_emoji = {
        'critical': '🚨',
        'urgent': '⚠️',
        'normal': '📍'
    }

    title = f"{urgency_emoji.get(urgency, '🩸')} URGENT: Blood Needed!"
    body = f"{blood_type} blood needed at {hospital_name}\nOnly {distance_km:.1f}km away"

    data = {
        'type': 'sos_alert',
        'sos_id': sos_id,
        'blood_type': blood_type,
        'hospital_name': hospital_name,
        'hospital_address': hospital_address,
        'distance_km': str(distance_km),
        'urgency': urgency,
        'action': 'respond',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'sound': 'alarm',
    }

    return send_to_device(
        registration_token=registration_token,
        title=title,
        body=body,
        data=data,
        android_channel_id="sos_critical",
        priority="high",
    )


def send_batch_sos_notifications(
    donor_tokens: List[str],
    blood_type: str,
    hospital_name: str,
    hospital_address: str,
    sos_id: str,
    urgency: str = "critical",
    donor_distances: Optional[Dict[str, float]] = None,
) -> Dict[str, Any]:
    """
    Send SOS notifications to multiple donors.

    Args:
        donor_tokens: List of FCM tokens for eligible donors
        blood_type: Required blood type
        hospital_name: Hospital name
        hospital_address: Hospital address
        sos_id: SOS alert ID
        urgency: Urgency level
        donor_distances: Optional dict mapping token to distance in km

    Returns:
        dict: Response with success/failure counts
    """
    if not donor_tokens:
        return {
            'success_count': 0,
            'failure_count': 0,
            'failed_tokens': [],
            'total_tokens': 0
        }

    urgency_emoji = {
        'critical': '🚨',
        'urgent': '⚠️',
        'normal': '🩸'
    }

    # Create a single notification for all recipients
    # Note: MulticastMessage uses one notification for all tokens
    urgency_emoji = {
        'critical': '🚨',
        'urgent': '⚠️',
        'normal': '🩸'
    }

    # Get average distance for notification body
    avg_distance = 0.0
    if donor_distances:
        distances = list(donor_distances.values())
        if distances:
            avg_distance = sum(distances) / len(distances)

    if avg_distance > 0:
        body = f"{blood_type} blood needed at {hospital_name}\nWithin {avg_distance:.1f}km"
    else:
        body = f"{blood_type} blood needed at {hospital_name}\nNear your location"

    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=f"{urgency_emoji.get(urgency, '🩸')} URGENT: Blood Needed!",
            body=body,
        ),
        data={
            'type': 'sos_alert',
            'sos_id': sos_id,
            'blood_type': blood_type,
            'hospital_name': hospital_name,
            'hospital_address': hospital_address,
            'urgency': urgency,
            'action': 'respond',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        android=messaging.AndroidConfig(
            notification=messaging.AndroidNotification(
                channel_id='sos_critical',
                sound='alarm',
            ),
            priority='high',
        ),
        tokens=donor_tokens,
    )

    try:
        batch_response = messaging.send_each_for_multicast(message, app=get_fcm_app())

        success_count = batch_response.success_count
        failure_count = batch_response.failure_count

        failed_tokens = []
        if hasattr(batch_response, 'responses'):
            for idx, response in enumerate(batch_response.responses):
                if not response.success:
                    failed_tokens.append(donor_tokens[idx])

        logger.info(f"SOS batch notification sent: {success_count} success, {failure_count} failed")

        return {
            'success_count': success_count,
            'failure_count': failure_count,
            'failed_tokens': failed_tokens,
            'total_tokens': len(donor_tokens)
        }

    except Exception as e:
        logger.error(f"Failed to send batch SOS notifications: {str(e)}")
        return {
            'success_count': 0,
            'failure_count': len(donor_tokens),
            'failed_tokens': donor_tokens,
            'total_tokens': len(donor_tokens)
        }


def validate_fcm_token(token: str) -> bool:
    """
    Validate if a token string looks like a valid FCM token.

    Args:
        token: FCM token string

    Returns:
        bool: True if token appears valid, False otherwise
    """
    if not token or not isinstance(token, str):
        return False

    # FCM tokens are typically long strings
    # Basic validation: length and characters
    if len(token) < 100:
        return False

    # FCM tokens contain alphanumeric characters, colons, and hyphens
    # This is a basic check - actual validation happens when sending
    return all(c.isalnum() or c in ':_-' for c in token)


def get_compatible_blood_types(recipient_type: str) -> List[str]:
    """
    Get compatible donor blood types for a recipient.

    Based on blood type compatibility rules:
    - A+ can receive from A+, A-, O+, O-
    - A- can receive from A-, O-
    - B+ can receive from B+, B-, O+, O-
    - B- can receive from B-, O-
    - AB+ can receive from all types (universal recipient)
    - AB- can receive from A-, B-, AB-, O-
    - O+ can receive from O+, O-
    - O- can receive from O- (universal donor)

    Args:
        recipient_type: Blood type of recipient (e.g., 'A+', 'A-', 'B+', etc.)

    Returns:
        list: Compatible donor blood types
    """
    compatibility_map = {
        'A+': ['A+', 'A-', 'O+', 'O-'],
        'A-': ['A-', 'O-'],
        'B+': ['B+', 'B-', 'O+', 'O-'],
        'B-': ['B-', 'O-'],
        'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
        'AB-': ['A-', 'B-', 'AB-', 'O-'],
        'O+': ['O+', 'O-'],
        'O-': ['O-'],
    }

    return compatibility_map.get(recipient_type, [])


def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great circle distance between two points on Earth.

    Args:
        lat1, lon1: Latitude and longitude of point 1 (in decimal degrees)
        lat2, lon2: Latitude and longitude of point 2 (in decimal degrees)

    Returns:
        float: Distance in kilometers
    """
    from math import radians, cos, sin, sqrt, asin

    # Convert decimal degrees to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
    c = 2 * asin(sqrt(a))

    # Radius of Earth in kilometers
    r = 6371

    return c * r
