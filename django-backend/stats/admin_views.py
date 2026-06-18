"""
Admin API Views for Statistics and Analytics.

Provides endpoints for:
- Dashboard overview statistics
- Detailed analytics with date ranges
- User growth data
- Blood type distribution
- Donation trends
- Geographic distribution
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.db.models import Count, Sum, Q
from django.utils import timezone
from datetime import datetime, timedelta
from django.db.models.functions import TruncDate, TruncMonth

from account.models import CustomUser, UserProfile
from blood_requests.models import BloodRequest
from donations.models import Donation
from django.contrib.auth import get_user_model

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
def admin_dashboard_stats(request):
    """
    Get dashboard overview statistics.

    GET /api/admin/stats/overview/

    Response (200 OK):
    {
        "success": true,
        "message": "Dashboard statistics retrieved",
        "data": {
            "total_users": 500,
            "total_donors": 350,
            "total_patients": 150,
            "active_blood_requests": 25,
            "fulfilled_requests_this_month": 45,
            "total_donations": 1200,
            "lives_saved": 3600,
            "active_sos_requests": 3,
            "users_growth": 12.5,
            "donors_growth": 10.2,
            "patients_growth": 18.3,
            "donations_growth": 8.7
        }
    }
    """
    try:
        # Current date and previous month for growth calculation
        now = timezone.now()
        prev_month_start = now - timedelta(days=30)
        two_months_ago = now - timedelta(days=60)

        # Total users
        total_users = User.objects.count()
        users_prev_month = User.objects.filter(date_joined__lt=prev_month_start).count()
        users_growth = ((total_users - users_prev_month) / users_prev_month * 100) if users_prev_month > 0 else 0

        # Total donors
        total_donors = User.objects.filter(role='donor').count()
        donors_prev_month = User.objects.filter(
            role='donor',
            date_joined__lt=prev_month_start
        ).count()
        donors_growth = ((total_donors - donors_prev_month) / donors_prev_month * 100) if donors_prev_month > 0 else 0

        # Total patients
        total_patients = User.objects.filter(role='patient').count()
        patients_prev_month = User.objects.filter(
            role='patient',
            date_joined__lt=prev_month_start
        ).count()
        patients_growth = ((total_patients - patients_prev_month) / patients_prev_month * 100) if patients_prev_month > 0 else 0

        # Active blood requests
        active_blood_requests = BloodRequest.objects.filter(
            status='pending'
        ).count()

        # Fulfilled requests this month
        fulfilled_requests_this_month = BloodRequest.objects.filter(
            status='fulfilled',
            updated_at__gte=now.replace(day=1)
        ).count()

        # Total donations
        total_donations = Donation.objects.count()
        donations_prev_month = Donation.objects.filter(
            donation_date__lt=prev_month_start
        ).count()
        donations_growth = ((total_donations - donations_prev_month) / donations_prev_month * 100) if donations_prev_month > 0 else 0

        # Calculate lives saved (1 unit = 3 lives)
        total_units = Donation.objects.aggregate(total=Sum('units'))['total'] or 0
        lives_saved = total_units * 3

        # Active SOS requests (if SOS model exists)
        active_sos_requests = 0
        try:
            from sos.models import SOSRequest
            active_sos_requests = SOSRequest.objects.filter(
                status='active'
            ).count()
        except:
            pass

        return success_response(
            message='Dashboard statistics retrieved successfully.',
            data={
                'total_users': total_users,
                'total_donors': total_donors,
                'total_patients': total_patients,
                'active_blood_requests': active_blood_requests,
                'fulfilled_requests_this_month': fulfilled_requests_this_month,
                'total_donations': total_donations,
                'lives_saved': lives_saved,
                'active_sos_requests': active_sos_requests,
                'users_growth': round(users_growth, 1),
                'donors_growth': round(donors_growth, 1),
                'patients_growth': round(patients_growth, 1),
                'donations_growth': round(donations_growth, 1),
            }
        )

    except Exception as e:
        logger.error(f"Error fetching dashboard stats: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch dashboard statistics.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_analytics(request):
    """
    Get detailed analytics with date range.

    GET /api/admin/stats/analytics/

    Query Parameters:
    - start_date: Start date (ISO format)
    - end_date: End date (ISO format)

    Response (200 OK):
    {
        "success": true,
        "message": "Analytics retrieved",
        "data": {
            "user_growth": [...],
            "blood_type_distribution": [...],
            "donation_stats": [...],
            "geographic_distribution": [...],
            "start_date": "2024-01-01",
            "end_date": "2024-01-31"
        }
    }
    """
    try:
        # Get date range from query params
        start_date_str = request.GET.get('start_date')
        end_date_str = request.GET.get('end_date')

        # Default to last 30 days if not provided
        if not start_date_str or not end_date_str:
            end_date = timezone.now()
            start_date = end_date - timedelta(days=30)
        else:
            start_date = datetime.fromisoformat(start_date_str)
            end_date = datetime.fromisoformat(end_date_str)

        # Ensure dates are timezone-aware
        if timezone.is_naive(start_date):
            start_date = timezone.make_aware(start_date)
        if timezone.is_naive(end_date):
            end_date = timezone.make_aware(end_date)

        # User growth data (daily)
        user_growth = []
        users_qs = User.objects.filter(
            date_joined__gte=start_date,
            date_joined__lte=end_date
        ).annotate(
            join_date=TruncDate('date_joined')
        ).values('join_date').annotate(
            count=Count('id')
        ).order_by('join_date')

        cumulative_users = User.objects.filter(date_joined__lt=start_date).count()
        for entry in users_qs:
            cumulative_users += entry['count']
            user_growth.append({
                'date': entry['join_date'].isoformat(),
                'total_users': cumulative_users,
                'new_donors': 0,  # Would need profile data
                'new_patients': 0,  # Would need profile data
            })

        # Blood type distribution
        blood_type_distribution = []
        blood_types = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
        total_donors = User.objects.filter(role='donor').count()

        for bt in blood_types:
            # Get users with donor role and their profile's blood group
            count = User.objects.filter(role='donor').filter(
                profile__blood_group=bt
            ).count()
            percentage = (count / total_donors * 100) if total_donors > 0 else 0
            blood_type_distribution.append({
                'blood_type': bt,
                'count': count,
                'percentage': round(percentage, 1)
            })

        # Donation statistics (monthly)
        donation_stats = []
        donations_qs = Donation.objects.filter(
            donation_date__gte=start_date,
            donation_date__lte=end_date
        ).annotate(
            month=TruncMonth('donation_date')
        ).values('month').annotate(
            donations=Count('id'),
            units=Sum('units')
        ).order_by('month')

        for entry in donations_qs:
            donation_stats.append({
                'month': entry['month'].isoformat(),
                'donations': entry['donations'],
                'units': entry['units'] or 0
            })

        # Geographic distribution
        geographic_distribution = []
        geo_qs = UserProfile.objects.values('city', 'state', 'country').annotate(
            user_count=Count('user')
        ).order_by('-user_count')[:20]

        for entry in geo_qs:
            # Count donors in this location
            donor_count = User.objects.filter(
                profile__city=entry['city'],
                profile__state=entry.get('state'),
                profile__country=entry['country'],
                role='donor'
            ).count()

            geographic_distribution.append({
                'city': entry['city'] or 'Unknown',
                'state': entry.get('state'),
                'user_count': entry['user_count'],
                'donor_count': donor_count
            })

        return success_response(
            message='Analytics retrieved successfully.',
            data={
                'user_growth': user_growth,
                'blood_type_distribution': blood_type_distribution,
                'donation_stats': donation_stats,
                'geographic_distribution': geographic_distribution,
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat(),
            }
        )

    except Exception as e:
        logger.error(f"Error fetching analytics: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch analytics.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
