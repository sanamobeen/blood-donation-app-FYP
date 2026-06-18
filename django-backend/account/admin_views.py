"""
Admin API Views for User Management.

Provides endpoints for:
- List all users with pagination and filtering
- Get user details
- Activate/Deactivate users
- Delete users
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.db.models import Count, Sum, Q
from django.contrib.auth import get_user_model
from datetime import datetime, timedelta

from .models import CustomUser, UserProfile

User = get_user_model()

logger = logging.getLogger(__name__)


def success_response(message, data=None, status_code=status.HTTP_200_OK):
    """Create a standardized success response."""
    response_data = {'success': True, 'message': message}
    if data is not None:
        response_data['data'] = data
    return Response(response_data, status=status_code)


def error_response(message, errors=None, status_code=status.HTTP_400_BAD_REQUEST):
    """Create a standardized error response."""
    response_data = {'success': False, 'message': message}
    if errors:
        response_data['errors'] = errors
    return Response(response_data, status=status_code)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_list_users(request):
    """
    Get all users with pagination and filtering.

    GET /api/admin/users/

    Query Parameters:
    - page: Page number (default: 1)
    - page_size: Items per page (default: 20)
    - search: Search by name, email, or phone
    - role: Filter by role (donor, patient)
    - blood_type: Filter by blood type
    - status: Filter by status (active, inactive)

    Response (200 OK):
    {
        "success": true,
        "message": "Users retrieved successfully",
        "data": {
            "users": [...],
            "total_count": 100,
            "total_pages": 5,
            "current_page": 1
        }
    }
    """
    try:
        # Get query parameters
        page = int(request.GET.get('page', 1))
        page_size = int(request.GET.get('page_size', 20))
        search = request.GET.get('search', '').strip()
        role_filter = request.GET.get('role', '').strip().lower()
        blood_type_filter = request.GET.get('blood_type', '').strip()
        status_filter = request.GET.get('status', '').strip().lower()

        # Base queryset
        users_qs = User.objects.all().order_by('-date_joined')

        # Apply search filter
        if search:
            users_qs = users_qs.filter(
                Q(full_name__icontains=search) |
                Q(email__icontains=search) |
                Q(phone_num__icontains=search)
            )

        # Apply role filter (role is in User model, not profile)
        if role_filter and role_filter in ['donor', 'patient', 'admin']:
            users_qs = users_qs.filter(role=role_filter)

        # Apply blood type filter
        if blood_type_filter:
            users_qs = users_qs.filter(profile__blood_group=blood_type_filter)

        # Apply status filter (active users are those not marked as deleted/inactive)
        # For now, we'll consider all active users
        if status_filter == 'inactive':
            # You'll need to add an is_active field to CustomUser model
            # For now, this won't filter
            pass

        # Get total count before pagination
        total_count = users_qs.count()
        total_pages = (total_count + page_size - 1) // page_size

        # Paginate
        start = (page - 1) * page_size
        end = start + page_size
        users = users_qs[start:end]

        # Build response data
        users_data = []
        for user in users:
            try:
                profile = user.profile
                blood_type = profile.blood_group if hasattr(profile, 'blood_group') else None
                user_role = user.role if hasattr(user, 'role') else None  # role is in User model
                city = profile.city if hasattr(profile, 'city') else None
                state = profile.state if hasattr(profile, 'state') else None
                country = profile.country if hasattr(profile, 'country') else ''
                total_donations = 0  # Would come from donations model
                last_donation_date = None
                profile_completion = 0
            except UserProfile.DoesNotExist:
                blood_type = None
                user_role = None
                city = None
                state = None
                country = ''
                total_donations = 0
                last_donation_date = None
                profile_completion = 0

            # Count donations
            from donations.models import Donation
            donations_qs = Donation.objects.filter(donor=user)
            total_donations = donations_qs.count()
            if total_donations > 0:
                last_donation = donations_qs.order_by('-donation_date').first()
                if last_donation:
                    last_donation_date = last_donation.donation_date

            # Calculate profile completion (simplified)
            profile_fields = [
                blood_type, city, country
            ]
            completed_fields = sum(1 for f in profile_fields if f)
            profile_completion = (completed_fields / len(profile_fields)) * 100 if profile_fields else 0

            users_data.append({
                'id': str(user.id),
                'email': user.email,
                'full_name': user.full_name,
                'phone_num': user.phone_num,
                'role': user_role or 'user',
                'blood_type': blood_type,
                'city': city,
                'state': state,
                'country': country,
                'profile_picture': profile.profile_picture.url if profile and profile.profile_picture else None,
                'is_active': user.is_active,
                'profile_completion': profile_completion,
                'total_donations': total_donations,
                'last_donation_date': last_donation_date.isoformat() if last_donation_date else None,
                'created_at': user.date_joined.isoformat(),
                'last_login': user.last_login.isoformat() if user.last_login else None,
            })

        return success_response(
            message='Users retrieved successfully.',
            data={
                'users': users_data,
                'total_count': total_count,
                'total_pages': total_pages,
                'current_page': page,
            }
        )

    except Exception as e:
        logger.error(f"Error fetching users: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch users.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_user_detail(request, user_id):
    """
    Get detailed information about a specific user.

    GET /api/admin/users/{user_id}/

    Response (200 OK):
    {
        "success": true,
        "message": "User details retrieved",
        "data": {
            "user": {...},
            "donations": [...],
            "blood_requests": [...],
            "pledges": [...],
            "activity_log": [...]
        }
    }
    """
    try:
        user = User.objects.get(id=user_id)

        # Get user profile data
        try:
            profile = user.profile
            blood_type = profile.blood_group if hasattr(profile, 'blood_group') else None
            user_role = user.role if hasattr(user, 'role') else None  # role is in User model
            city = profile.city if hasattr(profile, 'city') else None
            state = profile.state if hasattr(profile, 'state') else None
            country = profile.country if hasattr(profile, 'country') else ''
        except UserProfile.DoesNotExist:
            blood_type = None
            user_role = user.role if hasattr(user, 'role') else None
            city = None
            state = None
            country = ''

        # Build user data
        from donations.models import Donation
        donations_qs = Donation.objects.filter(donor=user)
        total_donations = donations_qs.count()

        user_data = {
            'id': str(user.id),
            'email': user.email,
            'full_name': user.full_name,
            'phone_num': user.phone_num,
            'role': user_role or 'user',
            'blood_type': blood_type,
            'city': city,
            'state': state,
            'country': country,
            'profile_picture': profile.profile_picture.url if profile and profile.profile_picture else None,
            'is_active': user.is_active,
            'total_donations': total_donations,
            'created_at': user.date_joined.isoformat(),
            'last_login': user.last_login.isoformat() if user.last_login else None,
        }

        # Get donations
        donations_data = []
        for donation in donations_qs[:10]:  # Last 10 donations
            donations_data.append({
                'id': str(donation.id),
                'date': donation.donation_date.isoformat(),
                'units': donation.units,
                'certificate': True,  # Assuming all have certificates
            })

        # Get blood requests
        from blood_requests.models import BloodRequest
        blood_requests_qs = BloodRequest.objects.filter(requested_by=user)
        requests_data = []
        for req in blood_requests_qs[:10]:
            requests_data.append({
                'id': str(req.id),
                'blood_type': req.blood_type,
                'units_needed': req.units_needed,
                'status': req.status,
                'created_at': req.created_at.isoformat(),
            })

        # Get pledges (responded to other requests)
        pledges_data = []  # To be implemented

        # Build activity log (simplified)
        activity_log = []
        if user.date_joined:
            activity_log.append({
                'action': 'Account created',
                'timestamp': user.date_joined.isoformat(),
            })
        if user.last_login:
            activity_log.append({
                'action': 'Last login',
                'timestamp': user.last_login.isoformat(),
            })

        return success_response(
            message='User details retrieved successfully.',
            data={
                'user': user_data,
                'donations': donations_data,
                'blood_requests': requests_data,
                'pledges': pledges_data,
                'activity_log': activity_log,
            }
        )

    except User.DoesNotExist:
        return error_response(
            message='User not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error fetching user details: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch user details.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def admin_activate_user(request, user_id):
    """
    Activate a user account.

    POST /api/admin/users/{user_id}/activate/

    Response (200 OK):
    {
        "success": true,
        "message": "User activated successfully"
    }
    """
    try:
        user = User.objects.get(id=user_id)
        user.is_active = True
        user.save()

        return success_response(message='User activated successfully.')

    except User.DoesNotExist:
        return error_response(
            message='User not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error activating user: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to activate user.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def admin_deactivate_user(request, user_id):
    """
    Deactivate a user account.

    POST /api/admin/users/{user_id}/deactivate/

    Response (200 OK):
    {
        "success": true,
        "message": "User deactivated successfully"
    }
    """
    try:
        user = User.objects.get(id=user_id)
        user.is_active = False
        user.save()

        return success_response(message='User deactivated successfully.')

    except User.DoesNotExist:
        return error_response(
            message='User not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error deactivating user: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to deactivate user.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def admin_delete_user(request, user_id):
    """
    Delete a user account.

    DELETE /api/admin/users/{user_id}/

    Response (204 No Content):
    User deleted successfully.
    """
    try:
        user = User.objects.get(id=user_id)
        user.delete()

        return Response(status=status.HTTP_204_NO_CONTENT)

    except User.DoesNotExist:
        return error_response(
            message='User not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error deleting user: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to delete user.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
