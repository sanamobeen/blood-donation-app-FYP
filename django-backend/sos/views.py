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
from datetime import timedelta
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from .serializers import SOSRequestSerializer, PublicSOSRequestSerializer, SOSResponseSerializer
from .models import SOSRequest, SOSResponse
from notifications.models import Notification


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
            donor_distances=donor_distances,
            patient_name=patient_name or 'Patient',
            created_at=timezone.now().isoformat(),
        )

        logger.info(f"SOS [{notification_id}]: Sent {notification_result['success_count']} notifications, "
                   f"{notification_result['failure_count']} failed")

        # Create in-app notifications for eligible donors
        for donor in eligible_donors:
            if donor.fcm_token in unique_tokens:
                Notification.objects.create(
                    user=donor.user,
                    title=f'🚨 Urgent Blood Request: {patient_name or "Patient"}',
                    message=f'{blood_type} blood needed at {hospital_name}. Only {donor_distances.get(donor.fcm_token, 0):.1f}km away.',
                    type='sos_alert',
                    related_request_id=notification_id,
                    data={
                        'sos_id': notification_id,
                        'patient_name': patient_name or 'Patient',
                        'blood_type': blood_type,
                        'hospital_name': hospital_name,
                        'hospital_address': hospital_address,
                        'distance_km': donor_distances.get(donor.fcm_token, 0),
                        'urgency': urgency_level,
                        'created_at': timezone.now().isoformat(),
                    }
                )
                logger.info(f"Created in-app notification for donor {donor.user.email}")

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

            # Send notifications to nearby compatible donors
            try:
                from account.fcm_service import (
                    get_compatible_blood_types,
                    calculate_distance,
                    send_batch_sos_notifications
                )
                from account.models import UserProfile

                # Get compatible blood types
                compatible_types = get_compatible_blood_types(sos_request.blood_type)
                logger.info(f"Compatible blood types for {sos_request.blood_type}: {compatible_types}")

                # Query eligible donors with location
                eligible_donors = []
                radius_km = 50  # Search within 50km

                for donor in UserProfile.objects.filter(
                    blood_group__in=compatible_types,
                    fcm_token__isnull=False,
                    user__is_active=True
                ).exclude(fcm_token='').select_related('user').all():

                    # Check if donor has location
                    if not donor.location_lat or not donor.location_lng:
                        continue

                    # Calculate distance from donor to hospital
                    distance = calculate_distance(
                        donor.location_lat,
                        donor.location_lng,
                        sos_request.hospital_lat,
                        sos_request.hospital_lng
                    )

                    # Filter by radius
                    if distance <= radius_km:
                        eligible_donors.append({
                            'profile': donor,
                            'distance': distance,
                            'fcm_token': donor.fcm_token
                        })

                # Send notifications to eligible donors
                if eligible_donors:
                    notification_result = send_batch_sos_notifications(
                        donor_tokens=[d['fcm_token'] for d in eligible_donors],
                        blood_type=sos_request.blood_type,
                        hospital_name=sos_request.hospital_name,
                        hospital_address=sos_request.hospital_address,
                        sos_id=str(sos_request.id),
                        urgency='critical',
                        donor_distances={d['fcm_token']: d['distance'] for d in eligible_donors},
                        patient_name=sos_request.patient_name or 'Patient',
                        created_at=sos_request.created_at.isoformat(),
                    )
                    success_count = notification_result.get('success_count', 0)
                    logger.info(f"Sent {success_count} SOS notifications to nearby donors")

                    # Create in-app notifications for eligible donors
                    for donor_data in eligible_donors:
                        donor_profile = donor_data['profile']
                        Notification.objects.create(
                            user=donor_profile.user,
                            title=f'🚨 Urgent Blood Request: {sos_request.patient_name or "Patient"}',
                            message=f'{sos_request.blood_type} blood needed at {sos_request.hospital_name}. Only {donor_data["distance"]:.1f}km away.',
                            type='sos_alert',
                            related_request_id=str(sos_request.id),
                            data={
                                'sos_id': str(sos_request.id),
                                'patient_name': sos_request.patient_name or 'Patient',
                                'blood_type': sos_request.blood_type,
                                'hospital_name': sos_request.hospital_name,
                                'hospital_address': sos_request.hospital_address,
                                'distance_km': donor_data['distance'],
                                'urgency': 'critical',
                                'created_at': sos_request.created_at.isoformat(),
                            }
                        )
                        logger.info(f"Created in-app notification for donor {donor_profile.user.email}")
                else:
                    logger.warning(f"No eligible donors found within {radius_km}km")

            except Exception as notification_error:
                # Log error but don't fail the SOS creation
                logger.error(f"Failed to send SOS notifications: {str(notification_error)}", exc_info=True)

            return success_response(
                message='SOS request created successfully. Help is on the way!',
                data={
                    'sos_request': PublicSOSRequestSerializer(sos_request).data,
                    'notified_donors': len(eligible_donors) if 'eligible_donors' in locals() else 0,
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

            # Get responders for this SOS request
            responses = SOSResponse.objects.filter(sos_request=sos).select_related('responder__profile')
            responders_data = SOSResponseSerializer(responses, many=True).data
            request_dict['responders'] = responders_data

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
def my_active_sos(request):
    """
    Get current user's active SOS requests.

    GET /api/sos/my-active/

    Returns all active SOS requests created by the authenticated user.

    Response (200 OK):
    {
        "success": true,
        "message": "Found 1 active SOS request",
        "data": {
            "requests": [...],
            "count": 1
        }
    }
    """
    try:
        # Get user's active SOS requests
        queryset = SOSRequest.objects.filter(
            requester=request.user,
            status='active'
        ).order_by('-created_at')

        # Serialize and add responders
        requests_data = []
        for sos in queryset:
            request_dict = SOSRequestSerializer(sos).data

            # Get responders for this SOS request
            responses = SOSResponse.objects.filter(sos_request=sos).select_related('responder__profile')
            responders_data = SOSResponseSerializer(responses, many=True).data
            request_dict['responders'] = responders_data

            requests_data.append(request_dict)

        return success_response(
            message=f'Found {len(requests_data)} active SOS request{"s" if len(requests_data) != 1 else ""}.',
            data={
                'requests': requests_data,
                'count': len(requests_data)
            }
        )

    except Exception as e:
        logger.error(f"Error fetching my active SOS: {str(e)}", exc_info=True)
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

        # Get responses
        responses = SOSResponse.objects.filter(sos_request=sos_request).select_related('responder')
        responders_data = SOSResponseSerializer(responses, many=True).data

        # Check if current user has responded
        has_responded = responses.filter(responder=request.user).exists()

        return success_response(
            message='SOS request retrieved successfully.',
            data={
                'sos_request': serializer.data,
                'responders': responders_data,
                'has_responded': has_responded
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

        logger.info(f"SOS Response attempt by {request.user.email} for SOS {sos_id} (status: {sos_request.status})")

        # Check if already responded
        if SOSResponse.objects.filter(sos_request=sos_request, responder=request.user).exists():
            logger.warning(f"{request.user.email} already responded to SOS {sos_id}")
            return error_response(
                message='You have already responded to this SOS request.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Check if SOS is still active
        if sos_request.status != 'active':
            logger.warning(f"SOS {sos_id} is not active (status: {sos_request.status})")
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

            # Send notification to the SOS requester (patient)
            try:
                from account.models import UserProfile

                requester_profile = sos_request.requester.profile

                # Create in-app notification for the patient
                sos_response = serializer.instance
                Notification.objects.create(
                    user=sos_request.requester,
                    title=f'🎉 Donor Responding to Your SOS!',
                    message=f'{request.user.profile.blood_group or "A donor"} is on their way! ETA: {response_data.get("estimated_arrival_minutes", "TBD")} minutes.',
                    type='sos_response',
                    related_request_id=str(sos_request.id),
                    data={
                        'sos_id': str(sos_request.id),
                        'response_id': str(sos_response.id),
                        'responder_name': request.user.get_full_name() or request.user.email,
                        'responder_email': request.user.email,
                        'responder_blood_type': request.user.profile.blood_group,
                        'estimated_arrival_minutes': response_data.get('estimated_arrival_minutes'),
                        'note': response_data.get('note', ''),
                    }
                )

                # Send FCM push notification if requester has token
                if requester_profile.fcm_token:
                    from account.fcm_service import send_to_device
                    send_to_device(
                        registration_token=requester_profile.fcm_token,
                        title=f'🎉 Donor Responding to Your SOS!',
                        body=f'{request.user.profile.blood_group or "A donor"} is on their way! ETA: {response_data.get("estimated_arrival_minutes", "TBD")} min.',
                        data={
                            'type': 'sos_response',
                            'sos_id': str(sos_request.id),
                            'response_id': str(sos_response.id),
                            'responder_name': request.user.get_full_name() or request.user.email,
                        },
                        android_channel_id='sos_alerts',
                    )
                    logger.info(f"Sent SOS response notification to {sos_request.requester.email}")
            except Exception as notify_error:
                logger.error(f"Failed to send SOS response notification: {str(notify_error)}", exc_info=True)

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


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def accept_sos_response(request, sos_id, response_id):
    """
    Accept a donor's response to SOS request.

    POST /api/sos/{sos_id}/accept-response/{response_id}/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Donor accepted",
        "data": {
            "response": {
                "id": "uuid",
                "status": "accepted",
                "donor_name": "John Doe"
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if user is the requester
        if sos_request.requester != request.user:
            return error_response(
                message='You are not authorized to accept responses for this SOS.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Update status
        response.status = 'accepted'
        response.accepted_at = timezone.now()
        response.save()

        logger.info(f"{request.user.email} accepted response from {response.responder.email} for SOS {sos_id}")

        # Update the existing notification type to hide accept button
        try:
            from notifications.models import Notification
            # Find the sos_response notification for this response and update its type
            Notification.objects.filter(
                user=sos_request.requester,
                type='sos_response',
                related_request_id=str(sos_request.id)
            ).update(type='sos_response_accepted')
            logger.info(f"Updated notification type to 'sos_response_accepted' for SOS {sos_id}")
        except Exception as e:
            logger.warning(f"Failed to update notification type: {str(e)}")

        # Notify the donor
        try:
            from notifications.services.fcm_service import notify_donor_sos_accepted
            notify_donor_sos_accepted(response)
        except Exception as e:
            logger.warning(f"Failed to send notification to donor: {str(e)}")

        return success_response(
            message='Donor response accepted. They will be notified.',
            data={
                'response': {
                    'id': str(response.id),
                    'status': response.status,
                    'donor_name': response.responder.full_name
                }
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error accepting SOS response: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while accepting the response.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_donation(request, sos_id, response_id):
    """
    Confirm that a donor has completed blood donation.

    POST /api/sos/{sos_id}/confirm-donation/{response_id}/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Donation confirmed",
        "data": {
            "response": {
                "id": "uuid",
                "status": "donated"
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if user is the requester
        if sos_request.requester != request.user:
            return error_response(
                message='You are not authorized to confirm donations for this SOS.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Update status
        response.status = 'donated'
        response.donated_at = timezone.now()
        response.save()

        # Automatically resolve SOS when donation is confirmed
        sos_request.status = 'resolved'
        sos_request.resolved_at = timezone.now()
        sos_request.resolution_notes = f'Donation confirmed from donor {response.responder.full_name or response.responder.email}'
        sos_request.save()

        logger.info(f"{request.user.email} confirmed donation from {response.responder.email} for SOS {sos_id}")
        logger.info(f"SOS {sos_id} automatically resolved after donation confirmation")

        # Notify the donor
        try:
            from notifications.services.fcm_service import notify_donor_donation_confirmed
            notify_donor_donation_confirmed(response)
        except Exception as e:
            logger.warning(f"Failed to send notification to donor: {str(e)}")

        return success_response(
            message='Donation confirmed. Thank you for updating!',
            data={
                'response': {
                    'id': str(response.id),
                    'status': response.status,
                    'donor_name': response.responder.full_name
                }
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error confirming donation: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while confirming the donation.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_no_show(request, sos_id, response_id):
    """
    Mark an accepted donor as no-show (by patient).

    POST /api/sos/{sos_id}/mark-no-show/{response_id}/

    This allows the patient to manually mark a donor as no-show
    if they haven't arrived within their ETA.

    Response (200 OK):
    {
        "success": true,
        "message": "Donor marked as no-show",
        "data": {
            "response": {
                "id": "uuid",
                "status": "no_show"
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if user is the requester
        if sos_request.requester != request.user:
            return error_response(
                message='You are not authorized to modify responses for this SOS.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Check if response is accepted (can only mark accepted as no-show)
        if response.status != 'accepted':
            return error_response(
                message=f'Can only mark accepted responses as no-show. Current status: {response.status}',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Check if already arrived
        if response.arrived_at is not None:
            return error_response(
                message='Donor has already confirmed arrival. Cannot mark as no-show.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Update status to no_show
        response.status = 'no_show'
        response.save()

        logger.info(f"{request.user.email} marked donor {response.responder.email} as no-show for SOS {sos_id}")

        # Notify both parties
        try:
            from notifications.services.fcm_service import notify_donor_response_rejected
            from notifications.models import Notification, DeviceToken

            # Notify donor
            Notification.objects.create(
                user=response.responder,
                title="⚠️ Marked as No-Show",
                message=f"The patient at {sos_request.hospital_name} has marked you as no-show. Please confirm arrival promptly in the future.",
                type='marked_no_show',
                related_request_id=str(sos_request.id),
                data={
                    'sos_id': str(sos_request.id),
                }
            )

            # Get donor's device tokens for push notification
            donor_tokens = list(
                DeviceToken.objects.filter(
                    user=response.responder,
                    is_active=True
                ).values_list('token', flat=True)
            )

            if donor_tokens:
                from notifications.services.fcm_service import send_push_notification_to_multiple
                send_push_notification_to_multiple(
                    tokens=donor_tokens,
                    title="⚠️ Marked as No-Show",
                    body=f"You were marked as no-show for the SOS at {sos_request.hospital_name}.",
                    data={
                        'type': 'marked_no_show',
                        'sos_id': str(sos_request.id),
                    }
                )

            logger.info(f"Sent no-show notification to donor {response.responder.email}")

        except Exception as e:
            logger.warning(f"Failed to send no-show notifications: {str(e)}")

        return success_response(
            message='Donor marked as no-show. They have been notified.',
            data={
                'response': {
                    'id': str(response.id),
                    'status': response.status,
                }
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error marking no-show: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while marking donor as no-show.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def notify_donor_late(request, sos_id, response_id):
    """
    Notify donor that they are running late (patient action).

    POST /api/sos/{sos_id}/notify-donor-late/{response_id}/

    This allows the patient to send a gentle reminder to the donor
    when they are late past their ETA.

    Request body (optional):
    {
        "minutes_late": 5  // Optional, defaults to 5
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Donor has been notified that they are late",
        "data": {
            "minutes_late": 5
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if user is the requester
        if sos_request.requester != request.user:
            return error_response(
                message='You are not authorized to send notifications for this SOS.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Check if response is accepted
        if response.status not in ['accepted', 'in_transit']:
            return error_response(
                message=f'Can only notify accepted donors. Current status: {response.status}',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Check if already arrived
        if response.arrived_at is not None:
            return error_response(
                message='Donor has already confirmed arrival.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Get minutes late from request, default to 5
        minutes_late = request.data.get('minutes_late', 5)

        # Calculate if they're actually late based on ETA
        if response.estimated_arrival_minutes and response.accepted_at:
            elapsed = (timezone.now() - response.accepted_at).total_seconds() / 60
            estimated_arrival_time = response.accepted_at + timezone.timedelta(minutes=response.estimated_arrival_minutes)
            actual_minutes_late = max(0, int((timezone.now() - estimated_arrival_time).total_seconds() / 60))

            # Use the greater of calculated or provided value
            minutes_late = max(minutes_late, actual_minutes_late)

        logger.info(f"{request.user.email} notified donor {response.responder.email} that they are {minutes_late} minutes late")

        # Send notification to donor
        try:
            from notifications.services.fcm_service import notify_donor_running_late

            success = notify_donor_running_late(response, minutes_late)

            if success:
                return success_response(
                    message=f'Donor has been notified that they are {minutes_late} minutes late.',
                    data={
                        'minutes_late': minutes_late,
                        'response_id': str(response.id),
                    }
                )
            else:
                return error_response(
                    message='Could not send notification. Donor may not have a registered device.',
                    status_code=status.HTTP_400_BAD_REQUEST
                )

        except Exception as e:
            logger.warning(f"Failed to send late notification: {str(e)}")
            return error_response(
                message='Failed to send notification to donor.',
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error notifying donor late: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while notifying the donor.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def donor_cannot_arrive(request, sos_id, response_id):
    """
    Donor confirms they cannot arrive / cancels their response.

    POST /api/sos/{sos_id}/donor-cannot-arrive/{response_id}/

    This allows the donor to notify the patient that they cannot make it.

    Request body (optional):
    {
        "reason": "Stuck in traffic, will be very late"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Patient has been notified that you cannot arrive",
        "data": {
            "response": {
                "id": "uuid",
                "status": "cancelled"
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Check if user is the responder
        if response.responder != request.user:
            return error_response(
                message='You are not authorized to modify this response.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Check if response can still be cancelled
        if response.status in ['donated', 'no_show']:
            return error_response(
                message=f'Cannot cancel response with status: {response.status}',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Get optional reason
        reason = request.data.get('reason', 'Donor unable to arrive')

        # Update status to cancelled
        previous_status = response.status
        response.status = 'cancelled'
        response.cancelled_at = timezone.now()
        response.note = f"{response.note or ''} [Cancellation: {reason}]" if response.note else f"[Cancellation: {reason}]"
        response.save()

        logger.info(f"{request.user.email} cancelled their response to SOS {sos_id}. Reason: {reason}")

        # Notify patient
        try:
            from notifications.services.fcm_service import notify_patient_donor_not_arriving

            success = notify_patient_donor_not_arriving(response)

            if success:
                return success_response(
                    message='Patient has been notified that you cannot arrive.',
                    data={
                        'response': {
                            'id': str(response.id),
                            'status': response.status,
                            'previous_status': previous_status,
                        }
                    }
                )
            else:
                return success_response(
                    message='Response cancelled. Could not notify patient.',
                    data={
                        'response': {
                            'id': str(response.id),
                            'status': response.status,
                        }
                    }
                )

        except Exception as e:
            logger.warning(f"Failed to send cannot arrive notification: {str(e)}")
            return success_response(
                message='Response cancelled.',
                data={
                    'response': {
                        'id': str(response.id),
                        'status': response.status,
                    }
                }
            )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error cancelling response: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while cancelling the response.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_response_eta(request, sos_id, response_id):
    """
    Update donor's estimated arrival time.

    POST /api/sos/{sos_id}/update-eta/{response_id}/

    Headers:
        Authorization: Bearer <access_token>

    Body:
    {
        "estimated_arrival_minutes": 15,
        "note": "Running a bit late due to traffic"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "ETA updated successfully",
        "data": {
            "response": {
                "id": "uuid",
                "estimated_arrival_minutes": 15
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Check if user is the responder
        if response.responder != request.user:
            return error_response(
                message='You can only update your own ETA.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Check if response is still active (not rejected, donated, or no_show)
        if response.status in ['rejected', 'donated', 'no_show']:
            return error_response(
                message=f'Cannot update ETA for response with status: {response.status}',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Get previous ETA for comparison
        previous_eta = response.estimated_arrival_minutes
        new_eta = request.data.get('estimated_arrival_minutes')

        if new_eta is None:
            return error_response(
                message='estimated_arrival_minutes is required',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        try:
            new_eta = int(new_eta)
            if new_eta < 0:
                return error_response(
                    message='ETA cannot be negative',
                    status_code=status.HTTP_400_BAD_REQUEST
                )
        except (ValueError, TypeError):
            return error_response(
                message='ETA must be a valid number',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Calculate delay
        delay_minutes = None
        if previous_eta and new_eta > previous_eta:
            delay_minutes = new_eta - previous_eta

        # Update response
        response.estimated_arrival_minutes = new_eta
        response.note = request.data.get('note', response.note)
        response.save()

        logger.info(f"{request.user.email} updated ETA to {new_eta} minutes for SOS {sos_id}")

        # Notify the patient about ETA update
        try:
            from notifications.services.fcm_service import notify_patient_eta_update, notify_patient_donor_running_late

            # If running late (more than 5 minutes delay), send running late notification
            if delay_minutes and delay_minutes > 5:
                notify_patient_donor_running_late(response, new_eta, delay_minutes)
            else:
                notify_patient_eta_update(response, new_eta)
        except Exception as e:
            logger.warning(f"Failed to send notification to patient: {str(e)}")

        return success_response(
            message='ETA updated successfully',
            data={
                'response': {
                    'id': str(response.id),
                    'estimated_arrival_minutes': response.estimated_arrival_minutes,
                    'previous_eta': previous_eta,
                    'delay_minutes': delay_minutes,
                }
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error updating ETA: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while updating your ETA.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_donor_arrival(request, sos_id, response_id):
    """
    Confirm that donor has arrived at the hospital.

    POST /api/sos/{sos_id}/confirm-arrival/{response_id}/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Arrival confirmed",
        "data": {
            "response": {
                "id": "uuid",
                "status": "accepted",
                "arrived_at": "2024-01-01T12:00:00Z"
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Check if user is the responder
        if response.responder != request.user:
            return error_response(
                message='You can only confirm your own arrival.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Check if response is accepted
        if response.status != 'accepted':
            return error_response(
                message='You can only confirm arrival for accepted responses.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Store arrival time (we'll add a field for this, or just use the notification)
        logger.info(f"{request.user.email} confirmed arrival at hospital for SOS {sos_id}")

        # Notify the patient about donor arrival
        try:
            from notifications.services.fcm_service import notify_patient_donor_arrived
            notify_patient_donor_arrived(response)
        except Exception as e:
            logger.warning(f"Failed to send notification to patient: {str(e)}")

        return success_response(
            message='Arrival confirmed. The patient has been notified!',
            data={
                'response': {
                    'id': str(response.id),
                    'status': response.status,
                    'sos_id': str(sos_request.id),
                    'hospital_name': sos_request.hospital_name,
                }
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error confirming arrival: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while confirming your arrival.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_on_my_way(request, sos_id, response_id):
    """
    Confirm to patient that donor is on their way (after being accepted).

    POST /api/sos/{sos_id}/confirm-on-my-way/{response_id}/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Patient has been notified you're on your way.",
        "data": {
            "response": {
                "id": "uuid",
                "status": "accepted"
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Check if user is the responder
        if response.responder != request.user:
            return error_response(
                message='You can only confirm your own response.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Check if response is accepted
        if response.status != 'accepted':
            return error_response(
                message='You can only confirm for accepted responses.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        logger.info(f"{request.user.email} confirmed they're on their way for SOS {sos_id}")

        # Notify the patient that donor is on their way
        try:
            from notifications.services.fcm_service import notify_patient_donor_on_my_way
            notify_patient_donor_on_my_way(response)
        except Exception as e:
            logger.warning(f"Failed to send notification to patient: {str(e)}")

        return success_response(
            message='Patient has been notified you\'re on your way.',
            data={
                'response': {
                    'id': str(response.id),
                    'status': response.status,
                    'sos_id': str(sos_request.id),
                }
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error confirming on my way: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while confirming.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def reject_sos_response(request, sos_id, response_id):
    """
    Reject a specific donor's response (by patient).

    POST /api/sos/{sos_id}/reject-response/{response_id}/

    Headers:
        Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Response rejected",
        "data": {
            "response": {
                "id": "uuid",
                "status": "rejected"
            }
        }
    }
    """
    try:
        sos_request = SOSRequest.objects.get(id=sos_id)

        # Check if user is the requester
        if sos_request.requester != request.user:
            return error_response(
                message='You are not authorized to reject responses for this SOS.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get the response
        response = SOSResponse.objects.get(id=response_id, sos_request=sos_request)

        # Check if response is still pending
        if response.status != 'pending':
            return error_response(
                message=f'Cannot reject response with status: {response.status}',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Update status
        response.status = 'rejected'
        response.save()

        logger.info(f"{request.user.email} rejected response from {response.responder.email} for SOS {sos_id}")

        # Update the existing notification type to hide accept/decline buttons
        try:
            from notifications.models import Notification
            # Find the sos_response notification for this response and update its type
            Notification.objects.filter(
                user=sos_request.requester,
                type='sos_response',
                related_request_id=str(sos_request.id)
            ).update(type='sos_response_rejected')
            logger.info(f"Updated notification type to 'sos_response_rejected' for SOS {sos_id}")
        except Exception as e:
            logger.warning(f"Failed to update notification type: {str(e)}")

        # Notify the donor
        try:
            from notifications.services.fcm_service import notify_donor_response_rejected
            notify_donor_response_rejected(response)
        except Exception as e:
            logger.warning(f"Failed to send notification to donor: {str(e)}")

        return success_response(
            message='Response rejected. The donor has been notified.',
            data={
                'response': {
                    'id': str(response.id),
                    'status': response.status,
                }
            }
        )

    except SOSRequest.DoesNotExist:
        return error_response(
            message='SOS request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except SOSResponse.DoesNotExist:
        return error_response(
            message='Response not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error rejecting response: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while rejecting the response.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def debug_sos_notifications(request):
    """
    Debug endpoint to check SOS notification configuration.

    GET /api/sos/debug-notifications/

    Response (200 OK):
    {
        "success": true,
        "firebase_configured": true,
        "donors_checked": 5,
        "eligible_donors": [
            {
                "email": "donor@example.com",
                "blood_group": "A+",
                "has_fcm_token": true,
                "has_location": true,
                "distance_km": 5.2,
                "is_eligible": true
            }
        ],
        "issues": ["List of any issues found"]
    }
    """
    try:
        from account.models import UserProfile
        from account.fcm_service import get_compatible_blood_types, calculate_distance
        import firebase_admin

        # Check if Firebase is configured
        firebase_configured = len(firebase_admin._apps) > 0

        # Get all donor profiles
        donor_profiles = UserProfile.objects.filter(
            user__role='donor',
            user__is_active=True
        ).select_related('user').all()

        # Use hospital location from a recent SOS or use a test location
        test_lat = float(request.query_params.get('lat', 31.5204))  # Default: Lahore
        test_lng = float(request.query_params.get('lng', 74.3587))
        test_blood_type = request.query_params.get('blood_type', 'A+')

        # Get compatible blood types
        compatible_types = get_compatible_blood_types(test_blood_type)

        eligible_donors = []
        all_donors_info = []
        issues = []

        for donor in donor_profiles:
            donor_info = {
                'email': donor.user.email,
                'blood_group': donor.blood_group,
                'has_fcm_token': bool(donor.fcm_token),
                'has_location': bool(donor.location_lat and donor.location_lng),
                'fcm_token_preview': donor.fcm_token[:20] + '...' if donor.fcm_token else None,
                'distance_km': None,
                'is_eligible': False,
                'issues': []
            }

            # Check blood type compatibility
            if donor.blood_group not in compatible_types:
                donor_info['issues'].append(f'Blood type {donor.blood_group} not compatible with {test_blood_type}')
                issues.append(f"{donor.user.email}: Incompatible blood type")
            elif donor.blood_group is None:
                donor_info['issues'].append('No blood group set')
                issues.append(f"{donor.user.email}: No blood group set")

            # Check FCM token
            if not donor.fcm_token:
                donor_info['issues'].append('No FCM token registered')
                issues.append(f"{donor.user.email}: No FCM token")

            # Check location
            if not donor.location_lat or not donor.location_lng:
                donor_info['issues'].append('No location set')
                issues.append(f"{donor.user.email}: No location set")
            else:
                # Calculate distance
                distance = calculate_distance(
                    float(donor.location_lat),
                    float(donor.location_lng),
                    test_lat, test_lng
                )
                donor_info['distance_km'] = round(distance, 2)

                if distance > 50:
                    donor_info['issues'].append(f'Outside 50km radius ({distance:.1f}km)')
                    issues.append(f"{donor.user.email}: Outside radius")

            # Determine eligibility
            donor_info['is_eligible'] = len(donor_info['issues']) == 0
            if donor_info['is_eligible']:
                eligible_donors.append(donor_info)

            all_donors_info.append(donor_info)

        return success_response(
            message='Debug information retrieved',
            data={
                'firebase_configured': firebase_configured,
                'test_parameters': {
                    'hospital_location': {'lat': test_lat, 'lng': test_lng},
                    'blood_type': test_blood_type,
                    'compatible_blood_types': compatible_types,
                    'radius_km': 50
                },
                'donors_checked': len(donor_profiles),
                'eligible_donors': eligible_donors,
                'all_donors': all_donors_info,
                'issues': issues
            }
        )

    except Exception as e:
        logger.error(f"Error in debug endpoint: {str(e)}", exc_info=True)
        return error_response(
            message=f'Debug error: {str(e)}',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
