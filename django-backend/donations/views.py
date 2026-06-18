"""
API Views for Donations.

Provides endpoints for recording and retrieving blood donation records.
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
from django.db.models import Sum

from .models import Donation
from .serializers import DonationSerializer, DonationCreateSerializer


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
@permission_classes([IsAuthenticated])
def my_donations(request):
    """
    Get current user's donation records.

    GET /api/donations/my/

    Response (200 OK):
    {
        "success": true,
        "message": "Donations retrieved",
        "data": {
            "donations": [...],
            "count": 5
        }
    }
    """
    try:
        donations = Donation.objects.filter(
            donor=request.user
        ).order_by('-donation_date', '-created_at')

        serializer = DonationSerializer(donations, many=True)

        # Get total donations count from user profile if available
        total_donations = donations.count()

        return success_response(
            message='Your donations retrieved successfully.',
            data={
                'donations': serializer.data,
                'count': total_donations,
                'total_donations': total_donations
            }
        )

    except Exception as e:
        return error_response(
            message='Failed to retrieve donations.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_donation(request):
    """
    Record a new donation.

    POST /api/donations/

    Response (201 Created):
    {
        "success": true,
        "message": "Donation recorded successfully",
        "data": {
            "donation": {...}
        }
    }
    """
    try:
        serializer = DonationCreateSerializer(
            data=request.data,
            context={'request': request}
        )

        if serializer.is_valid():
            donation = serializer.save()

            # Update associated pledge status if blood request exists
            if donation.blood_request:
                from blood_requests.models import DonorResponse
                try:
                    # Find and update the pledge to 'donated' status
                    pledge = DonorResponse.objects.filter(
                        blood_request=donation.blood_request,
                        donor=request.user,
                        status='pledged'
                    ).first()

                    if pledge:
                        pledge.status = 'completed'
                        pledge.completed_at = timezone.now()
                        pledge.save()
                        logger.info(f"Pledge {pledge.id} updated to 'donated' status")
                except:
                    pass  # Pledge may not exist

                # Notify patient about the donation
                if donation.blood_request.requested_by:
                    try:
                        from notifications.models import Notification
                        Notification.objects.create(
                            user=donation.blood_request.requested_by,
                            title='Donation Recorded! 🩸',
                            message=f'A donation has been recorded by {request.user.full_name or request.user.email}. Please acknowledge it once received.',
                            type='donation_recorded',
                            related_request_id=str(donation.blood_request.id)
                        )
                        logger.info(f"Notification created for patient {donation.blood_request.requested_by.email}")
                    except Exception as e:
                        logger.warning(f"Failed to create notification: {e}")

            # Update donor profile total_donations if UserProfile exists
            try:
                from account.models import UserProfile
                user_profile = UserProfile.objects.filter(user=request.user).first()
                if user_profile:
                    user_profile.total_donations += 1
                    user_profile.last_donation = donation.donation_date
                    user_profile.save()
            except:
                pass  # UserProfile may not exist or have different structure

            result_serializer = DonationSerializer(donation)

            return success_response(
                message='Donation recorded successfully.',
                data={
                    'donation': result_serializer.data
                },
                status_code=status.HTTP_201_CREATED
            )

        return error_response(
            message='Failed to record donation.',
            errors=serializer.errors
        )

    except Exception as e:
        return error_response(
            message='An error occurred while recording the donation.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def donation_detail(request, donation_id):
    """
    Get details of a specific donation.

    GET /api/donations/{id}/

    Response (200 OK):
    {
        "success": true,
        "message": "Donation retrieved",
        "data": {
            "donation": {...}
        }
    }
    """
    try:
        donation = Donation.objects.get(id=donation_id, donor=request.user)
        serializer = DonationSerializer(donation)

        return success_response(
            message='Donation retrieved successfully.',
            data={
                'donation': serializer.data
            }
        )

    except Donation.DoesNotExist:
        return error_response(
            message='Donation not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )

    except Exception as e:
        return error_response(
            message='Failed to retrieve donation.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def donation_stats(request):
    """
    Get donation statistics for current user.

    GET /api/donations/stats/

    Response (200 OK):
    {
        "success": true,
        "message": "Statistics retrieved",
        "data": {
            "total_donations": 5,
            "total_units": 5,
            "last_donation_date": "2024-06-05"
        }
    }
    """
    try:
        donations = Donation.objects.filter(donor=request.user)
        total_donations_count = donations.count()
        total_units = sum(d.units for d in donations)

        last_donation = donations.first()
        last_donation_date = last_donation.donation_date if last_donation else None

        return success_response(
            message='Donation statistics retrieved successfully.',
            data={
                'total_donations': total_donations_count,
                'total_units': total_units,
                'last_donation_date': last_donation_date
            }
        )

    except Exception as e:
        return error_response(
            message='Failed to retrieve statistics.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def acknowledge_donation(request, donation_id):
    """
    Patient acknowledges a donation (confirms donation happened).

    POST /api/donations/{id}/acknowledge

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Donation acknowledged",
        "data": {
            "donation": {...},
            "certificate_number": "DN-2024-ABC123"
        }
    }
    """
    try:
        donation = Donation.objects.get(id=donation_id)

        # Check if user can acknowledge (must be the requester of the blood request)
        if not donation.can_be_acknowledged_by(request.user):
            return error_response(
                message='You are not authorized to acknowledge this donation.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Check if already acknowledged
        if donation.acknowledged_by_patient:
            return error_response(
                message='This donation has already been acknowledged.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Acknowledge the donation
        donation.acknowledged_by_patient = True
        donation.acknowledged_at = timezone.now()

        # Generate certificate number
        certificate_number = donation.generate_certificate_number()

        # Mark certificate as issued
        donation.certificate_issued = True
        donation.save()

        logger.info(f"Donation {donation_id} acknowledged by {request.user.email}")

        # Update blood request when donation is acknowledged
        if donation.blood_request:
            blood_request = donation.blood_request

            # Update units received counter
            blood_request.units_received += donation.units
            blood_request.save()

            # Create notification for donor
            try:
                from notifications.models import Notification
                Notification.objects.create(
                    user=donation.donor,
                    title='Donation Acknowledged! 🎉',
                    message=f'Your donation of {donation.units} unit(s) has been acknowledged. Thank you for saving a life!',
                    type='donation_acknowledged',
                    related_request_id=str(blood_request.id)
                )
                logger.info(f"Notification created for donor {donation.donor.email}")
            except Exception as e:
                logger.warning(f"Failed to create notification: {e}")

            # Count acknowledged units and update status if fulfilled
            acknowledged_units = Donation.objects.filter(
                blood_request=blood_request,
                acknowledged_by_patient=True
            ).aggregate(total=Sum('units'))['total'] or 0

            if acknowledged_units >= blood_request.units_needed and blood_request.status != 'fulfilled':
                blood_request.status = 'fulfilled'
                blood_request.is_active = False
                blood_request.save()
                logger.info(f"Blood request {blood_request.id} marked as fulfilled")

                # Notify all donors who pledged
                pledged_donors = CustomUser.objects.filter(
                    pledges__blood_request=blood_request,
                    pledges__status__in=['pledged', 'donated']
                ).distinct()

                for donor in pledged_donors:
                    if donor != donation.donor:  # Don't notify the donor who just donated
                        try:
                            from notifications.models import Notification
                            Notification.objects.create(
                                user=donor,
                                title='Blood Request Fulfilled! ✅',
                                message=f'The blood request for {blood_request.patient_name} has been fulfilled. Thank you for your willingness to help.',
                                type='request_fulfilled',
                                related_request_id=str(blood_request.id)
                            )
                        except Exception as e:
                            logger.warning(f"Failed to create notification: {e}")

        serializer = DonationSerializer(donation, context={'request': request})

        return success_response(
            message='Donation acknowledged successfully. Thank you for confirming!',
            data={
                'donation': serializer.data,
                'certificate_number': certificate_number
            }
        )

    except Donation.DoesNotExist:
        return error_response(
            message='Donation not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error acknowledging donation: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to acknowledge donation.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def donation_certificate(request, donation_id):
    """
    Get donation certificate.

    GET /api/donations/{id}/certificate

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Certificate generated",
        "data": {
            "certificate_number": "DN-2024-ABC123",
            "donation_number": "DN-2024-0001",
            "donation_date": "2024-06-05",
            "donor_name": "John Doe",
            "units": 1,
            "recipient": "On behalf of City Hospital",
            "issued_at": "2024-06-05T10:00:00Z"
        }
    }
    """
    try:
        donation = Donation.objects.get(id=donation_id)

        # Check if user owns this donation
        if donation.donor != request.user:
            return error_response(
                message='You can only view your own donation certificates.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Check if donation is acknowledged
        if not donation.acknowledged_by_patient:
            return error_response(
                message='Certificate is only available after patient acknowledges the donation.',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Generate certificate number if not exists
        if not donation.certificate_number:
            donation.generate_certificate_number()
            donation.save()

        # Get patient name as recipient
        recipient = donation.blood_request.patient_name if donation.blood_request else 'Unknown Recipient'

        return success_response(
            message='Certificate retrieved successfully.',
            data={
                'certificate_number': donation.certificate_number,
                'donation_number': donation.certificate_number,
                'donation_date': donation.donation_date,
                'donor_name': request.user.get_full_name(),
                'blood_type': donation.blood_type_code if donation.blood_type else None,
                'units': donation.units,
                'recipient': recipient,
                'issued_at': donation.acknowledged_at
            }
        )

    except Donation.DoesNotExist:
        return error_response(
            message='Donation not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error generating certificate: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to generate certificate.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def blood_request_responses(request, request_id):
    """
    Get list of donations/responses for a blood request (for the patient).

    GET /api/donations/request-responses/{request_id}/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Responses retrieved",
        "data": {
            "responses": [...],
            "acknowledged_count": 2,
            "pending_count": 1,
            "total_units_received": 2
        }
    }
    """
    try:
        from blood_requests.models import BloodRequest

        blood_request = BloodRequest.objects.get(id=request_id)

        # Check if user owns this request
        if blood_request.requested_by != request.user:
            return error_response(
                message='You can only view responses for your own blood requests.',
                status_code=status.HTTP_403_FORBIDDEN
            )

        # Get all donations for this request
        donations = Donation.objects.filter(
            blood_request=blood_request
        ).order_by('-created_at')

        serializer = DonationSerializer(donations, many=True, context={'request': request})

        # Calculate stats
        acknowledged_count = donations.filter(acknowledged_by_patient=True).count()
        pending_count = donations.filter(acknowledged_by_patient=False).count()
        total_units_received = Donation.objects.filter(
            blood_request=blood_request,
            acknowledged_by_patient=True
        ).aggregate(total=Sum('units'))['total'] or 0

        return success_response(
            message='Donation responses retrieved successfully.',
            data={
                'responses': serializer.data,
                'acknowledged_count': acknowledged_count,
                'pending_count': pending_count,
                'total_units_received': total_units_received,
                'units_needed': blood_request.units_needed
            }
        )

    except BloodRequest.DoesNotExist:
        return error_response(
            message='Blood request not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error fetching request responses: {str(e)}", exc_info=True)
        return error_response(
            message='Failed to fetch responses.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
