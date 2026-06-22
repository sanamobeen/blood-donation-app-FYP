"""
API Views for Blood Requests.

Provides endpoints for:
- Listing blood requests
- Creating blood requests
- Viewing blood request details
- Updating blood requests
- Deleting blood requests
- Getting current user's blood requests
"""
import logging
from rest_framework import status, serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from datetime import datetime, timedelta
from django.utils import timezone

from .serializers import (
    BloodRequestSerializer,
    BloodRequestUpdateSerializer,
    DetailedBloodRequestSerializer,
    PublicBloodRequestSerializer,
    DonorResponseSerializer,
    DonorResponsePublicSerializer,
    DonorResponseCreateSerializer,
    AcceptPledgeSerializer,
    RejectPledgeSerializer,
    ConfirmDonationSerializer,
    BatchAcceptPledgesSerializer,
)
from .models import BloodRequest, DonorResponse
from django.db.models import F


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


# Blood Request Views

@api_view(['GET'])
@permission_classes([AllowAny])
def blood_request_list(request):
    """
    Get list of all active blood requests.

    GET /api/blood-requests/

    Query Parameters:
    - blood_group: Filter by blood group (optional)
    - urgency_level: Filter by urgency level (optional)
    - status: Filter by status (optional)

    Response (200 OK):
    {
        "success": true,
        "message": "Blood requests retrieved successfully",
        "blood_requests": [...],
        "count": 10
    }
    """
    try:
        # Get query parameters for filtering
        blood_group = request.query_params.get('blood_group')
        urgency_level = request.query_params.get('urgency_level')
        status_param = request.query_params.get('status', 'pending')

        # Build queryset
        queryset = BloodRequest.objects.filter(is_active=True)

        # Exclude user's own requests when authenticated (donors shouldn't see their own requests)
        logger.info(f"Fetching blood requests - Authenticated: {request.user.is_authenticated}")
        if request.user and request.user.is_authenticated:
            logger.info(f"Excluding requests from user: {request.user.email}")
            queryset = queryset.exclude(requested_by=request.user)
        else:
            logger.warning("User not authenticated - showing all requests including own")

        if blood_group:
            queryset = queryset.filter(blood_group=blood_group)
        if urgency_level:
            queryset = queryset.filter(urgency_level=urgency_level)
        if status_param:
            queryset = queryset.filter(status=status_param)

        # Order by urgency (critical first) and then by date
        queryset = queryset.order_by('-urgency_level', '-created_at')

        serializer = PublicBloodRequestSerializer(queryset, many=True)

        return success_response(
            message='Blood requests retrieved successfully.',
            data={
                'blood_requests': serializer.data,
                'count': queryset.count()
            }
        )

    except Exception as e:
        logger.error(f"Error fetching blood requests: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch blood requests.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def blood_request_create(request):
    """
    Create a new blood request with auto-expiration.

    POST /api/blood-requests/create/

    Request Body:
    {
        "patient_name": "John Doe",
        "blood_group": "A+",
        "units_needed": 2,
        "urgency_level": "urgent",
        "contact_number": "+923001234567",
        "hospital_name": "City Hospital",
        "location": "Lahore, Pakistan",
        "location_lat": 24.8607,
        "location_lng": 67.0011,
        "additional_notes": "Patient needs blood urgently"
    }

    Response (201 Created):
    {
        "success": true,
        "message": "Blood request created successfully",
        "blood_request": {...}
    }
    """
    try:
        from datetime import timedelta

        # Log incoming data for debugging
        logger.info(f"Blood request create data: {request.data}")
        logger.info(f"location_lat: {request.data.get('location_lat')}")
        logger.info(f"location_lng: {request.data.get('location_lng')}")

        serializer = BloodRequestSerializer(
            data=request.data,
            context={'request': request}
        )

        if serializer.is_valid():
            blood_request = serializer.save()
            logger.info(f"Blood request saved - lat: {blood_request.location_lat}, lng: {blood_request.location_lng}")

            # Phase 1: Set expiration based on urgency
            from .utils import calculate_request_expiration_hours
            expires_in_hours = calculate_request_expiration_hours(blood_request.urgency_level)
            blood_request.expires_at = timezone.now() + timedelta(hours=expires_in_hours)
            blood_request.save()

            logger.info(f"New blood request created: {blood_request.id} - {blood_request.patient_name} (expires in {expires_in_hours}h)")

            return success_response(
                message='Blood request created successfully.',
                data={
                    'blood_request': PublicBloodRequestSerializer(blood_request).data
                },
                status_code=status.HTTP_201_CREATED
            )

        logger.warning(f"Blood request creation failed: {serializer.errors}")
        return error_response(
            message='Failed to create blood request.',
            errors=serializer.errors
        )

    except Exception as e:
        logger.error(f"Error creating blood request: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while creating the blood request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def blood_request_detail(request, request_id):
    """
    Get details of a specific blood request.

    GET /api/blood-requests/{request_id}/

    Response (200 OK):
    {
        "success": true,
        "message": "Blood request retrieved successfully",
        "blood_request": {...}
    }
    """
    try:
        # Allow fetching both active and completed requests
        blood_request = BloodRequest.objects.get(id=request_id)
        serializer = PublicBloodRequestSerializer(blood_request)

        return success_response(
            message='Blood request retrieved successfully.',
            data={
                'blood_request': serializer.data
            }
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error fetching blood request: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch blood request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
def blood_request_update(request, request_id):
    """
    Update a blood request (only the user who created it or admin).

    PUT /api/blood-requests/{request_id}/update/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "status": "fulfilled",
        "is_active": false,
        "additional_notes": "Blood donation completed successfully"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Blood request updated successfully",
        "blood_request": {...}
    }
    """
    try:
        blood_request = BloodRequest.objects.get(id=request_id)

        # Check if user is authorized (created the request or is staff)
        if blood_request.requested_by != request.user and not request.user.is_staff:
            return error_response(
                message='You are not authorized to update this blood request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        partial = request.method == 'PATCH'
        serializer = BloodRequestUpdateSerializer(
            blood_request,
            data=request.data,
            partial=partial
        )

        if serializer.is_valid():
            updated_request = serializer.save()
            logger.info(f"Blood request updated: {request_id} by {request.user.email}")

            return success_response(
                message='Blood request updated successfully.',
                data={
                    'blood_request': PublicBloodRequestSerializer(updated_request).data
                }
            )

        return error_response(
            message='Failed to update blood request.',
            errors=serializer.errors
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error updating blood request: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while updating the blood request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def blood_request_delete(request, request_id):
    """
    Delete a blood request (only the user who created it or admin).

    DELETE /api/blood-requests/{request_id}/delete/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Blood request deleted successfully"
    }
    """
    try:
        blood_request = BloodRequest.objects.get(id=request_id)

        # Check if user is authorized (created the request or is staff)
        if blood_request.requested_by != request.user and not request.user.is_staff:
            return error_response(
                message='You are not authorized to delete this blood request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Soft delete by setting is_active to False
        blood_request.is_active = False
        blood_request.save()

        logger.info(f"Blood request deleted: {request_id} by {request.user.email}")

        return success_response(
            message='Blood request deleted successfully.'
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error deleting blood request: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while deleting the blood request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_blood_requests(request):
    """
    Get blood requests created by the current user with optional status filtering.

    GET /api/blood-requests/my-requests/

    Headers:
    Authorization: Bearer <access_token>

    Query Parameters:
    - status: Filter by status (optional)
      - 'active': Shows only active pending requests
      - 'completed': Shows only fulfilled or cancelled requests
      - 'all' or not provided: Shows all requests

    Response (200 OK):
    {
        "success": true,
        "message": "Your blood requests retrieved successfully",
        "blood_requests": [...],
        "count": 5
    }

    Examples:
    - GET /api/blood-requests/my-requests/              # All requests
    - GET /api/blood-requests/my-requests/?status=active     # Only active
    - GET /api/blood-requests/my-requests/?status=completed  # Only completed
    """
    try:
        # Get query parameter for status filtering
        status_filter = request.query_params.get('status', 'all')

        # Build base queryset
        queryset = BloodRequest.objects.filter(
            requested_by=request.user
        ).order_by('-created_at')

        # Apply status filter
        if status_filter == 'active':
            # Show only active pending requests
            queryset = queryset.filter(is_active=True, status='pending')
        elif status_filter == 'completed':
            # Show only fulfilled or cancelled requests
            queryset = queryset.filter(status__in=['fulfilled', 'cancelled'])
        # For 'all' or any other value, show all requests

        serializer = DetailedBloodRequestSerializer(queryset, many=True)

        return Response({
            'success': True,
            'message': 'Your blood requests retrieved successfully.',
            'blood_requests': serializer.data,
            'count': queryset.count()
        })

    except Exception as e:
        logger.error(f"Error fetching user's blood requests: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch your blood requests.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def blood_request_cancel(request, request_id):
    """
    Cancel a blood request (only by user who created it).

    POST /api/blood-requests/{request_id}/cancel/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Blood request cancelled",
        "data": {
            "id": "uuid",
            "status": "cancelled"
        }
    }
    """
    try:
        blood_request = BloodRequest.objects.get(id=request_id)

        # Check if user is authorized (created the request or is staff)
        if blood_request.requested_by != request.user and not request.user.is_staff:
            return error_response(
                message='You are not authorized to cancel this blood request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Update status to cancelled
        blood_request.status = 'cancelled'
        blood_request.is_active = False
        blood_request.save()

        logger.info(f"Blood request cancelled: {request_id} by {request.user.email}")

        return success_response(
            message='Blood request cancelled successfully.',
            data={
                'id': str(blood_request.id),
                'status': blood_request.status
            }
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error cancelling blood request: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while cancelling the blood request.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def nearby_blood_requests(request):
    """
    Get nearby blood requests based on donor's location.

    GET /api/blood-requests/nearby/?lat=40.7128&lng=-74.0060&radius=50&blood_type=A+

    Phase 1 FIX: Distance is calculated from DONOR location to REQUEST location (not self).

    Query Parameters:
    - lat (optional) - Donor's latitude (uses profile location if not provided and authenticated)
    - lng (optional) - Donor's longitude (uses profile location if not provided and authenticated)
    - radius (optional) - Search radius in km (default: 50)
    - blood_type (optional) - Filter by blood type (overrides blood compatibility)

    Response (200 OK):
    {
        "success": true,
        "message": "Nearby requests found",
        "data": {
            "requests": [...],
            "count": 7
        }
    }
    """
    try:
        from .utils import haversine_distance, can_donate, get_compatible_blood_groups

        # Get query parameters
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        radius = float(request.query_params.get('radius', 50))  # Default 50km
        blood_type = request.query_params.get('blood_type')

        # CRITICAL FIX: If authenticated, use donor's profile location
        donor_blood_group = None
        if request.user and request.user.is_authenticated:
            profile = getattr(request.user, 'profile', None)
            if profile and profile.location_lat and profile.location_lng:
                # Use profile location if not explicitly provided
                if not lat:
                    lat = profile.location_lat
                if not lng:
                    lng = profile.location_lng
                # Get donor's blood group for compatibility filtering
                donor_blood_group = profile.blood_group

        if not lat or not lng:
            return error_response(
                message='Location required. Please provide lat/lng or update your profile.',
                errors={'lat': 'Required', 'lng': 'Required'}
            )

        donor_lat = float(lat)
        donor_lng = float(lng)

        # FIXED: Get all active pending requests (multiple donors can now pledge)
        # Removed one-donor restriction - requests show even if they have pledges
        queryset = BloodRequest.objects.filter(
            is_active=True,
            status='pending',
            expires_at__gt=timezone.now()  # Only non-expired requests
        )

        # Exclude user's own requests
        if request.user and request.user.is_authenticated:
            queryset = queryset.exclude(requested_by=request.user)

        # CRITICAL FIX: Filter by blood compatibility if donor's blood group is known
        if donor_blood_group and blood_type is None:
            # Get compatible blood groups for this donor
            compatible_groups = get_compatible_blood_groups(donor_blood_group)
            queryset = queryset.filter(blood_group__in=compatible_groups)

        # Explicit blood type filter overrides compatibility
        if blood_type:
            queryset = queryset.filter(blood_group=blood_type)

        # CRITICAL FIX: Calculate distances and filter by radius
        # Distance = DONOR_LOCATION <-> REQUEST_LOCATION (not self)
        requests_data = []
        for req in queryset:
            # Skip if request doesn't have location
            if not req.location_lat or not req.location_lng:
                continue

            # CRITICAL: Calculate distance from DONOR to REQUEST location
            distance = haversine_distance(
                donor_lat, donor_lng,  # Donor's location
                req.location_lat, req.location_lng  # Request (patient) location
            )

            # Only include requests within radius
            if distance <= radius:
                request_dict = PublicBloodRequestSerializer(req).data
                request_dict['distance_km'] = round(distance, 1)
                requests_data.append(request_dict)

        # Sort by distance (nearest first) then by urgency
        requests_data.sort(key=lambda x: (x['distance_km'], x.get('urgency_level', 'normal')))

        return success_response(
            message=f'Found {len(requests_data)} nearby blood requests.',
            data={
                'requests': requests_data,
                'count': len(requests_data)
            }
        )

    except Exception as e:
        logger.error(f"Error fetching nearby blood requests: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch nearby blood requests.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


def check_donor_eligibility(user, exclude_request_id=None):
    """
    Check if donor is eligible to pledge based on recent completed donations.
    In the new flow, donors can pledge to multiple requests - patients decide which to accept.

    Returns a tuple: (is_eligible, message, cooldown_days_remaining)
    """
    # Cooldown period after completing a donation: 56 days (8 weeks)
    COOLDOWN_DAYS = 56

    try:
        from django.utils import timezone

        # Check for recent completed pledges (donations that were completed)
        cooldown_cutoff = timezone.now() - timedelta(days=COOLDOWN_DAYS)
        recent_completed_pledge = DonorResponse.objects.filter(
            donor=user,
            status='completed',
            completed_at__gte=cooldown_cutoff
        ).order_by('-completed_at').first()

        if recent_completed_pledge:
            days_since_completion = (timezone.now() - recent_completed_pledge.completed_at).days
            days_remaining = COOLDOWN_DAYS - days_since_completion
            return (
                False,
                f'You completed a donation {days_since_completion} days ago. '
                f'You must wait {days_remaining} more days before pledging again (56-day cooldown).',
                days_remaining
            )

        # Also check Donation model for manually recorded donations
        from donations.models import Donation
        cutoff_date = timezone.now().date() - timedelta(days=COOLDOWN_DAYS)
        recent_donations = Donation.objects.filter(
            donor=user,
            donation_date__gte=cutoff_date
        ).order_by('-donation_date')

        if recent_donations.exists():
            last_donation = recent_donations.first()
            days_since_donation = (timezone.now().date() - last_donation.donation_date).days
            days_remaining = COOLDOWN_DAYS - days_since_donation
            return (
                False,
                f'You donated blood {days_since_donation} days ago. '
                f'You must wait {days_remaining} more days before pledging again (56-day cooldown).',
                days_remaining
            )

        return True, None, 0
    except Exception as e:
        logger.error(f"Error checking donor eligibility: {str(e)}", exc_info=True)
        # If eligibility check fails, allow pledge (fail open)
        return True, None, 0


# Pledge/Donor Response Views

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_pledge(request, request_id):
    """
    Create a pledge for a blood request.

    POST /api/blood-requests/{request_id}/pledge/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "units_pledged": 1,
        "preferred_date": "2024-06-08",
        "note": "I can donate in the morning"
    }

    Response (201 Created):
    {
        "success": true,
        "message": "Pledge created successfully",
        "pledge": {...}
    }
    """
    try:
        logger.info(f"🤝 Pledge request START - request_id: {request_id}, user: {request.user.email}, body: {request.data}")

        # Get the blood request
        blood_request = BloodRequest.objects.get(id=request_id, is_active=True)
        logger.info(f"✅ Blood request found: {blood_request.id} - {blood_request.patient_name}")

        # Check if user has already pledged to THIS request (allow multiple requests, but not same request twice)
        user_existing_pledge = DonorResponse.objects.filter(
            blood_request=blood_request,
            donor=request.user,
            status='pledged'
        ).first()

        if user_existing_pledge:
            logger.info(f"❌ User already pledged to this request: {user_existing_pledge.id}")
            return error_response(
                message='You have already pledged to this request.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Check if donor is in cooldown period after completing a donation (56 days)
        from datetime import timedelta
        from django.utils import timezone

        cooldown_period = timezone.now() - timedelta(days=56)
        recent_completed_donation = DonorResponse.objects.filter(
            donor=request.user,
            status='completed',
            completed_at__gte=cooldown_period
        ).order_by('-completed_at').first()

        if recent_completed_donation:
            # Calculate days remaining in cooldown
            days_since_donation = (timezone.now() - recent_completed_donation.completed_at).days
            days_remaining = 56 - days_since_donation

            logger.info(f"❌ User in cooldown period: {days_since_donation} days since last donation, {days_remaining} days remaining")
            return error_response(
                message=f'You must wait {days_remaining} more days before pledging again (56-day cooldown after donation).',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Validate pledge data
        pledge_serializer = DonorResponseCreateSerializer(data=request.data)
        if not pledge_serializer.is_valid():
            logger.error(f"❌ Validation failed: {pledge_serializer.errors}")
            return error_response(
                message='Invalid pledge data.',
                errors=pledge_serializer.errors
            )

        # Ensure donor has a profile (create if missing)
        from account.models import UserProfile
        donor_profile, created = UserProfile.objects.get_or_create(
            user=request.user,
            defaults={
                'blood_group': blood_request.blood_group,  # Set blood group from request
                'city': 'Unknown',  # Default value
            }
        )
        if created:
            logger.info(f"✅ Created donor profile for {request.user.email}")

        # Create pledge with PLEDGED status
        pledge = DonorResponse.objects.create(
            blood_request=blood_request,
            donor=request.user,
            units_pledged=pledge_serializer.validated_data.get('units_pledged', 1),
            preferred_date=pledge_serializer.validated_data.get('preferred_date'),
            note=pledge_serializer.validated_data.get('note', ''),
            status='pledged'
        )
        logger.info(f"✅ Pledge created: {pledge.id}")

        # Update blood request progress
        blood_request.units_pledged += pledge.units_pledged
        blood_request.responders_count += 1
        blood_request.save()
        logger.info(f"✅ Blood request updated: units_pledged={blood_request.units_pledged}, responders={blood_request.responders_count}")

        # Create notification for the patient
        if blood_request.requested_by:
            try:
                from notifications.views import send_push_notification
                send_push_notification(
                    user=blood_request.requested_by,
                    title='New Pledge Received! 🩸',
                    message=f'{request.user.full_name or request.user.email} has pledged to donate {blood_request.blood_group} blood for {blood_request.patient_name}.',
                    notif_type='new_pledge',
                    data={
                        'request_id': str(blood_request.id),
                        'pledge_id': str(pledge.id),
                    },
                    send_push=True
                )
                logger.info(f"✅ Notification sent to patient: {blood_request.requested_by.email}")
            except Exception as e:
                logger.warning(f"⚠️  Failed to send notification: {str(e)}")

        logger.info(f"🎉 Pledge creation SUCCESS")
        return success_response(
            message='Pledge created successfully! The patient will review your pledge shortly.',
            data={
                'pledge': DonorResponseSerializer(pledge).data,
                'request_fulfilled': blood_request.status == 'fulfilled',
                'units_pledged': blood_request.units_pledged,
                'units_needed': blood_request.units_needed,
            },
            status_code=status.HTTP_201_CREATED
        )

    except BloodRequest.DoesNotExist:
        logger.error(f"❌ Blood request not found: {request_id}")
        return error_response(
            message='Blood request not found or inactive.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"❌ Error creating pledge: {str(e)}", exc_info=True)
        logger.error(f"❌ Exception type: {type(e).__name__}")
        return error_response(
            message='An error occurred while creating the pledge.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def get_request_pledges(request, request_id):
    """
    Get all pledges for a blood request.

    GET /api/blood-requests/{request_id}/pledges/

    Response (200 OK):
    {
        "success": true,
        "message": "Pledges retrieved successfully",
        "pledges": [...],
        "count": 3
    }
    """
    try:
        # Allow fetching pledges for both active and completed requests
        blood_request = BloodRequest.objects.get(id=request_id)
    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )

    try:
        pledges = DonorResponse.objects.filter(
            blood_request=blood_request,
            status__in=['pledged', 'completed']
        ).order_by('-created_at')

        serializer = DonorResponseSerializer(pledges, many=True)

        return success_response(
            message='Pledges retrieved successfully.',
            data={
                'pledges': serializer.data,
                'count': pledges.count()
            }
        )

    except Exception as e:
        logger.error(f"Error fetching pledges: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch pledges.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_pledge(request, pledge_id):
    """
    Cancel a pledge.

    POST /api/blood-requests/pledges/{pledge_id}/cancel/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Pledge cancelled successfully"
    }
    """
    try:
        pledge = DonorResponse.objects.get(id=pledge_id, donor=request.user, status='pending')
    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found or already processed.',
            status_code=status.HTTP_404_NOT_FOUND
        )

    try:
        # Update pledge status
        pledge.status = 'cancelled'
        pledge.save()

        # Update blood request progress
        blood_request = pledge.blood_request
        blood_request.units_pledged -= pledge.units_pledged
        blood_request.responders_count -= 1
        blood_request.save()

        logger.info(f"Pledge cancelled: {pledge_id} by {request.user.email}")

        return success_response(
            message='Pledge cancelled successfully.'
        )

    except Exception as e:
        logger.error(f"Error cancelling pledge: {str(e)}", exc_info=True)
        return error_response(
            message='An error occurred while cancelling the pledge.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def get_request_progress(request, request_id):
    """
    Get progress information for a blood request.

    GET /api/blood-requests/{request_id}/progress/

    Response (200 OK):
    {
        "success": true,
        "message": "Progress retrieved successfully",
        "data": {
            "units_needed": 3,
            "units_pledged": 2,
            "units_received": 0,
            "units_remaining": 1,
            "responders_count": 2,
            "pledges": [...]
        }
    }
    """
    try:
        # Allow fetching progress for both active and completed requests
        blood_request = BloodRequest.objects.get(id=request_id)
    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )

    try:
        pledges = DonorResponse.objects.filter(
            blood_request=blood_request,
            status__in=['pledged', 'completed']
        ).order_by('-created_at')

        serializer = DonorResponseSerializer(pledges, many=True)

        return success_response(
            message='Progress retrieved successfully.',
            data={
                'units_needed': blood_request.units_needed,
                'units_pledged': blood_request.units_pledged,
                'units_received': blood_request.units_received,
                'units_remaining': max(0, blood_request.units_needed - blood_request.units_pledged),
                'responders_count': blood_request.responders_count,
                'pledges': serializer.data
            }
        )

    except Exception as e:
        logger.error(f"Error fetching progress: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch progress.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def donor_eligibility_status(request):
    """
    Check donor's current eligibility to pledge/donate.

    GET /api/blood-requests/donor-eligibility/

    Response (200 OK):
    {
        "success": true,
        "data": {
            "is_eligible": true,
            "cooldown_days_remaining": 0,
            "message": "You are eligible to donate",
            "last_donation_date": null,
            "last_pledge_date": null
        }
    }
    """
    try:
        is_eligible, message, days_remaining = check_donor_eligibility(request.user)

        # Get last donation and pledge dates
        from donations.models import Donation
        last_donation = Donation.objects.filter(
            donor=request.user
        ).order_by('-donation_date').first()

        last_pledge = DonorResponse.objects.filter(
            donor=request.user,
            status__in=['pledged', 'completed']
        ).order_by('-created_at').first()

        return success_response(
            message='Eligibility checked successfully.',
            data={
                'is_eligible': is_eligible,
                'cooldown_days_remaining': days_remaining,
                'message': message if message else 'You are eligible to donate',
                'last_donation_date': last_donation.donation_date.isoformat() if last_donation else None,
                'last_pledge_date': last_pledge.created_at.isoformat() if last_pledge else None,
                'next_eligible_date': (datetime.now().date() + timedelta(days=days_remaining)).isoformat() if days_remaining > 0 else None,
            }
        )

    except Exception as e:
        logger.error(f"Error checking donor eligibility: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to check eligibility.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# Admin Views

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_blood_requests_list(request):
    """
    Get all blood requests for admin dashboard.
    Requires admin/staff privileges.

    GET /api/admin/blood-requests/

    Query Parameters:
    - status: Filter by status (pending, fulfilled, cancelled) - optional
    - urgency_level: Filter by urgency (critical, urgent, normal) - optional
    - blood_group: Filter by blood group - optional
    - page: Page number for pagination (default: 1)
    - page_size: Items per page (default: 20, max: 100)

    Response (200 OK):
    {
        "success": true,
        "message": "Blood requests retrieved",
        "data": {
            "blood_requests": [...],
            "count": 50,
            "total_pages": 3,
            "current_page": 1
        }
    }
    """
    try:
        # Check if user is staff
        if not request.user.is_staff:
            return error_response(
                message='Admin privileges required.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get query parameters for filtering
        status_param = request.query_params.get('status')
        urgency_level = request.query_params.get('urgency_level')
        blood_group = request.query_params.get('blood_group')
        page = int(request.query_params.get('page', 1))
        page_size = min(int(request.query_params.get('page_size', 20)), 100)

        # Build queryset
        queryset = BloodRequest.objects.all().order_by('-created_at')

        # Apply filters
        if status_param:
            queryset = queryset.filter(status=status_param)
        if urgency_level:
            queryset = queryset.filter(urgency_level=urgency_level)
        if blood_group:
            queryset = queryset.filter(blood_group=blood_group)

        # Pagination
        from django.core.paginator import Paginator
        paginator = Paginator(queryset, page_size)

        try:
            blood_requests_page = paginator.page(page)
        except:
            blood_requests_page = paginator.page(1)

        # Serialize data with full details
        requests_data = []
        for req in blood_requests_page:
            requester_info = None
            if req.requested_by:
                requester_info = {
                    'id': str(req.requested_by.id),
                    'email': req.requested_by.email,
                    'full_name': req.requested_by.full_name,
                    'role': req.requested_by.role
                }

            requests_data.append({
                'id': str(req.id),
                'patient_name': req.patient_name,
                'blood_group': req.blood_group,
                'units_needed': req.units_needed,
                'units_pledged': req.units_pledged,
                'units_received': req.units_received,
                'units_remaining': max(0, req.units_needed - req.units_pledged),
                'urgency_level': req.urgency_level,
                'status': req.status,
                'is_active': req.is_active,
                'contact_number': req.contact_number,
                'hospital_name': req.hospital_name,
                'location': req.location,
                'additional_notes': req.additional_notes,
                'responders_count': req.responders_count,
                'requested_by': requester_info,
                'created_at': req.created_at.isoformat(),
                'updated_at': req.updated_at.isoformat(),
            })

        return success_response(
            message='Blood requests retrieved successfully.',
            data={
                'blood_requests': requests_data,
                'count': queryset.count(),
                'total_pages': paginator.num_pages,
                'current_page': blood_requests_page.number,
                'page_size': page_size,
                'has_next': blood_requests_page.has_next(),
                'has_previous': blood_requests_page.has_previous(),
            }
        )

    except Exception as e:
        logger.error(f"Error fetching admin blood requests: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch blood requests.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_blood_request_detail(request, request_id):
    """
    Get detailed information about a specific blood request for admin.
    Includes pledges and responder information.

    GET /api/admin/blood-requests/{request_id}/

    Response (200 OK):
    {
        "success": true,
        "message": "Blood request details retrieved",
        "data": {
            "blood_request": {...},
            "pledges": [...]
        }
    }
    """
    try:
        # Check if user is staff
        if not request.user.is_staff:
            return error_response(
                message='Admin privileges required.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        blood_request = BloodRequest.objects.get(id=request_id)

        # Get requester info
        requester_info = None
        if blood_request.requested_by:
            requester_info = {
                'id': str(blood_request.requested_by.id),
                'email': blood_request.requested_by.email,
                'full_name': blood_request.requested_by.full_name,
                'role': blood_request.requested_by.role,
                'phone': blood_request.requested_by.phone_number,
            }

        # Build blood request data
        request_data = {
            'id': str(blood_request.id),
            'patient_name': blood_request.patient_name,
            'blood_group': blood_request.blood_group,
            'units_needed': blood_request.units_needed,
            'units_pledged': blood_request.units_pledged,
            'units_received': blood_request.units_received,
            'units_remaining': max(0, blood_request.units_needed - blood_request.units_pledged),
            'urgency_level': blood_request.urgency_level,
            'status': blood_request.status,
            'is_active': blood_request.is_active,
            'contact_number': blood_request.contact_number,
            'hospital_name': blood_request.hospital_name,
            'location': blood_request.location,
            'additional_notes': blood_request.additional_notes,
            'responders_count': blood_request.responders_count,
            'requested_by': requester_info,
            'created_at': blood_request.created_at.isoformat(),
            'updated_at': blood_request.updated_at.isoformat(),
        }

        # Get pledges for this request
        pledges = DonorResponse.objects.filter(
            blood_request=blood_request
        ).order_by('-created_at')

        pledges_data = []
        for pledge in pledges:
            donor_info = None
            if pledge.donor:
                donor_info = {
                    'id': str(pledge.donor.id),
                    'email': pledge.donor.email,
                    'full_name': pledge.donor.full_name,
                    'phone': pledge.donor.phone_number,
                    'blood_group': pledge.donor.profile.blood_group if pledge.donor.profile else None,
                }

            pledges_data.append({
                'id': str(pledge.id),
                'donor': donor_info,
                'units_pledged': pledge.units_pledged,
                'preferred_date': pledge.preferred_date.isoformat() if pledge.preferred_date else None,
                'note': pledge.note,
                'status': pledge.status,
                'created_at': pledge.created_at.isoformat(),
                'completed_at': pledge.completed_at.isoformat() if pledge.completed_at else None,
            })

        return success_response(
            message='Blood request details retrieved successfully.',
            data={
                'blood_request': request_data,
                'pledges': pledges_data,
                'pledges_count': pledges.count(),
            }
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error fetching admin blood request detail: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch blood request details.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# ============================================================================
# Patient Pledge Management Views
# ============================================================================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_pledged_donors_for_patient(request, request_id):
    """
    Get list of pledged donors for a blood request (patient only).
    Includes full donor details for patient review.

    GET /api/blood-requests/{request_id}/pledges/patient/

    Response (200 OK):
    {
        "success": true,
        "message": "Pledged donors retrieved",
        "pledges": [...],
        "summary": {
            "total": 10,
            "pending": 5,
            "accepted": 3,
            "rejected": 2
        }
    }
    """
    try:
        blood_request = BloodRequest.objects.get(id=request_id)

        # Verify user is the request creator
        if blood_request.requested_by != request.user:
            return error_response(
                message='You are not authorized to view pledges for this request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get all pledges with donor details
        pledges = DonorResponse.objects.filter(
            blood_request=blood_request
        ).select_related('donor', 'donor__profile').order_by('-created_at')

        # Calculate summary
        summary = {
            'total': pledges.count(),
            'pending': pledges.filter(status='pending').count(),
            'accepted': pledges.filter(status='accepted').count(),
            'rejected': pledges.filter(status='rejected').count(),
            'donated': pledges.filter(status='completed').count(),
        }

        serializer = DonorResponseSerializer(pledges, many=True)

        return success_response(
            message='Pledged donors retrieved successfully.',
            data={
                'pledges': serializer.data,
                'summary': summary,
                'blood_request': {
                    'id': str(blood_request.id),
                    'blood_group': blood_request.blood_group,
                    'units_needed': blood_request.units_needed,
                    'units_pledged': blood_request.units_pledged,
                    'units_received': blood_request.units_received,
                }
            }
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error fetching pledged donors: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch pledged donors.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def accept_pledge(request, request_id, pledge_id):
    """
    Accept a donor's pledge as PRIMARY donor (patient only).

    POST /api/blood-requests/{request_id}/pledges/{pledge_id}/accept/

    This moves pledge from PLEDGED -> CONFIRMED and creates a chat conversation.

    Request Body:
    {
        "patient_note": "Please call me at..."
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Pledge confirmed and chat created",
        "pledge": {...},
        "conversation_id": "uuid"
    }
    """
    try:
        from django.db import transaction
        from django.utils import timezone

        logger.info(f"accept_pledge START: request_id={request_id}, pledge_id={pledge_id}, user={request.user.email}")

        with transaction.atomic():
            logger.info("Step 1: Getting blood_request and pledge")
            blood_request = BloodRequest.objects.select_for_update().get(id=request_id)
            pledge = DonorResponse.objects.get(id=pledge_id, blood_request=blood_request)
            logger.info(f"Step 1 DONE: blood_request={blood_request.id}, pledge status={pledge.status}")

            # Verify user is the request creator
            logger.info("Step 2: Checking authorization")
            if blood_request.requested_by != request.user:
                logger.warning(f"Authorization failed: {blood_request.requested_by.email} != {request.user.email}")
                return error_response(
                    message='You are not authorized to accept pledges for this request.',
                    status_code=status.HTTP_403_FORBIDDEN
                )
            logger.info("Step 2 DONE: Authorized")

            # Check if there's already an active donor
            logger.info("Step 3: Checking for active donor")
            if blood_request.active_donor_pledge_id:
                logger.warning(f"Active donor already exists: {blood_request.active_donor_pledge_id}")
                return error_response(
                    'This request already has an active donor.',
                    status_code=status.HTTP_409_CONFLICT
                )
            logger.info("Step 3 DONE: No active donor")

            # Check if pledge can be accepted
            logger.info("Step 4: Checking pledge status")
            if pledge.status != 'pledged':
                logger.warning(f"Pledge status is not pledged: {pledge.status}")
                return error_response(
                    message=f'Cannot accept pledge with status "{pledge.status}".',
                    status_code=status.HTTP_400_BAD_REQUEST
                )
            logger.info("Step 4 DONE: Pledge status is pledged")

            # Get patient note
            logger.info("Step 5: Getting patient note")
            serializer = AcceptPledgeSerializer(data=request.data)
            if serializer.is_valid():
                patient_note = serializer.validated_data.get('patient_note', '')
                logger.info(f"Step 5 DONE: Patient note={patient_note}")
            else:
                logger.error(f"Step 5 FAILED: Serializer errors={serializer.errors}")
                return error_response(
                    message='Invalid data.',
                    errors=serializer.errors
                )

            # Update pledge to CONFIRMED status
            logger.info("Step 6: Updating pledge to confirmed")
            pledge.status = 'confirmed'
            pledge.confirmed_at = timezone.now()
            pledge.patient_note = patient_note
            pledge.save()
            logger.info("Step 6 DONE: Pledge updated")

            # Set as active donor on blood request
            logger.info("Step 7: Setting active donor on blood request")
            blood_request.active_donor_pledge_id = pledge.id
            blood_request.responders_count = F('responders_count') + 1
            blood_request.save(update_fields=['active_donor_pledge_id', 'responders_count'])
            logger.info("Step 7 DONE: Blood request updated")

            logger.info(f"SUCCESS: Pledge {pledge_id} confirmed by {request.user.email}")

            # AUTO-CREATE OR UPDATE CONVERSATION
            try:
                from chat.models import Conversation
                from django.db import IntegrityError

                # Check if conversation already exists between these two users
                conversation = Conversation.objects.filter(
                    patient=request.user,
                    donor=pledge.donor,
                    is_active=True
                ).first()

                if conversation:
                    # Update existing conversation with new blood_request/pledge context
                    conversation.blood_request = blood_request
                    conversation.pledge = pledge
                    conversation.save()
                    conversation_id = str(conversation.id)
                    logger.info(f"Existing conversation reused for pledge {pledge_id}")
                else:
                    # Create new conversation
                    conversation = Conversation.objects.create(
                        blood_request=blood_request,
                        pledge=pledge,
                        patient=request.user,
                        donor=pledge.donor
                    )
                    conversation_id = str(conversation.id)
                    logger.info(f"New conversation created for pledge {pledge_id}")
            except ImportError:
                conversation_id = None
                logger.warning("Chat app not available")

            # Create notification for donor
            if pledge.donor:
                try:
                    from notifications.models import Notification
                    Notification.objects.create(
                        user=pledge.donor,
                        title='Your Pledge Has Been Confirmed!',
                        message=f'{request.user.full_name or request.user.email} has confirmed your pledge to donate {blood_request.blood_group} blood. Chat is now open.',
                        type='pledge_confirmed',
                        related_request_id=str(blood_request.id),
                        related_pledge_id=str(pledge.id),
                        related_conversation_id=conversation_id
                    )
                    logger.info(f"Notification sent to donor {pledge.donor.email}")
                except Exception as e:
                    logger.warning(f"Failed to create notification: {e}")

            response_data = {'pledge': DonorResponseSerializer(pledge).data}
            if conversation_id:
                response_data['conversation_id'] = conversation_id

            return success_response(
                message='Pledge confirmed and chat created.',
                data=response_data
            )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error accepting pledge: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to accept pledge.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def reject_pledge(request, request_id, pledge_id):
    """
    Reject a donor's pledge (patient only).

    POST /api/blood-requests/{request_id}/pledges/{pledge_id}/reject/

    Request Body:
    {
        "reason": "Optional rejection reason (internal)"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Pledge rejected"
    }
    """
    try:
        from django.db import transaction
        from django.utils import timezone

        with transaction.atomic():
            blood_request = BloodRequest.objects.select_for_update().get(id=request_id)
            pledge = DonorResponse.objects.get(id=pledge_id, blood_request=blood_request)

            # Verify user is the request creator
            if blood_request.requested_by != request.user:
                return error_response(
                    message='You are not authorized to reject pledges for this request.',
                    status_code=status.HTTP_403_FORBIDDEN
                )

            # Check if pledge can be rejected (only pledged or confirmed pledges)
            if pledge.status not in ['pledged', 'confirmed']:
                return error_response(
                    message=f'Cannot reject pledge with status "{pledge.status}".',
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            # Get rejection reason
            serializer = RejectPledgeSerializer(data=request.data)
            if serializer.is_valid():
                rejection_reason = serializer.validated_data.get('reason', '')
            else:
                return error_response(
                    message='Invalid data.',
                    errors=serializer.errors
                )

            # Store previous status before updating
            previous_status = pledge.status
            was_confirmed = previous_status == 'confirmed'

            # Update pledge
            pledge.status = 'rejected'
            pledge.rejected_at = timezone.now()
            pledge.rejection_reason = rejection_reason
            pledge.save()

            # Update blood request progress if was confirmed
            if was_confirmed:
                blood_request.units_pledged -= pledge.units_pledged
                blood_request.responders_count = F('responders_count') - 1

                # Clear active donor if this was the confirmed donor
                if blood_request.active_donor_pledge_id == pledge.id:
                    blood_request.active_donor_pledge_id = None

                blood_request.save(update_fields=['units_pledged', 'responders_count', 'active_donor_pledge_id'])

            logger.info(f"Pledge {pledge_id} rejected by {request.user.email}")

            # Create notification for donor (generic, without specific reason)
            if pledge.donor:
                try:
                    from notifications.models import Notification
                    Notification.objects.create(
                        user=pledge.donor,
                        title='Pledge Update',
                        message=f'The patient has reviewed your pledge for {blood_request.blood_group} blood. Thank you for your willingness to help.',
                        type='pledge_rejected',
                        related_request_id=str(blood_request.id),
                    )
                    logger.info(f"Notification sent to donor {pledge.donor.email}")
                except Exception as e:
                    logger.warning(f"Failed to create notification: {e}")

            return success_response(
                message='Pledge rejected successfully.',
                data={'pledge': DonorResponsePublicSerializer(pledge).data}
            )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error rejecting pledge: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to reject pledge.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
        return error_response(
            message='Failed to reject pledge.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def accept_pledges_batch(request, request_id):
    """
    Accept multiple pledges at once (patient only).

    POST /api/blood-requests/{request_id}/pledges/accept-batch/

    Request Body:
    {
        "pledge_ids": ["uuid1", "uuid2", "uuid3"],
        "patient_note": "Thank you all for helping..."
    }

    Response (200 OK):
    {
        "success": true,
        "message": "X pledges accepted",
        "accepted_count": 3,
        "pledges": [...]
    }
    """
    try:
        from django.utils import timezone

        blood_request = BloodRequest.objects.get(id=request_id)

        # Verify user is the request creator
        if blood_request.requested_by != request.user:
            return error_response(
                message='You are not authorized to accept pledges for this request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get pledge IDs and note
        serializer = BatchAcceptPledgesSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response(
                message='Invalid data.',
                errors=serializer.errors
            )

        pledge_ids = serializer.validated_data['pledge_ids']
        patient_note = serializer.validated_data.get('patient_note', '')

        # Get pledges that are pending
        pledges = DonorResponse.objects.filter(
            id__in=pledge_ids,
            blood_request=blood_request,
            status='pending'
        )

        accepted_pledges = []
        for pledge in pledges:
            pledge.status = 'accepted'
            pledge.accepted_at = timezone.now()
            if patient_note:
                pledge.patient_note = patient_note
            pledge.save()
            accepted_pledges.append(pledge)

            # Create notification for donor
            if pledge.donor:
                try:
                    from notifications.models import Notification
                    Notification.objects.create(
                        user=pledge.donor,
                        title='Your Pledge Has Been Accepted!',
                        message=f'{request.user.full_name or request.user.email} has accepted your pledge to donate {blood_request.blood_group} blood.',
                        type='pledge_accepted',
                        related_request_id=str(blood_request.id),
                        related_pledge_id=str(pledge.id)
                    )
                except Exception as e:
                    logger.warning(f"Failed to create notification: {e}")

        logger.info(f"Batch accepted {len(accepted_pledges)} pledges by {request.user.email}")

        return success_response(
            message=f'{len(accepted_pledges)} pledge(s) accepted successfully.',
            data={
                'accepted_count': len(accepted_pledges),
                'pledges': DonorResponsePublicSerializer(accepted_pledges, many=True).data
            }
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error in batch accept: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to accept pledges.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def confirm_donation(request, request_id, pledge_id):
    """
    Confirm that donation has been received (patient only).

    POST /api/blood-requests/{request_id}/pledges/{pledge_id}/confirm-donation/

    Request Body:
    {
        "units_received": 1,
        "patient_note": "Thank you so much!"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Donation confirmed",
        "pledge": {...},
        "blood_request_status": "partial"
    }
    """
    try:
        from django.utils import timezone

        blood_request = BloodRequest.objects.get(id=request_id)
        pledge = DonorResponse.objects.get(id=pledge_id, blood_request=blood_request)

        # Verify user is the request creator
        if blood_request.requested_by != request.user:
            return error_response(
                message='You are not authorized to confirm donations for this request.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Check if pledge can be marked as donated
        # FIXED: Allow both 'pledged' and 'accepted' status
        if pledge.status not in ['pledged', 'accepted']:
            return error_response(
                message=f'Cannot confirm donation for pledge with status "{pledge.status}".',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Get donation details
        serializer = ConfirmDonationSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response(
                message='Invalid data.',
                errors=serializer.errors
            )

        units_received = serializer.validated_data['units_received']
        patient_note = serializer.validated_data.get('patient_note', '')

        # Validate units
        if units_received > pledge.units_pledged:
            return error_response(
                message='Units received cannot exceed units pledged.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Update pledge
        pledge.status = 'completed'
        pledge.completed_at = timezone.now()
        pledge.units_received = units_received
        if patient_note:
            pledge.patient_note = patient_note
        pledge.save()

        # ✅ FIXED: Create donation record
        try:
            from donations.models import Donation
            from blood_types.models import BloodType

            # Get or find blood type
            blood_type = None
            try:
                blood_type = BloodType.objects.filter(
                    blood_group=blood_request.blood_group
                ).first()
            except:
                pass

            # Create donation record
            donation = Donation.objects.create(
                donor=pledge.donor,
                blood_request=blood_request,
                blood_type=blood_type,
                units=units_received,
                donation_date=timezone.now().date(),
                donation_center=blood_request.hospital_name or 'Hospital',
                donation_center_address=blood_request.location or '',
                acknowledged_by_patient=True,
                acknowledged_at=timezone.now(),
            )

            logger.info(f"Donation record created: {donation.id} for pledge {pledge_id}")

            # Generate certificate number
            try:
                donation.generate_certificate_number()
                donation.certificate_issued = True
                donation.save()
                logger.info(f"Certificate generated: {donation.certificate_number}")
            except Exception as cert_error:
                logger.warning(f"Failed to generate certificate: {cert_error}")

        except ImportError:
            logger.warning("Donations app not available - skipping donation record creation")
        except Exception as donation_error:
            logger.error(f"Failed to create donation record: {donation_error}")

        # Update blood request
        blood_request.units_received += units_received

        # Update blood request status
        if blood_request.units_received >= blood_request.units_needed:
            blood_request.status = 'fulfilled'
            blood_request.is_active = False
        elif blood_request.units_received > 0:
            blood_request.status = 'partial'

        blood_request.save()

        logger.info(f"Donation confirmed for pledge {pledge_id} by {request.user.email}")

        # Create notification for donor
        if pledge.donor:
            try:
                from notifications.models import Notification
                Notification.objects.create(
                    user=pledge.donor,
                    title='Thank You for Donating!',
                    message=f'Your donation has been received. You have helped save a life! Thank you for your generous contribution.',
                    type='donation_confirmed',
                    related_request_id=str(blood_request.id),
                    related_pledge_id=str(pledge.id)
                )
                logger.info(f"Notification sent to donor {pledge.donor.email}")
            except ImportError:
                logger.info("Notifications app not available")

        return success_response(
            message='Donation confirmed successfully. Thank you for helping save lives!',
            data={
                'pledge': DonorResponseSerializer(pledge).data,
                'blood_request_status': blood_request.status,
                'units_received': blood_request.units_received,
                'units_needed': blood_request.units_needed,
            }
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error confirming donation: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to confirm donation.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def complete_pledge_donation(request, request_id, pledge_id):
    """
    Complete donation from a pledge (patient only).

    POST /api/blood-requests/{request_id}/pledges/{pledge_id}/complete/

    Simplified endpoint for patients to confirm blood donation was received.
    This creates a donation record and marks the pledge as donated.

    Request Body:
    {
        "units_donated": 1,
        "patient_note": "Thank you so much!"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Donation completed successfully",
        "pledge": {...},
        "donation": {...},
        "blood_request_status": "partial"
    }
    """
    # Variables to store data for notification after transaction
    pledge_donor = None
    notification_data = {}

    try:
        from django.db import transaction
        from django.utils import timezone

        with transaction.atomic():
            blood_request = BloodRequest.objects.select_for_update().get(id=request_id)
            pledge = DonorResponse.objects.select_for_update().get(
                id=pledge_id,
                blood_request=blood_request
            )

            # Verify user is the request creator
            if blood_request.requested_by != request.user:
                return error_response(
                    message='You are not authorized to complete donations for this request.',
                    status_code=status.HTTP_403_FORBIDDEN
                )

            # Check if pledge can be marked as donated
            if pledge.status not in ['pledged', 'accepted', 'confirmed']:
                return error_response(
                    message=f'Cannot complete donation for pledge with status "{pledge.status}".',
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            # Get donation details
            units_donated = request.data.get('units_donated', pledge.units_pledged)
            patient_note = request.data.get('patient_note', '')

            try:
                units_donated = int(units_donated)
            except (ValueError, TypeError):
                units_donated = pledge.units_pledged

            # Validate units
            if units_donated > pledge.units_pledged:
                return error_response(
                    message='Units donated cannot exceed units pledged.',
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            # Update pledge
            pledge.status = 'completed'
            pledge.completed_at = timezone.now()
            pledge.units_received = units_donated
            if patient_note:
                pledge.patient_note = patient_note
            pledge.save()

            # Store donor for notification (after transaction)
            pledge_donor = pledge.donor
            notification_data = {
                'units_donated': units_donated,
                'blood_request_id': str(blood_request.id),
                'pledge_id': str(pledge.id),
            }

            # Create donation record
            donation_data = None
            try:
                from donations.models import Donation
                from blood_types.models import BloodType

                # Get blood type
                blood_type = None
                try:
                    blood_type = BloodType.objects.filter(
                        blood_group=blood_request.blood_group
                    ).first()
                except:
                    pass

                # Create donation record
                donation = Donation.objects.create(
                    donor=pledge.donor,
                    blood_request=blood_request,
                    blood_type=blood_type,
                    units=units_donated,
                    donation_date=timezone.now().date(),
                    donation_center=blood_request.hospital_name or 'Hospital',
                    donation_center_address=blood_request.location or '',
                    acknowledged_by_patient=True,
                    acknowledged_at=timezone.now(),
                )

                logger.info(f"Donation record created: {donation.id} for pledge {pledge_id}")

                # Generate certificate number
                try:
                    donation.generate_certificate_number()
                    donation.certificate_issued = True
                    donation.save()
                    logger.info(f"Certificate generated: {donation.certificate_number}")
                except Exception as cert_error:
                    logger.warning(f"Failed to generate certificate: {cert_error}")

                donation_data = {
                    'id': str(donation.id),
                    'certificate_number': donation.certificate_number,
                    'units': donation.units,
                    'donation_date': donation.donation_date.isoformat(),
                }

            except ImportError:
                logger.warning("Donations app not available")
            except Exception as donation_error:
                logger.error(f"Failed to create donation record: {donation_error}")

            # Update blood request
            blood_request.units_received += units_donated

            # Update blood request status
            if blood_request.units_received >= blood_request.units_needed:
                blood_request.status = 'fulfilled'
                blood_request.is_active = False
            elif blood_request.units_received > 0:
                blood_request.status = 'partial'

            blood_request.save()

            logger.info(f"Pledge donation completed: {pledge_id} by {request.user.email}")

            response_data = {
                'pledge': DonorResponseSerializer(pledge).data,
                'blood_request_status': blood_request.status,
                'units_received': blood_request.units_received,
                'units_needed': blood_request.units_needed,
            }

            if donation_data:
                response_data['donation'] = donation_data

            return success_response(
                message='Donation completed successfully! Thank you for helping save lives.',
                data=response_data
            )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error completing pledge donation: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to complete donation.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    # Send notification AFTER the atomic transaction completes
    # This ensures notification failures don't break the transaction
    if pledge_donor and notification_data.isNotEmpty:
        try:
            from notifications.models import Notification
            Notification.objects.create(
                user=pledge_donor,
                title='Thank You for Donating!',
                message=f'Your donation of {notification_data["units_donated"]} unit(s) has been confirmed. You have helped save a life!',
                type='donation_confirmed',
                related_request_id=notification_data['blood_request_id'],
                related_pledge_id=notification_data['pledge_id']
            )
            logger.info(f"Notification sent to donor {pledge_donor.email}")
        except Exception as e:
            logger.warning(f"Failed to create notification: {e}")


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_my_pledges(request):
    """
    Get current donor's pledges with status tracking.

    GET /api/blood-requests/my-pledges/

    Query Parameters:
    - status: Filter by status (optional)

    Response (200 OK):
    {
        "success": true,
        "pledges": [...],
        "summary": {
            "total": 5,
            "pending": 2,
            "accepted": 1,
            "rejected": 1,
            "donated": 1
        }
    }
    """
    try:
        # Get filter
        status_filter = request.query_params.get('status')

        # Build queryset
        queryset = DonorResponse.objects.filter(
            donor=request.user
        ).select_related('blood_request').order_by('-created_at')

        if status_filter:
            queryset = queryset.filter(status=status_filter)

        # Calculate summary
        all_pledges = DonorResponse.objects.filter(donor=request.user)
        summary = {
            'total': all_pledges.count(),
            'pending': all_pledges.filter(status='pending').count(),
            'accepted': all_pledges.filter(status='accepted').count(),
            'rejected': all_pledges.filter(status='rejected').count(),
            'donated': all_pledges.filter(status='completed').count(),
            'cancelled': all_pledges.filter(status='cancelled').count(),
        }

        serializer = DonorResponsePublicSerializer(queryset, many=True)

        return success_response(
            message='Your pledges retrieved successfully.',
            data={
                'pledges': serializer.data,
                'summary': summary
            }
        )

    except Exception as e:
        logger.error(f"Error fetching my pledges: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch your pledges.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# ============================================================================
# Phase 5: Donation Status Tracking Views
# ============================================================================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_pledge_status(request, pledge_id):
    """
    Update donation status (donor only).

    POST /api/blood-requests/pledges/{pledge_id}/status/

    Phase 5: Track donation progress with real-time updates.

    Allowed transitions:
    - confirmed -> on_the_way
    - on_the_way -> arrived
    - arrived -> ready
    - ready -> completed (marked by patient via confirm_donation)

    Request Body:
    {
        "status": "on_the_way"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Status updated to on_the_way",
        "pledge": {...}
    }
    """
    try:
        from django.utils import timezone

        pledge = DonorResponse.objects.get(id=pledge_id, donor=request.user)
        blood_request = pledge.blood_request

        # Validate status
        new_status = request.data.get('status')
        valid_transitions = {
            'confirmed': ['on_the_way'],
            'on_the_way': ['arrived'],
            'arrived': ['ready'],
            'ready': [],  # Can't self-complete, patient confirms
        }

        if new_status not in valid_transitions.get(pledge.status, []):
            return error_response(
                message=f'Invalid status transition from {pledge.status} to {new_status}.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Update status and timestamp
        pledge.status = new_status
        if new_status == 'on_the_way':
            pledge.on_the_way_at = timezone.now()
        elif new_status == 'arrived':
            pledge.arrived_at = timezone.now()
        elif new_status == 'ready':
            pledge.ready_at = timezone.now()
        pledge.save()

        logger.info(f"Pledge {pledge_id} status updated to {new_status} by {request.user.email}")

        # Notify patient
        if blood_request.requested_by:
            try:
                from notifications.models import Notification
                status_messages = {
                    'on_the_way': f'{request.user.full_name or request.user.email} is on the way to donate!',
                    'arrived': f'{request.user.full_name or request.user.email} has arrived at the location.',
                    'ready': f'{request.user.full_name or request.user.email} is ready for donation.',
                }

                Notification.objects.create(
                    user=blood_request.requested_by,
                    title='Donation Status Update',
                    message=status_messages.get(new_status, 'Status updated'),
                    type='donation_status_update',
                    related_request_id=str(blood_request.id),
                    related_pledge_id=str(pledge.id)
                )
            except Exception as e:
                logger.warning(f"Failed to create notification: {e}")

        return success_response(
            message=f'Status updated to {new_status}.',
            data={'pledge': DonorResponseSerializer(pledge).data}
        )

    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error updating pledge status: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to update pledge status.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# ============================================================================
# Phase 6: No-Show Reporting Views
# ============================================================================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def report_no_show(request, request_id, pledge_id):
    """
    Report a donor as no-show (patient only).

    POST /api/blood-requests/{request_id}/pledges/{pledge_id}/no-show/

    Phase 6: Report no-show with automatic penalties and backup activation.

    Effects:
    1. Marks pledge as no_show
    2. Decreases donor's reliability score (-20 points)
    3. Notifies donor of no-show report
    4. Activates next best backup donor

    Response (200 OK):
    {
        "success": true,
        "message": "No-show reported. Donor's reliability score decreased.",
        "backup_activated": true
    }
    """
    try:
        from django.db import transaction
        from django.utils import timezone

        with transaction.atomic():
            # Lock the blood request to prevent race conditions
            blood_request = BloodRequest.objects.select_for_update().get(id=request_id)
            pledge = DonorResponse.objects.select_for_update().get(
                id=pledge_id,
                blood_request=blood_request
            )

            # Verify user is the request creator
            if blood_request.requested_by != request.user:
                return error_response(
                    message='Only the requester can report no-show.',
                    status_code=status.HTTP_403_FORBIDDEN
                )

            # Check if pledge can be reported as no-show
            if pledge.status not in ['confirmed', 'on_the_way', 'arrived', 'ready']:
                return error_response(
                    message=f'Cannot report status "{pledge.status}" as no-show.',
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            # Mark as no-show
            pledge.status = 'no_show'
            pledge.no_show_reported_at = timezone.now()
            pledge.save()

            # Clear active donor reference
            blood_request.active_donor_pledge_id = None
            blood_request.save()

            # Update donor's reliability score (using service)
            if pledge.donor and pledge.donor.profile:
                from account.services import reliability_service
                reliability_service.update_on_no_show(pledge)

            # Notify donor about no-show report
            if pledge.donor:
                try:
                    from notifications.models import Notification
                    Notification.objects.create(
                        user=pledge.donor,
                        title='No-Show Reported',
                        message=f'You were reported as a no-show for {blood_request.patient_name}\'s blood request. This affects your reliability score.',
                        type='no_show_reported',
                        related_request_id=str(blood_request.id),
                        related_pledge_id=str(pledge.id)
                    )
                    logger.warning(f"No-show reported for donor {pledge.donor.id} by {request.user.email}")
                except Exception as e:
                    logger.warning(f"Failed to create notification: {e}")

            # Activate backup donor
            from .utils import activate_backup_donor_locked
            backup = activate_backup_donor_locked(blood_request, pledge)

            return success_response(
                message='No-show reported. Donor\'s reliability score has been decreased.',
                data={
                    'backup_activated': backup is not None,
                    'pledge': DonorResponseSerializer(pledge).data
                }
            )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error reporting no-show: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to report no-show.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# ============================================================================
# SOS Notification Views
# ============================================================================

@api_view(['POST'])
@permission_classes([AllowAny])
async def send_sos_notifications(request):
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
            fcm_token__ne='',  # Exclude empty tokens
            user__is_active=True
        ).select_related('user').all()

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
        notification_result = await send_batch_sos_notifications(
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
def update_fcm_token(request):
    """
    Update FCM token for the current user.

    POST /api/account/fcm-token/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "fcm_token": "device_fcm_token_string"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "FCM token updated successfully"
    }
    """
    try:
        from django.utils import timezone

        fcm_token = request.data.get('fcm_token')

        if not fcm_token:
            return error_response(
                message='fcm_token is required',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Validate token format (basic check)
        from account.fcm_service import validate_fcm_token
        if not validate_fcm_token(fcm_token):
            return error_response(
                message='Invalid FCM token format',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Get or create user profile
        profile, created = UserProfile.objects.get_or_create(
            user=request.user
        )

        # Update FCM token
        profile.fcm_token = fcm_token
        profile.fcm_token_updated_at = timezone.now()
        profile.save()

        logger.info(f"FCM token updated for user {request.user.email}")

        return success_response(
            message='FCM token updated successfully'
        )

    except Exception as e:
        logger.error(f"Error updating FCM token: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to update FCM token',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


# ============================================================================
# Phase 7: Pre-Donation Verification Views
# ============================================================================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def verify_pledge(request, pledge_id):
    """
    Verify pledge before donation (donor only).

    POST /api/blood-requests/pledges/{pledge_id}/verify/

    Phase 7: Pre-donation verification to ensure donor eligibility.

    Donor confirms:
    - They are available
    - They are medically eligible
    - Last donation date is acceptable
    - Health questionnaire is complete

    Response (200 OK):
    {
        "success": true,
        "message": "Pledge verified successfully",
        "pledge": {...}
    }
    """
    try:
        from django.utils import timezone

        pledge = DonorResponse.objects.get(id=pledge_id, donor=request.user)

        if pledge.status != 'pledged':
            return error_response(
                message='Only pledged donations can be verified.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        profile = getattr(request.user, 'profile', None)
        if not profile:
            return error_response(
                message='Profile required for verification.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Check eligibility
        if not profile.is_eligible:
            return error_response(
                message=f'Not eligible: {profile.eligibility_reason or "Last donation too recent"}',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Mark as verified
        pledge.is_verified = True
        pledge.verified_at = timezone.now()
        pledge.verified_availability = profile.is_available_for_donation
        pledge.verified_eligibility = profile.is_eligible
        pledge.verified_last_donation = True  # Already checked above
        pledge.verified_health_questionnaire = profile.eligibility_verified
        pledge.save()

        logger.info(f"Pledge {pledge_id} verified by {request.user.email}")

        return success_response(
            message='Pledge verified successfully. You can now be confirmed by the patient.',
            data={'pledge': DonorResponseSerializer(pledge).data}
        )

    except DonorResponse.DoesNotExist:
        return error_response(
            message='Pledge not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error verifying pledge: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to verify pledge.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_responding_donors_for_patient(request):
    """
    Get all donors who have responded to the patient's blood requests.

    GET /api/blood-requests/responding-donors/

    Response (200 OK):
    {
        "success": true,
        "message": "Responding donors retrieved",
        "donors": [...],
        "summary": {
            "total_donors": 5,
            "pledged": 3,
            "confirmed": 2
        }
    }
    """
    try:
        from django.db.models import Q, F
        from account.models import CustomUser

        # Get all blood requests created by this patient
        patient_requests = BloodRequest.objects.filter(
            requested_by=request.user
        ).values_list('id', flat=True)

        if not patient_requests:
            return success_response(
                message='No blood requests found',
                data={
                    'donors': [],
                    'summary': {
                        'total_donors': 0,
                        'pledged': 0,
                        'confirmed': 0,
                        'on_the_way': 0,
                        'completed': 0
                    }
                }
            )

        # Get all pledges for the patient's requests
        pledges = DonorResponse.objects.filter(
            blood_request_id__in=patient_requests
        ).select_related('donor__profile', 'blood_request').order_by('-created_at')

        # Serialize pledges with donor details
        donor_data = []
        pledged_count = 0
        confirmed_count = 0
        on_the_way_count = 0
        completed_count = 0

        for pledge in pledges:
            # Skip cancelled or rejected pledges
            if pledge.status in ['cancelled', 'rejected']:
                continue

            donor = pledge.donor
            if not donor:
                continue

            # Count by status
            if pledge.status == 'pledged':
                pledged_count += 1
            elif pledge.status == 'confirmed':
                confirmed_count += 1
            elif pledge.status == 'on_the_way':
                on_the_way_count += 1
            elif pledge.status == 'completed':
                completed_count += 1

            # Get donor profile data
            profile = getattr(donor, 'profile', None)

            donor_info = {
                'pledge_id': str(pledge.id),
                'request_id': str(pledge.blood_request.id),
                'patient_name': pledge.blood_request.patient_name,
                'blood_group': pledge.blood_request.blood_group,
                'donor': {
                    'id': str(donor.id),
                    'name': donor.full_name or donor.email.split('@')[0],
                    'email': donor.email,
                    'phone': donor.phone_num if donor else None,
                    'blood_group': profile.blood_group if profile else None,
                    'city': profile.city if profile else None,
                },
                'pledge': {
                    'units_pledged': pledge.units_pledged,
                    'preferred_date': pledge.preferred_date.isoformat() if pledge.preferred_date else None,
                    'note': pledge.note,
                    'status': pledge.status,
                    'status_display': pledge.get_status_display(),
                    'created_at': pledge.created_at.isoformat(),
                    'is_confirmed': pledge.status == 'confirmed',
                    'can_accept': pledge.status in ['pledged', 'shortlisted'],
                    'can_reject': pledge.status in ['pledged', 'shortlisted', 'confirmed'],
                    'can_complete': pledge.status in ['arrived', 'ready'],
                }
            }
            donor_data.append(donor_info)

        return success_response(
            message='Responding donors retrieved',
            data={
                'donors': donor_data,
                'summary': {
                    'total_donors': len(donor_data),
                    'pledged': pledged_count,
                    'confirmed': confirmed_count,
                    'on_the_way': on_the_way_count,
                    'completed': completed_count
                }
            }
        )

    except Exception as e:
        logger.error(f"Error fetching responding donors: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch responding donors.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
