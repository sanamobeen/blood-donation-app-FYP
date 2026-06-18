"""
API Views for Blood Donation Authentication.

Provides endpoints for:
- User Registration
- User Login/Logout
- Profile Management
- Password Change
"""
import logging
from rest_framework import status, serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from django.conf import settings

from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserSerializer,
    UserUpdateSerializer,
    PasswordChangeSerializer,
    ForgotPasswordSerializer,
    ResetPasswordSerializer,
    UserProfileSerializer,
    UserProfileCreateSerializer,
    UserProfileUpdateSerializer,
    PublicProfileSerializer,
    DonationRecordSerializer,
    MedicalInfoUpdateSerializer,
)
from .models import CustomUser, UserProfile, PasswordReset


# Configure logging
logger = logging.getLogger(__name__)


# Helper Functions
def get_tokens_for_user(user):
    """
    Generate JWT tokens for a user.
    Returns both access and refresh tokens.
    """
    refresh = RefreshToken.for_user(user)
    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }


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


# Authentication Views

@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    """
    Register a new user account.

    POST /api/auth/register/

    Request Body:
    {
        "email": "user@example.com",
        "password": "SecurePass123",
        "password_confirm": "SecurePass123",
        "full_name": "John Doe",
        "phone_num": "+1234567890",
        "address": "123 Street, City"
    }

    Response (201 Created):
    {
        "success": true,
        "message": "Registration successful",
        "user": {...},
        "tokens": {...}
    }
    """
    serializer = UserRegistrationSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.save()
        tokens = get_tokens_for_user(user)

        logger.info(f"New user registered: {user.email}")

        return success_response(
            message='Registration successful. Please verify your phone number.',
            data={
                'user': UserSerializer(user).data,
                'tokens': tokens,
            },
            status_code=status.HTTP_201_CREATED
        )

    logger.warning(f"Registration failed: {serializer.errors}")
    return error_response(
        message='Registration failed. Please check your input.',
        errors=serializer.errors
    )


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    """
    Authenticate user and return tokens.

    POST /api/auth/login/

    Request Body:
    {
        "email": "user@example.com",
        "password": "SecurePass123"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Login successful",
        "user": {...},
        "tokens": {...}
    }
    """
    serializer = UserLoginSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.validated_data['user']
        tokens = get_tokens_for_user(user)

        logger.info(f"User logged in: {user.email}")

        # Include both user data with role and profile data (if exists)
        response_data = {
            'user': UserSerializer(user).data,
            'tokens': tokens,
        }

        # Add profile data if it exists
        try:
            response_data['profile'] = UserProfileSerializer(user.profile).data
        except Exception:
            # User doesn't have a profile yet or other error, skip profile data
            pass

        return success_response(
            message='Login successful.',
            data=response_data
        )

    logger.warning(f"Login failed: {serializer.errors}")
    return error_response(
        message='Login failed. Please check your credentials.',
        errors=serializer.errors
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    """
    Logout user by blacklisting the refresh token.

    POST /api/auth/logout/

    Request Body:
    {
        "refresh": "refresh_token_string"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Logout successful"
    }
    """
    try:
        refresh_token = request.data.get('refresh')
        if refresh_token:
            token = RefreshToken(refresh_token)
            token.blacklist()

        logger.info(f"User logged out: {request.user.email}")
        return success_response(message='Logout successful.')

    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        return error_response(
            message='Logout failed.',
            errors={'refresh': 'Invalid or expired token.'}
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    """
    Get current user profile.

    GET /api/auth/profile/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Profile retrieved successfully",
        "user": {...}
    }
    """
    serializer = UserSerializer(request.user)
    return success_response(
        message='Profile retrieved successfully.',
        data={'user': serializer.data}
    )


@api_view(['PATCH', 'PUT'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    """
    Update user profile.

    PATCH /api/auth/profile/update/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "full_name": "John Updated Doe",
        "phone_num": "+9876543210",
        "address": "New address"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Profile updated successfully",
        "user": {...}
    }
    """
    serializer = UserUpdateSerializer(request.user, data=request.data, partial=True)

    if serializer.is_valid():
        serializer.save()
        logger.info(f"Profile updated: {request.user.email}")
        return success_response(
            message='Profile updated successfully.',
            data={'user': UserSerializer(request.user).data}
        )

    return error_response(
        message='Profile update failed.',
        errors=serializer.errors
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """
    Change user password.

    POST /api/auth/change-password/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "old_password": "OldPass123",
        "new_password": "NewPass123",
        "new_password_confirm": "NewPass123"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Password changed successfully"
    }
    """
    serializer = PasswordChangeSerializer(
        data=request.data,
        context={'request': request}
    )

    if serializer.is_valid():
        user = request.user
        user.set_password(serializer.validated_data['new_password'])
        user.save()

        # Generate new tokens (invalidate old ones)
        tokens = get_tokens_for_user(user)

        logger.info(f"Password changed: {user.email}")

        return success_response(
            message='Password changed successfully. Please login again with new password.',
            data={'tokens': tokens}
        )

    return error_response(
        message='Password change failed.',
        errors=serializer.errors
    )


# Profile CRUD Views

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_detail(request):
    """
    Get current user's full profile.

    GET /api/auth/profile/detail/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Profile retrieved successfully",
        "profile": {...}  # Always returned, minimal for patients
    }
    """
    user = request.user
    user_serializer = UserSerializer(user)

    # Try to get UserProfile (exists for donors, not for patients)
    try:
        profile = user.profile
        profile_serializer = UserProfileSerializer(profile)
        return success_response(
            message='Profile retrieved successfully.',
            data={
                'profile': profile_serializer.data,
                'user': user_serializer.data
            }
        )
    except UserProfile.DoesNotExist:
        # For patients without UserProfile, create minimal profile from user data
        # This ensures Flutter app always gets a consistent structure
        minimal_profile = {
            'id': str(user.id),
            'user_full_name': user.full_name,
            'email': user.email,
            'username': user.email,  # Use email as username
            'profile_picture': None,
            'profile_picture_url': None,
            'blood_group': None,
            'age': None,
            'gender': None,
            'weight': None,
            'city': None,
            'date_of_birth': None,
            'created_at': user.date_joined.isoformat(),
            'updated_at': user.date_joined.isoformat(),
            'role': user.role
        }
        return success_response(
            message='Profile retrieved successfully.',
            data={
                'profile': minimal_profile,
                'user': user_serializer.data
            }
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def profile_create(request):
    """
    Create a new user profile.

    POST /api/auth/profile/create/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "blood_type": "A+",
        "date_of_birth": "1990-01-01",
        "gender": "male",
        "weight": 70,
        "address": "123 Street, City",
        "city": "Lahore",
        "state": "Punjab",
        "postal_code": "54000",
        "country": "Pakistan",
        "latitude": 31.5204,
        "longitude": 74.3587,
        "is_available_for_donation": true,
        "preferred_donation_time": "morning",
        "preferred_donation_location": "Blood Bank",
        "emergency_contact_name": "John Doe",
        "emergency_contact_phone": "+923001234567",
        "has_health_conditions": false,
        "health_conditions": "",
        "allergies": "",
        "medications": ""
    }

    Response (201 Created):
    {
        "success": true,
        "message": "Profile created successfully",
        "profile": {...}
    }
    """
    logger.info("=" * 50)
    logger.info(f"PROFILE CREATION REQUEST START")
    logger.info(f"User: {request.user.email}")
    logger.info(f"Content-Type: {request.content_type}")
    logger.info(f"Request data type: {type(request.data)}")

    try:
        # Log request data
        if hasattr(request.data, 'keys'):
            logger.info(f"Request data keys: {list(request.data.keys())}")
            for key, value in request.data.items():
                logger.info(f"  {key}: {value} (type: {type(value).__name__})")
        else:
            logger.info(f"Request data: {request.data}")
    except Exception as e:
        logger.error(f"Error logging request data: {e}")

    # Check if profile already exists
    try:
        profile = request.user.profile
        logger.warning(f"Profile already exists for user: {request.user.email}")
        return error_response(
            message='Profile already exists. Use update endpoint to modify.',
            status_code=status.HTTP_400_BAD_REQUEST
        )
    except UserProfile.DoesNotExist:
        logger.info("No existing profile found, proceeding with creation")
    except Exception as e:
        logger.error(f"Error checking for existing profile: {e}")

    try:
        serializer = UserProfileCreateSerializer(
            data=request.data,
            context={'request': request}
        )

        if serializer.is_valid():
            logger.info(f"Serializer is valid, creating profile for: {request.user.email}")
            profile = serializer.save()
            logger.info(f"Profile created successfully - User: {request.user.email}, Profile ID: {profile.id}")

            # Serialize the created profile
            profile_serializer = UserProfileSerializer(profile)
            logger.info(f"Profile serialized successfully: {profile_serializer.data}")

            response = success_response(
                message='Profile created successfully.',
                data={'profile': profile_serializer.data},
                status_code=status.HTTP_201_CREATED
            )
            logger.info(f"Returning success response with status 201")
            return response
        else:
            logger.warning(f"Profile creation validation failed for {request.user.email}")
            logger.warning(f"Validation errors: {serializer.errors}")
            return error_response(
                message='Profile creation failed.',
                errors=serializer.errors
            )
    except Exception as e:
        logger.error(f"Unexpected error during profile creation for {request.user.email}: {e}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return error_response(
            message='An unexpected error occurred during profile creation.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
    finally:
        logger.info(f"PROFILE CREATION REQUEST END")
        logger.info("=" * 50)


@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
def profile_update(request):
    """
    Update current user's profile.

    PUT /api/auth/profile/update/
    PATCH /api/auth/profile/update/

    Headers:
    Authorization: Bearer <access_token>

    Request Body (same as create, all fields optional for PATCH):
    {
        "blood_type": "A+",
        "weight": 75,
        "city": "Karachi"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Profile updated successfully",
        "profile": {...}
    }
    """
    try:
        profile = request.user.profile
    except UserProfile.DoesNotExist:
        return error_response(
            message='Profile not found. Please create a profile first.',
            status_code=status.HTTP_404_NOT_FOUND
        )

    partial = request.method == 'PATCH'
    serializer = UserProfileUpdateSerializer(
        profile,
        data=request.data,
        partial=partial,
        context={'request': request}
    )

    if serializer.is_valid():
        profile = serializer.save()
        logger.info(f"Profile updated for user: {request.user.email}")
        return success_response(
            message='Profile updated successfully.',
            data={'profile': UserProfileSerializer(profile).data}
        )

    return error_response(
        message='Profile update failed.',
        errors=serializer.errors
    )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def profile_delete(request):
    """
    Delete current user's profile.

    DELETE /api/auth/profile/delete/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Profile deleted successfully"
    }
    """
    try:
        profile = request.user.profile
        profile.delete()
        logger.info(f"Profile deleted for user: {request.user.email}")
        return success_response(message='Profile deleted successfully.')
    except UserProfile.DoesNotExist:
        return error_response(
            message='Profile not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_user_role(request):
    """
    Update current user's role (donor/patient).

    PATCH /api/auth/profile/update-role/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "role": "donor" or "patient"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Role updated successfully",
        "user": {...}
    }
    """
    logger.info(f"update_user_role called with data: {request.data}")
    new_role = request.data.get('role')

    if not new_role:
        logger.warning("Role is required but not provided")
        return error_response(message='Role is required.')

    # Normalize the role to lowercase and strip whitespace
    new_role = str(new_role).strip().lower()
    logger.info(f"Normalized role value: '{new_role}'")

    if new_role not in ['donor', 'patient']:
        logger.warning(f"Invalid role value: '{new_role}'")
        return error_response(message='Invalid role. Must be "donor" or "patient".')

    try:
        user = request.user
        old_role = user.role

        # Update user role
        user.role = new_role
        user.save()

        logger.info(f"Role updated for user {user.email}: {old_role} -> {new_role}")

        return success_response(
            message=f'Role updated to {new_role.capitalize()} successfully.',
            data={'user': UserSerializer(user).data}
        )
    except Exception as e:
        logger.error(f"Error updating user role: {e}")
        return error_response(
            message='Failed to update role.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_role(request):
    """
    Get current user's role information.

    GET /api/auth/profile/role/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Role retrieved successfully",
        "data": {
            "role": "donor" or "patient" or null,
            "has_role": true/false,
            "can_switch": true,
            "available_roles": ["donor", "patient"]
        }
    }
    """
    try:
        user = request.user

        return success_response(
            message='Role retrieved successfully.',
            data={
                'role': user.role,
                'has_role': user.role is not None,
                'can_switch': True,  # Users can always switch roles
                'available_roles': ['donor', 'patient']
            }
        )
    except Exception as e:
        logger.error(f"Error getting user role: {e}")
        return error_response(
            message='Failed to retrieve role.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def record_donation(request):
    """
    Record a blood donation for the current user.

    POST /api/auth/profile/record-donation/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Donation recorded successfully",
        "profile": {...}
    }
    """
    serializer = DonationRecordSerializer(
        data={},
        context={'request': request}
    )

    if serializer.is_valid():
        profile = serializer.save()
        logger.info(f"Donation recorded for user: {request.user.email}")
        return success_response(
            message='Donation recorded successfully. Thank you for saving lives!',
            data={'profile': UserProfileSerializer(profile).data}
        )

    return error_response(
        message='Failed to record donation.',
        errors=serializer.errors
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_completion(request):
    """
    Get profile completion status for current user.

    GET /api/auth/profile/completion/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Profile completion status retrieved",
        "completion": {
            "percentage": 75,
            "completed": true/false,
            "missing_fields": ["blood_type", "weight"]
        }
    }
    """
    try:
        profile = request.user.profile
        missing_fields = []

        required_fields = {
            'blood_type': 'Blood Type',
            'date_of_birth': 'Date of Birth',
            'gender': 'Gender',
            'weight': 'Weight',
            'address': 'Address',
            'city': 'City',
            'state': 'State',
            'postal_code': 'Postal Code'
        }

        for field, label in required_fields.items():
            if not getattr(profile, field, None):
                missing_fields.append(label)

        return success_response(
            message='Profile completion status retrieved.',
            data={
                'completion': {
                    'percentage': profile.profile_completion_percentage,
                    'completed': profile.profile_completed,
                    'missing_fields': missing_fields
                }
            }
        )
    except UserProfile.DoesNotExist:
        return success_response(
            message='Profile completion status retrieved.',
            data={
                'completion': {
                    'percentage': 0,
                    'completed': False,
                    'missing_fields': [
                        'Blood Type', 'Date of Birth', 'Gender', 'Weight',
                        'Address', 'City', 'State', 'Postal Code'
                    ]
                }
            }
        )


# Forgot Password Views

@api_view(['POST'])
@permission_classes([AllowAny])
def forgot_password(request):
    """
    Send password reset email to user.

    POST /api/auth/forgot-password/

    Request Body:
    {
        "email": "user@example.com"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Password reset link has been sent to your email",
        "data": {
            "email": "user@example.com",
            "token": "uuid-token"  # Only in DEBUG mode
        }
    }
    """
    try:
        serializer = ForgotPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"]

        # Get user (serializer already validated email exists)
        user = CustomUser.objects.get(email=email)

        # Delete any existing unused reset tokens for this user
        PasswordReset.objects.filter(user=user, is_used=False).delete()

        # Create new reset token
        reset = PasswordReset.objects.create(user=user)

        # Log the token for development/testing
        logger.info(f"Password reset requested for {email}: Token = {reset.token}")

        # Send actual email
        try:
            from django.core.mail import send_mail

            # Use deep link scheme for mobile app
            reset_link = f"{settings.APP_DEEP_LINK_SCHEME}://reset-password?email={email}&token={reset.token}"

            subject = "Password Reset Request - Blood Donation System"
            full_name = user.get_full_name()
            message = f"""
Hello {full_name or 'User'},

You recently requested to reset your password for your Blood Donation account.

Click the link below to reset your password:
{reset_link}

This link will expire in 1 hour.

If you're using a mobile device, this will open the Blood Donation app.
If the app doesn't open, make sure you have the app installed.

If you didn't request this password reset, please ignore this email.

Best regards,
Blood Donation Team
"""

            send_mail(
                subject=subject,
                message=message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )

            logger.info(f"Password reset email sent successfully to {email}")

        except Exception as email_error:
            logger.error(f"Failed to send password reset email: {str(email_error)}")

        # Build response data
        response_data = {"email": email}

        # Include token only in development mode for testing
        if settings.DEBUG:
            response_data["token"] = str(reset.token)

        return success_response(
            message="Password reset link has been sent to your email",
            data=response_data,
        )

    except serializers.ValidationError as e:
        logger.warning(f"Forgot password validation failed: {e.detail}")
        return error_response(
            message="Failed to process forgot password request",
            errors=e.detail,
        )

    except Exception as e:
        logger.error(f"Unexpected error during forgot password: {str(e)}", exc_info=True)
        return error_response(
            message="An unexpected error occurred. Please try again later.",
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    """
    Reset user password using reset token.

    POST /api/auth/reset-password/

    Request Body:
    {
        "email": "user@example.com",
        "token": "reset_token_here",
        "new_password": "NewPassword123",
        "confirm_password": "NewPassword123"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Password reset successfully. You can now login with your new password"
    }
    """
    try:
        serializer = ResetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = serializer.validated_data["user"]
        reset = serializer.validated_data["reset"]
        new_password = serializer.validated_data["new_password"]

        # Set new password
        user.set_password(new_password)
        user.save()

        # Mark token as used
        reset.is_used = True
        reset.save()

        # Log password reset
        logger.info(f"Password reset successful for {user.email}")

        return success_response(
            message="Password reset successfully. You can now login with your new password"
        )

    except serializers.ValidationError as e:
        logger.warning(f"Reset password validation failed: {e.detail}")
        return error_response(
            message="Failed to reset password",
            errors=e.detail,
        )

    except Exception as e:
        logger.error(f"Unexpected error during reset password: {str(e)}", exc_info=True)
        return error_response(
            message="An unexpected error occurred. Please try again later.",
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def get_donors(request):
    """
    Get all available donors.

    GET /api/auth/donors/

    Query Params:
    - blood_type: Filter by blood type (optional)
    - city: Filter by city (optional)

    Response (200 OK):
    {
        "success": true,
        "message": "Donors retrieved successfully",
        "donors": [...],
        "count": 10
    }
    """
    try:
        from .models import UserProfile

        # Get query parameters
        blood_type = request.query_params.get('blood_type')
        city = request.query_params.get('city')

        # Base queryset - users with profiles who are available for donation
        # Include all donors (even current user) so they can see themselves when switching roles
        donors_queryset = UserProfile.objects.filter(
            is_available_for_donation=True,
            user__is_active=True
        ).select_related('user').prefetch_related('donation_records')

        # Apply filters
        if blood_type:
            donors_queryset = donors_queryset.filter(blood_group=blood_type)

        if city:
            donors_queryset = donors_queryset.filter(city__iexact=city)

        # Serialize the data
        donors_data = []
        for profile in donors_queryset:
            donor_data = PublicProfileSerializer(profile).data
            # Add additional fields needed for the frontend
            donor_data['id'] = profile.user.id
            donor_data['name'] = profile.user.get_full_name() or profile.user.email.split('@')[0]
            donor_data['email'] = profile.user.email
            donor_data['phone'] = profile.user.phone_num
            donor_data['profile_picture'] = profile.profile_picture_url if profile.profile_picture_url else None
            donor_data['distance'] = '0'  # Will be calculated by frontend
            donor_data['is_online'] = True  # Default to online
            donor_data['last_donation'] = profile.last_donation_date.strftime('%Y-%m-%d') if profile.last_donation_date else None
            donor_data['total_donations'] = profile.total_donations
            donors_data.append(donor_data)

        return success_response(
            message='Donors retrieved successfully.',
            data={
                'donors': donors_data,
                'count': len(donors_data)
            }
        )

    except Exception as e:
        logger.error(f"Error fetching donors: {str(e)}")
        return error_response(
            message='Failed to fetch donors.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def eligibility_check(request):
    """
    Check current user's eligibility for blood donation.

    GET /api/auth/profile/eligibility/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Eligibility status retrieved",
        "eligibility": {
            "is_eligible": true,
            "next_eligible_date": "2025-02-01",
            "days_until_eligible": 30,
            "total_donations": 5,
            "last_donation_date": "2024-12-15"
        }
    }
    """
    try:
        profile = request.user.profile
        profile.check_eligibility()

        days_until = 0
        if profile.next_eligible_date:
            from datetime import date
            delta = profile.next_eligible_date - date.today()
            days_until = max(0, delta.days)

        return success_response(
            message='Eligibility status retrieved.',
            data={
                'eligibility': {
                    'is_eligible': profile.is_eligible,
                    'next_eligible_date': profile.next_eligible_date,
                    'days_until_eligible': days_until,
                    'total_donations': profile.total_donations,
                    'last_donation_date': profile.last_donation_date
                }
            }
        )
    except UserProfile.DoesNotExist:
        return error_response(
            message='Profile not found. Please complete your profile setup first.',
            status_code=status.HTTP_404_NOT_FOUND
        )


# OTP Views

@api_view(['POST'])
@permission_classes([AllowAny])
def send_otp(request):
    """
    Send OTP code to user's phone number.

    POST /api/auth/send-otp/

    Request Body:
    {
        "phone_num": "+1234567890"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "OTP sent successfully",
        "data": {
            "message": "OTP sent to +1234567890",
            "expires_in": 600,
            "phone_num": "+1234567890",
            "otp_code": "123456"
        }
    }
    """
    try:
        phone_num = request.data.get('phone_num')

        if not phone_num:
            return error_response(
                message='Phone number is required.',
                errors={'phone_num': 'This field is required.'}
            )

        # Find user by phone number
        try:
            user = CustomUser.objects.get(phone_num=phone_num)
        except CustomUser.DoesNotExist:
            return error_response(
                message='User with this phone number not found.',
                status_code=status.HTTP_404_NOT_FOUND
            )

        # Check if user can request OTP (resend cooldown)
        can_request, seconds_remaining = user.can_request_otp()
        if not can_request:
            return error_response(
                message=f'Please wait {seconds_remaining} seconds before requesting another OTP.',
                status_code=status.HTTP_429_TOO_MANY_REQUESTS
            )

        # Generate OTP
        otp_code = user.generate_otp()

        logger.info(f"OTP generated for {phone_num}: {otp_code}")

        # Send OTP via SMS (integration would go here)
        # For now, just log it
        # TODO: Integrate with SMS service like Twilio

        response_data = {
            'message': f'OTP sent to {phone_num}',
            'expires_in': 600,  # 10 minutes
            'phone_num': phone_num
        }

        # Include OTP code in development mode
        if settings.DEBUG:
            response_data['otp_code'] = otp_code

        return success_response(
            message='OTP sent successfully.',
            data=response_data
        )

    except Exception as e:
        logger.error(f"Error sending OTP: {str(e)}")
        return error_response(
            message='Failed to send OTP. Please try again.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    """
    Verify OTP code for phone number.

    POST /api/auth/verify-otp/

    Request Body:
    {
        "phone_num": "+1234567890",
        "otp_code": "123456"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Phone verified successfully",
        "data": {
            "user": {
                "id": "uuid",
                "phone_verified": true
            }
        }
    }
    """
    try:
        phone_num = request.data.get('phone_num')
        otp_code = request.data.get('otp_code')

        if not phone_num or not otp_code:
            errors = {}
            if not phone_num:
                errors['phone_num'] = 'This field is required.'
            if not otp_code:
                errors['otp_code'] = 'This field is required.'
            return error_response(
                message='Phone number and OTP code are required.',
                errors=errors
            )

        # Find user by phone number
        try:
            user = CustomUser.objects.get(phone_num=phone_num)
        except CustomUser.DoesNotExist:
            return error_response(
                message='User with this phone number not found.',
                status_code=status.HTTP_404_NOT_FOUND
            )

        # Verify OTP
        success, message = user.verify_otp(otp_code)

        if success:
            return success_response(
                message='Phone verified successfully.',
                data={
                    'user': {
                        'id': str(user.id),
                        'phone_verified': user.phone_verified
                    }
                }
            )
        else:
            return error_response(message=message)

    except Exception as e:
        logger.error(f"Error verifying OTP: {str(e)}")
        return error_response(
            message='Failed to verify OTP. Please try again.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def resend_otp(request):
    """
    Resend OTP code to user's phone number.

    POST /api/auth/resend-otp/

    Request Body:
    {
        "phone_num": "+1234567890"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "OTP sent successfully",
        "data": {
            "message": "OTP sent to +1234567890",
            "expires_in": 600,
            "phone_num": "+1234567890",
            "otp_code": "123456"
        }
    }
    """
    # Resend OTP is same as send OTP
    return send_otp(request)


# Donor Profile Endpoints

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_availability(request):
    """
    Toggle donor's availability status.

    POST /api/donor/profile/toggle-availability/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Availability updated",
        "data": {
            "is_available": false
        }
    }
    """
    try:
        profile = request.user.profile
        profile.is_available_for_donation = not profile.is_available_for_donation
        profile.save(update_fields=['is_available_for_donation'])

        logger.info(f"Availability toggled for {request.user.email}: {profile.is_available_for_donation}")

        return success_response(
            message='Availability updated successfully.',
            data={
                'is_available': profile.is_available_for_donation
            }
        )

    except UserProfile.DoesNotExist:
        return error_response(
            message='Profile not found. Please complete your profile setup first.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error toggling availability: {str(e)}")
        return error_response(
            message='Failed to update availability.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_location(request):
    """
    Update donor's location coordinates.

    PATCH /api/donor/profile/location/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "location_lat": 40.7128,
        "location_lng": -74.0060,
        "address": "123 Street, City"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Location updated successfully",
        "data": {
            "profile": {...}
        }
    }
    """
    try:
        profile = request.user.profile

        # Update location fields
        if 'location_lat' in request.data:
            profile.location_lat = request.data.get('location_lat')
        if 'location_lng' in request.data:
            profile.location_lng = request.data.get('location_lng')
        if 'address' in request.data:
            profile.address = request.data.get('address')
        if 'city' in request.data:
            profile.city = request.data.get('city')
        if 'state' in request.data:
            profile.state = request.data.get('state')
        if 'country' in request.data:
            profile.country = request.data.get('country')
        if 'postal_code' in request.data:
            profile.postal_code = request.data.get('postal_code')

        profile.save()

        logger.info(f"Location updated for {request.user.email}")

        return success_response(
            message='Location updated successfully.',
            data={
                'profile': UserProfileSerializer(profile).data
            }
        )

    except UserProfile.DoesNotExist:
        return error_response(
            message='Profile not found. Please complete your profile setup first.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error updating location: {str(e)}")
        return error_response(
            message='Failed to update location.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def nearby_donors(request):
    """
    Get nearby donors based on location and blood type.

    GET /api/donor/nearby/?blood_type=1&lat=40.7128&lng=-74.0060&radius=50

    Headers:
    Authorization: Bearer <access_token>

    Query Parameters:
    - blood_type (optional) - Filter by blood type ID
    - lat (required) - Latitude
    - lng (required) - Longitude
    - radius (optional) - Radius in km (default: 50)

    Response (200 OK):
    {
        "success": true,
        "message": "Nearby donors found",
        "data": {
            "donors": [...],
            "count": 15
        }
    }
    """
    try:
        from math import radians, cos, sin, sqrt, asin

        # Get query parameters
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        radius = float(request.query_params.get('radius', 50))  # Default 50km
        blood_type = request.query_params.get('blood_type')

        if not lat or not lng:
            return error_response(
                message='Latitude and longitude are required.',
                errors={'lat': 'Required', 'lng': 'Required'}
            )

        try:
            lat = float(lat)
            lng = float(lng)
        except ValueError:
            return error_response(
                message='Invalid coordinates.',
                errors={'lat': 'Must be a number', 'lng': 'Must be a number'}
            )

        # Get all available donors with location
        # Include all donors (even current user) so they can see themselves when switching roles
        donors_queryset = UserProfile.objects.filter(
            is_available_for_donation=True,
            location_lat__isnull=False,
            location_lng__isnull=False,
            user__is_active=True
        ).select_related('user')

        # Filter by blood type if provided
        if blood_type:
            donors_queryset = donors_queryset.filter(blood_group=blood_type)

        nearby_donors = []
        for profile in donors_queryset:
            # Calculate distance using Haversine formula
            lat1 = radians(lat)
            lat2 = radians(float(profile.location_lat))
            lng1 = radians(lng)
            lng2 = radians(float(profile.location_lng))

            dlat = lat2 - lat1
            dlng = lng2 - lng1

            a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlng / 2)**2
            c = 2 * asin(sqrt(a))
            distance_km = 6371 * c  # Earth's radius in km

            if distance_km <= radius:
                donor_data = PublicProfileSerializer(profile).data
                donor_data['id'] = str(profile.user.id)
                donor_data['full_name'] = profile.user.get_full_name()
                donor_data['blood_type'] = profile.blood_group
                donor_data['distance_km'] = round(distance_km, 1)
                donor_data['last_donation_date'] = profile.last_donation_date.strftime('%Y-%m-%d') if profile.last_donation_date else None
                donor_data['is_available'] = profile.is_available_for_donation
                nearby_donors.append(donor_data)

        # Sort by distance
        nearby_donors.sort(key=lambda x: x['distance_km'])

        return success_response(
            message=f'Found {len(nearby_donors)} nearby donors.',
            data={
                'donors': nearby_donors,
                'count': len(nearby_donors)
            }
        )

    except Exception as e:
        logger.error(f"Error fetching nearby donors: {str(e)}")
        return error_response(
            message='Failed to fetch nearby donors.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def donor_profile_detail(request, donor_id):
    """
    Get donor profile by ID (public view).

    GET /api/donor/profile/{id}/

    Headers:
    Authorization: Bearer <access_token>

    Response (200 OK):
    {
        "success": true,
        "message": "Profile retrieved",
        "data": {
            "profile": {...}
        }
    }
    """
    try:
        profile = UserProfile.objects.get(id=donor_id, user__is_active=True)
        serializer = PublicProfileSerializer(profile)

        return success_response(
            message='Profile retrieved successfully.',
            data={
                'profile': serializer.data
            }
        )

    except UserProfile.DoesNotExist:
        return error_response(
            message='Profile not found.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error fetching donor profile: {str(e)}")
        return error_response(
            message='Failed to fetch profile.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def medical_info_update(request):
    """
    Update medical information (medications, allergies, health conditions).

    PATCH /api/profile/update-medical/

    Headers:
    Authorization: Bearer <access_token>

    Request Body:
    {
        "medications": ["Aspirin", "Vitamin D"],
        "allergies": ["Penicillin", "Peanuts"],
        "health_conditions": ["Diabetes Type 2"]
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Medical information updated successfully.",
        "data": {
            "medications": ["Aspirin", "Vitamin D"],
            "allergies": ["Penicillin", "Peanuts"],
            "health_conditions": ["Diabetes Type 2"]
        }
    }
    """
    try:
        profile = request.user.profile
        serializer = MedicalInfoUpdateSerializer(
            profile,
            data=request.data,
            partial=True
        )

        if serializer.is_valid():
            serializer.save()
            return success_response(
                message='Medical information updated successfully.',
                data={'data': serializer.data}
            )
        else:
            return error_response(
                message='Invalid data provided.',
                errors=serializer.errors
            )

    except UserProfile.DoesNotExist:
        return error_response(
            message='Profile not found. Please complete your profile first.',
            status_code=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"Error updating medical info: {str(e)}")
        return error_response(
            message='Failed to update medical information.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_profile_picture(request):
    """
    Upload profile picture for the current user.

    POST /api/auth/profile/upload-picture/

    Headers:
    Authorization: Bearer <access_token>
    Content-Type: multipart/form-data

    Request Body:
    profile_picture: (file) Image file

    Response (200 OK):
    {
        "success": true,
        "message": "Profile picture uploaded successfully",
        "data": {
            "profile_picture_url": "https://example.com/media/profile_pictures/user_123.jpg"
        }
    }
    """
    try:
        if 'profile_picture' not in request.FILES:
            return error_response(
                message='No image file provided.',
                errors={'profile_picture': 'This field is required.'}
            )

        image_file = request.FILES['profile_picture']

        # Validate file size (max 5MB)
        max_size = 5 * 1024 * 1024  # 5MB
        if image_file.size > max_size:
            return error_response(
                message='Image file is too large. Maximum size is 5MB.',
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE
            )

        # Validate file type
        allowed_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
        if image_file.content_type not in allowed_types:
            return error_response(
                message='Invalid file type. Please upload a JPEG, PNG, GIF, or WebP image.',
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE
            )

        # Generate unique filename
        import os
        from django.utils import timezone
        import uuid

        file_extension = os.path.splitext(image_file.name)[1]
        unique_filename = f"profile_{request.user.id}_{uuid.uuid4().hex[:8]}{file_extension}"

        # For now, store the filename as URL (in production, use S3 or similar)
        # You can configure Django's MEDIA_ROOT and MEDIA_URL for local storage
        try:
            from django.core.files.storage import default_storage
            from django.core.files.base import ContentFile

            # Save file
            path = default_storage.save(f'profile_pictures/{unique_filename}', ContentFile(image_file.read()))
            profile_picture_url = default_storage.url(path)

        except Exception as e:
            logger.error(f"Error saving file: {str(e)}")
            # Fallback: just use the filename as a placeholder URL
            profile_picture_url = f"/media/profile_pictures/{unique_filename}"

        # Update user profile with new picture URL
        try:
            profile = request.user.profile
            profile.profile_picture = profile_picture_url
            profile.profile_picture_updated_at = timezone.now()
            profile.save(update_fields=['profile_picture', 'profile_picture_updated_at'])
        except UserProfile.DoesNotExist:
            # Create profile if it doesn't exist
            UserProfile.objects.create(
                user=request.user,
                profile_picture=profile_picture_url,
                profile_picture_updated_at=timezone.now()
            )

        logger.info(f"Profile picture uploaded for {request.user.email}: {profile_picture_url}")

        return success_response(
            message='Profile picture uploaded successfully.',
            data={
                'profile_picture_url': profile_picture_url
            }
        )

    except Exception as e:
        logger.error(f"Error uploading profile picture: {str(e)}")
        return error_response(
            message='Failed to upload profile picture. Please try again.',
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['PUT', 'PATCH'])
@permission_classes([IsAuthenticated])
def update_combined_profile(request):
    """
    Update both user and profile information in a single request.

    PUT /api/auth/profile/update-combined/
    PATCH /api/auth/profile/update-combined/

    Headers:
    Authorization: Bearer <access_token>

    Request Body (all fields optional for PATCH):
    {
        // User fields
        "full_name": "John Updated Doe",
        "phone_num": "+9876543210",

        // Profile fields
        "blood_group": "A+",
        "date_of_birth": "1990-01-01",
        "gender": "male",
        "weight": 75,
        "city": "Karachi",
        "location_lat": 24.8607,
        "location_lng": 67.0011,
        "profile_picture": "https://example.com/image.jpg"
    }

    Response (200 OK):
    {
        "success": true,
        "message": "Profile updated successfully",
        "data": {
            "user": {...},
            "profile": {...}
        }
    }
    """
    try:
        user = request.user
        partial = request.method == 'PATCH'

        # Update user fields
        user_updated = False
        user_fields = ['full_name', 'phone_num']
        for field in user_fields:
            if field in request.data:
                setattr(user, field, request.data.get(field))
                user_updated = True

        if user_updated:
            user.save()

        # Update or create profile
        profile_data = {k: v for k, v in request.data.items() if k not in user_fields}

        try:
            profile = user.profile
        except UserProfile.DoesNotExist:
            profile = UserProfile.objects.create(user=user)

        # Update profile fields
        serializer = UserProfileUpdateSerializer(
            profile,
            data=profile_data,
            partial=partial,
            context={'request': request}
        )

        if serializer.is_valid():
            profile = serializer.save()

            logger.info(f"Combined profile updated for {user.email}")

            return success_response(
                message='Profile updated successfully.',
                data={
                    'user': UserSerializer(user).data,
                    'profile': UserProfileSerializer(profile).data
                }
            )
        else:
            # If profile update fails, we should potentially rollback user changes
            # For now, we'll return the validation errors
            return error_response(
                message='Profile validation failed.',
                errors=serializer.errors
            )

    except Exception as e:
        logger.error(f"Error updating combined profile: {str(e)}")
        return error_response(
            message='Failed to update profile.',
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
        from .fcm_service import validate_fcm_token

        fcm_token = request.data.get('fcm_token')

        if not fcm_token:
            return error_response(
                message='fcm_token is required',
                status_code=status.HTTP_400_BAD_REQUEST
            )

        # Validate token format (basic check)
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

