"""
API Views for Statistics.

Provides endpoints for:
- Public statistics (total donors, donations, etc.)
- User-specific statistics
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.db.models import Count, Sum, Q
from django.utils import timezone
from datetime import timedelta

from account.models import CustomUser, UserProfile
from blood_requests.models import BloodRequest
from donations.models import Donation


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


@api_view(['GET'])
@permission_classes([AllowAny])
def public_stats(request):
    """
    Get public statistics for the blood donation platform.

    GET /api/stats/public/

    Response (200 OK):
    {
        "success": true,
        "message": "Public statistics retrieved",
        "data": {
            "total_donors": 15234,
            "total_donations": 45678,
            "active_requests": 234,
            "lives_saved": 137034,
            "blood_type_distribution": {...}
        }
    }
    """
    try:
        # Count total donors (users with profiles)
        total_donors = UserProfile.objects.count()

        # Count total donations
        total_donations = Donation.objects.count()

        # Count active blood requests
        active_requests = BloodRequest.objects.filter(
            is_active=True,
            status='pending'
        ).count()

        # Calculate lives saved (1 unit = 3 lives saved estimate)
        total_units = Donation.objects.aggregate(total=Sum('units'))['total'] or 0
        lives_saved = total_units * 3

        # Blood type distribution
        blood_type_dist = {}
        blood_types = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        for bt in blood_types:
            count = UserProfile.objects.filter(blood_group=bt).count()
            if total_donors > 0:
                percentage = round((count / total_donors) * 100)
            else:
                percentage = 0
            blood_type_dist[bt] = {
                'count': count,
                'percentage': percentage
            }

        return success_response(
            message='Public statistics retrieved successfully.',
            data={
                'total_donors': total_donors,
                'total_donations': total_donations,
                'active_requests': active_requests,
                'lives_saved': lives_saved,
                'blood_type_distribution': blood_type_dist
            }
        )

    except Exception as e:
        logger.error(f"Error fetching public stats: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch statistics.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_stats(request):
    """
    Get user-specific statistics.

    GET /api/stats/user/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "User statistics retrieved",
        "data": {
            "total_donations": 5,
            "total_units_donated": 5,
            "lives_saved": 15,
            "requests_created": 2,
            "sos_responded": 3,
            "achievements_count": 3,
            "points": 150
        }
    }
    """
    try:
        user = request.user

        # Count user's donations
        user_donations = Donation.objects.filter(donor=user)
        total_donations = user_donations.count()
        total_units = user_donations.aggregate(total=Sum('units'))['total'] or 0

        # Calculate lives saved
        lives_saved = total_units * 3

        # Count blood requests created by user
        requests_created = BloodRequest.objects.filter(requested_by=user).count()

        # Count SOS responses
        sos_responded = 0  # Will be implemented when SOS responses are tracked

        # Get profile data if exists
        achievements_count = 0
        points = 0
        try:
            profile = user.profile
            # These would come from an achievements system
            # For now, use total_donations as a proxy
            achievements_count = min(total_donations, 10)
            points = total_donations * 10
        except UserProfile.DoesNotExist:
            pass

        return success_response(
            message='User statistics retrieved successfully.',
            data={
                'total_donations': total_donations,
                'total_units_donated': total_units,
                'lives_saved': lives_saved,
                'requests_created': requests_created,
                'sos_responded': sos_responded,
                'achievements_count': achievements_count,
                'points': points
            }
        )

    except Exception as e:
        logger.error(f"Error fetching user stats: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch your statistics.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
