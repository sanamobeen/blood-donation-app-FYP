"""
Firebase Cloud Messaging (FCM) Service for Push Notifications

Handles sending push notifications to mobile devices for SOS alerts and other features.
"""
import logging
import json
from typing import List, Dict, Any, Optional
import firebase_admin
from firebase_admin import messaging, credentials
from firebase_admin import exceptions
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
            import os

            # Check if Firebase is already initialized by settings.py
            if firebase_admin._apps:
                # Use the existing app
                _fcm_app = list(firebase_admin._apps.values())[0]
                logger.info("Using existing Firebase Admin SDK instance from settings")
                return _fcm_app

            # Check if Firebase credentials are configured
            cred = None
            firebase_credentials_path = os.environ.get('FIREBASE_CREDENTIALS_PATH')

            # Resolve relative path if needed
            if firebase_credentials_path and not firebase_credentials_path.startswith('/'):
                from django.conf import settings
                firebase_credentials_path = str(settings.BASE_DIR / firebase_credentials_path)

            # Check for FIREBASE_CREDENTIALS (dict) first
            if hasattr(settings, 'FIREBASE_CREDENTIALS') and settings.FIREBASE_CREDENTIALS:
                # From dictionary
                cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
            # Check for FIREBASE_CREDENTIALS_PATH (file path)
            elif firebase_credentials_path and os.path.exists(firebase_credentials_path):
                # From file path
                cred = credentials.Certificate(firebase_credentials_path)
            else:
                # For development, try to initialize without credentials
                # This will work for development but needs proper credentials in production
                logger.warning("Firebase credentials not configured. FCM will not work properly.")
                # Create app without credentials (will fail in production)
                cred = None

            if cred:
                _fcm_app = firebase_admin.initialize_app(cred, options={'project_id': 'blood-donation-chat'})
                logger.info("Firebase Admin SDK initialized successfully in fcm_service")
            else:
                # Initialize without credentials (for development only)
                _fcm_app = firebase_admin.initialize_app()

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

    except exceptions.InvalidArgumentError as e:
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
    patient_name: str,
    blood_type: str,
    hospital_name: str,
    hospital_address: str,
    distance_km: float,
    sos_id: str,
    urgency: str = "critical",
    created_at: str = None,
) -> bool:
    """
    Send an SOS notification to a single donor.

    Args:
        registration_token: FCM device token
        patient_name: Name of the patient needing blood
        blood_type: Required blood type
        hospital_name: Hospital name
        hospital_address: Hospital address
        distance_km: Distance from donor to hospital
        sos_id: SOS alert ID
        urgency: Urgency level (critical, urgent, normal)
        created_at: When SOS was created (ISO format string)

    Returns:
        bool: True if successful, False otherwise
    """
    # Create urgency indicator
    urgency_emoji = {
        'critical': '🚨',
        'urgent': '⚠️',
        'normal': '📍'
    }

    # Format notification title with patient name
    title = f"{urgency_emoji.get(urgency, '🩸')} SOS: {patient_name}"

    # Format notification body with all details
    body_parts = [
        f"🩸 {blood_type} blood needed",
        f"📍 {distance_km:.1f}km away",
        f"🏥 {hospital_name}",
    ]

    # Add creation time if provided
    if created_at:
        body_parts.append(f"⏰ {created_at}")

    body = "\n".join(body_parts)

    data = {
        'type': 'sos_alert',
        'sos_id': sos_id,
        'patient_name': patient_name,
        'blood_type': blood_type,
        'hospital_name': hospital_name,
        'hospital_address': hospital_address,
        'distance_km': str(distance_km),
        'urgency': urgency,
        'created_at': created_at or '',
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
    patient_name: str = "Patient",
    created_at: str = None,
) -> Dict[str, Any]:
    """
    Send SOS notifications to multiple donors with individualized information.

    Each donor receives a personalized notification showing their specific distance
    to the patient and all relevant patient information.

    Args:
        donor_tokens: List of FCM tokens for eligible donors
        blood_type: Required blood type
        hospital_name: Hospital name
        hospital_address: Hospital address
        sos_id: SOS alert ID
        urgency: Urgency level
        donor_distances: Dict mapping token to distance in km for each donor
        patient_name: Name of the patient needing blood
        created_at: When SOS was created (ISO format string)

    Returns:
        dict: Response with success/failure counts
    """
    from datetime import datetime

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

    success_count = 0
    failure_count = 0
    failed_tokens = []

    # Format the creation time for display
    created_time_str = ""
    if created_at:
        try:
            dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            created_time_str = dt.strftime('%H:%M')  # Just show time
        except:
            created_time_str = ""

    # Send individual notification to each donor
    for token in donor_tokens:
        try:
            # Get distance for this specific donor
            distance_km = donor_distances.get(token, 0.0) if donor_distances else 0.0

            # Create personalized title with patient name
            title = f"{urgency_emoji.get(urgency, '🩸')} SOS: {patient_name}"

            # Create personalized body with all details
            body_parts = [
                f"🩸 {blood_type} blood needed",
                f"📍 {distance_km:.1f}km away",
                f"🏥 {hospital_name}",
            ]

            # Add creation time if available
            if created_time_str:
                body_parts.append(f"⏰ Requested at {created_time_str}")

            body = "\n".join(body_parts)

            # Create data payload with all patient information
            data = {
                'type': 'sos_alert',
                'sos_id': sos_id,
                'patient_name': patient_name,
                'blood_type': blood_type,
                'hospital_name': hospital_name,
                'hospital_address': hospital_address,
                'distance_km': str(distance_km),
                'urgency': urgency,
                'created_at': created_at or '',
                'action': 'respond',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            }

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data,
                android=messaging.AndroidConfig(
                    notification=messaging.AndroidNotification(
                        channel_id='sos_critical',
                        sound='alarm',
                        priority='high',
                    ),
                    priority='high',
                ),
                token=token,
            )

            # Send the message
            messaging.send(message, app=get_fcm_app())
            success_count += 1
            logger.info(f"SOS notification sent to donor at {distance_km:.1f}km")

        except exceptions.InvalidArgumentError as e:
            logger.error(f"Invalid FCM token {token[:20]}...: {str(e)}")
            failure_count += 1
            failed_tokens.append(token)
        except Exception as e:
            logger.error(f"Failed to send SOS notification to {token[:20]}...: {str(e)}")
            failure_count += 1
            failed_tokens.append(token)

    logger.info(f"SOS batch notification sent: {success_count} success, {failure_count} failed")

    return {
        'success_count': success_count,
        'failure_count': failure_count,
        'failed_tokens': failed_tokens,
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
