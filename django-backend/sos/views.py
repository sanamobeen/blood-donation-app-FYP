"""
API Views for SOS (Emergency) Blood Requests.

Provides endpoints for:
- Creating SOS requests
- Listing active SOS requests
- Responding to SOS requests
- Resolving SOS requests
- Cancelling SOS requests
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from .serializers import SOSRequestSerializer, PublicSOSRequestSerializer, SOSResponseSerializer
from .models import SOSRequest, SOSResponse


# Configure logging
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
def notify_donors(request):
    """
    Send SOS push notifications to nearby compatible donors.

    POST /api/sos/notify-donors/

    Request Body:
    {
        "blood_type": "A+",
        "hospital_name": "City Hospital",
        "hospital_address": "123 Main St",
        "hospital_lat": 31.5204,
        "hospital_lng": 74.3587,
        "patient_name": "John Doe",
        "contact_phone": "+923001234567",
        "urgency_level": "critical",
        "radius_km": 10
    }

    Response (200 OK):
    {
        "success": true,
        "message": "SOS notifications sent successfully",
        "notified_count": 15,
        "target_radius": 10,
        "eligible_donors": 18,
        "notification_id": "sos_12345"
    }
    """
    try:
        # Verify user is a patient
        if request.user.role != 'patient':
            return error_response(
                message='SOS notifications are only available for patients. Please switch your role to patient to use this feature.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        import uuid
        from account.fcm_service import (
            get_compatible_blood_types,
            calculate_distance,
            send_batch_sos_notifications
        )
        from account.models import UserProfile

        # Extract request data
        blood_type = request.data.get('blood_type')
        hospital_name = request.data.get('hospital_name', 'Unknown Hospital')
        hospital_address = request.data.get('hospital_address', '')
        hospital_lat = request.data.get('hospital_lat')
        hospital_lng = request.data.get('hospital_lng')
        patient_name = request.data.get('patient_name', 'Patient')
        contact_phone = request.data.get('contact_phone', '')
        urgency_level = request.data.get('urgency_level', 'critical')
        radius_km = float(request.data.get('radius_km', 10))

        # Validate required fields
        if not blood_type:
            return error_response(
                message='blood_type is required',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        if not hospital_lat or not hospital_lng:
            return error_response(
                message='hospital_lat and hospital_lng are required',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        hospital_lat = float(hospital_lat)
        hospital_lng = float(hospital_lng)

        # Log SOS request
        notification_id = f"sos_{uuid.uuid4().hex[:8]}"
        logger.info(f"SOS Alert [{notification_id}]: {blood_type} needed at {hospital_name}")

        # Get compatible blood types
        compatible_types = get_compatible_blood_types(blood_type)
        logger.info(f"Compatible blood types for {blood_type}: {compatible_types}")

        # Query eligible donors
        eligible_donors = UserProfile.objects.filter(
            blood_group__in=compatible_types,
            fcm_token__isnull=False,
            user__is_active=True
        ).exclude(fcm_token='').select_related('user').all()

        # Filter by distance
        donor_tokens = []
        donor_distances = {}

        for donor in eligible_donors:
            if not donor.location_lat or not donor.location_lng:
                continue

            # Calculate distance from donor to hospital
            distance = calculate_distance(
                float(donor.location_lat),
                float(donor.location_lng),
                hospital_lat,
                hospital_lng
            )

            if distance <= radius_km:
                donor_tokens.append(donor.fcm_token)
                donor_distances[donor.fcm_token] = distance

        # Remove duplicate tokens
        unique_tokens = list(set(donor_tokens))

        logger.info(f"Found {len(unique_tokens)} eligible donors within {radius_km}km")

        if not unique_tokens:
            return success_response(
                message='No eligible donors found in the specified area',
                data={
                    'notification_id': notification_id,
                    'notified_count': 0,
                    'target_radius': radius_km,
                    'eligible_donors': 0,
                    'message_detail': f'No compatible donors with valid FCM tokens found within {radius_km}km radius'
                }
            )

        # Send batch SOS notifications
        notification_result = send_batch_sos_notifications(
            donor_tokens=unique_tokens,
            blood_type=blood_type,
            hospital_name=hospital_name,
            hospital_address=hospital_address,
            sos_id=notification_id,
            urgency=urgency_level,
            donor_distances=donor_distances
        )

        logger.info(f"SOS [{notification_id}]: Sent {notification_result['success_count']} notifications, "
                   f"{notification_result['failure_count']} failed")

        return success_response(
            message=f'SOS notifications sent to {notification_result["success_count"]} donors',
            data={
                'notification_id': notification_id,
                'notified_count': notification_result['success_count'],
                'target_radius': radius_km,
                'eligible_donors': len(unique_tokens),
                'failed_count': notification_result['failure_count'],
                'urgency_level': urgency_level,
                'blood_type': blood_type,
                'hospital_name': hospital_name
            }
        )

    except Exception as e:
        logger.error(f"Error sending SOS notifications: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to send SOS notifications',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_sos(request):
    """
    Create a new SOS emergency blood request.

    POST /api/sos/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "blood_type": "O+",
        "hospital_name": "Emergency Center",
        "hospital_address": "456 Emergency Ave",
        "hospital_lat": 40.7128,
        "hospital_lng": -74.0060,
        "contact_phone": "+1234567890",
        "patient_name": "Jane Doe",
        "age": 35,
        "gender": "Female",
        "units_needed": 2
    }

    Response (201 Created):
    {
        "success": true,
        "message": "SOS request created",
        "data": {
            "sos_request": {...}
        }
    }
    """
    try:
        # Verify user is a patient
        if request.user.role != 'patient':
            return error_response(
                message='SOS requests are only available for patients. Please switch your role to patient to use this feature.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        serializer = SOSRequestSerializer(
            data=request.data,
            context={'request': request}
        )

        if serializer.is_valid():
            sos_request = serializer.save()
            logger.info(f"New SOS request created: {sos_request.id} by {request.user.email}")

            return success_response(
                message='SOS request created successfully. Help is on the way!',
                data={
                    'sos_request': PublicSOSRequestSerializer(sos_request).data
                },
                status_code=status.HTTP_201_CREATED
            )

        logger.warning(f"SOS request creation failed: {serializer.errors}")
        return error_response(
            message='Failed to create SOS request.',
            errors=serializer.errors
        )

    except Exception as e:
        logger.error(f"Error creating SOS request: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while creating the SOS request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def list_active_sos(request):
    """
    List all active SOS requests with location filtering.

    GET /api/sos/active/?lat=40.7128&lng=-74.0060&radius=100&blood_type=O+

    Query Parameters:
    - lat (required) - Latitude
    - lng (required) - Longitude
    - radius (optional) - Radius in km (default: 100)
    - blood_type (optional) - Filter by blood type

    Response (200 OK):
    {
        "success": true,
        "message": "Active SOS requests found",
        "data": {
            "requests": [...],
            "count": 2
        }
    }
    """
    try:
        from math import radians, cos, sin, sqrt, asin

        # Get query parameters
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        radius = float(request.query_params.get('radius', 100))  # Default 100km
        blood_type = request.query_params.get('blood_type')

        # Build queryset - active SOS requests from last 2 hours
        from datetime import timedelta
        from django.utils import timezone

        two_hours_ago = timezone.now() - timedelta(hours=2)
        queryset = SOSRequest.objects.filter(
            status='active',
            created_at__gte=two_hours_ago
        ).order_by('-created_at')

        # Filter by blood type if provided
        if blood_type:
            queryset = queryset.filter(blood_type=blood_type)

        # Serialize and add distance calculation
        requests_data = []
        for sos in queryset:
            request_dict = PublicSOSRequestSerializer(sos).data

            # Calculate distance if coordinates are available
            if sos.hospital_lat and sos.hospital_lng and lat and lng:
                try:
                    lat1 = radians(float(lat))
                    lat2 = radians(float(sos.hospital_lat))
                    lng1 = radians(float(lng))
                    lng2 = radians(float(sos.hospital_lng))

                    dlat = lat2 - lat1
                    dlng = lng2 - lng1

                    a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlng / 2)**2
                    c = 2 * asin(sqrt(a))
                    distance_km = 6371 * c  # Earth's radius in km

                    request_dict['distance_km'] = round(distance_km, 1)

                    # Filter by radius
                    if distance_km > radius:
                        continue
                except (ValueError, TypeError):
                    request_dict['distance_km'] = None
            else:
                request_dict['distance_km'] = None

            requests_data.append(request_dict)

        return success_response(
            message=f'Found {len(requests_data)} active SOS requests.',
            data={
                'requests': requests_data,
                'count': len(requests_data)
            }
        )

    except Exception as e:
        logger.error(f"Error fetching active SOS requests: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch active SOS requests.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def sos_detail(request, sos_id):
    """
    Get details of a specific SOS request.

    GET /api/sos/{id}/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "SOS retrieved",
        "data": {
            "sos": {...}
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)
        serializer = SOSRequestSerializer(sos_request)

        return success_response(
            message='SOS request retrieved successfully.',
            data={
                'sos': serializer.data
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error fetching SOS request: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch SOS request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def respond_to_sos(request, sos_id):
    """
    Respond to an SOS request.

    POST /api/sos/{id}/respond/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "can_help": true,
        "estimated_arrival_minutes": 30,
        "note": "On my way"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Response recorded",
        "data": {
            "responders_count": 4
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if already responded
        if SOSResponse.objects.filter(sos_request=sos_request, responder=request.user).exists():
            return error_response(
                message='You have already responded to this SOS request.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Check if SOS is still active
        if sos_request.status != 'active':
            return error_response(
                message='This SOS request is no longer active.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Create response
        response_data = {
            'sos_request': sos_request.id,
            'can_help': request.data.get('can_help', True)
        }

        if 'estimated_arrival_minutes' in request.data:
            response_data['estimated_arrival_minutes'] = request.data['estimated_arrival_minutes']

        if 'note' in request.data:
            response_data['note'] = request.data['note']

        serializer = SOSResponseSerializer(
            data=response_data,
            context={'request': request}
        )

        if serializer.is_valid():
            serializer.save()
            logger.info(f"{request.user.email} responded to SOS {sos_id}")

            # Refresh to get updated responders_count
            sos_request.refresh_from_db()

            return success_response(
                message='Response recorded successfully. Thank you for helping!',
                data={
                    'responders_count': sos_request.responders_count
                }
            )

        return error_response(
            message='Failed to record response.',
            errors=serializer.errors
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error responding to SOS: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while recording your response.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def resolve_sos(request, sos_id):
    """
    Resolve an SOS request (only by requester).

    POST /api/sos/{id}/resolve/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "resolution_note": "Blood successfully delivered"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "SOS resolved",
        "data": {
            "id": "uuid",
            "status": "resolved",
            "resolved_at": "2024-06-05T12:00:00Z"
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if user is authorized (created the request or is staff)
        if sos_request.requester != request.user and not request.user.is_staff:
            return error_response(
                message='You are not authorized to resolve this SOS request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Update status
        sos_request.status = 'resolved'
        sos_request.resolved_at = timezone.now()
        sos_request.resolution_note = request.data.get('resolution_note', '')
        sos_request.save()

        logger.info(f"SOS request {sos_id} resolved by {request.user.email}")

        # Notify all responders
        try:
            from notifications.services.fcm_service import notify_sos_responders_status_change
            notify_sos_responders_status_change(sos_request, 'resolved')
        except Exception as e:
            logger.warning(f"Failed to send notifications for SOS resolution: {str(e)}")

        return success_response(
            message='SOS request resolved successfully. Thank you for updating!',
            data={
                'id': str(sos_request.id),
                'status': sos_request.status,
                'resolved_at': sos_request.resolved_at
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error resolving SOS: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while resolving the SOS request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_sos(request, sos_id):
    """
    Cancel an SOS request (only by requester).

    POST /api/sos/{id}/cancel/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "SOS cancelled",
        "data": {
            "id": "uuid",
            "status": "cancelled"
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if user is authorized (created the request or is staff)
        if sos_request.requester != request.user and not request.user.is_staff:
            return error_response(
                message='You are not authorized to cancel this SOS request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Update status
        sos_request.status = 'cancelled'
        sos_request.save()

        logger.info(f"SOS request {sos_id} cancelled by {request.user.email}")

        # Notify all responders
        try:
            from notifications.services.fcm_service import notify_sos_responders_status_change
            notify_sos_responders_status_change(sos_request, 'cancelled')
        except Exception as e:
            logger.warning(f"Failed to send notifications for SOS cancellation: {str(e)}")

        return success_response(
            message='SOS request cancelled successfully.',
            data={
                'id': str(sos_request.id),
                'status': sos_request.status
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error cancelling SOS: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while cancelling the SOS request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
