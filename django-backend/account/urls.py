"""
URL configuration for the account app.

Defines all API endpoints for user authentication and profile management.
"""
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    register,
    login,
    logout,
    profile,
    update_profile,
    change_password,
    forgot_password,
    reset_password,
    profile_detail,
    profile_create,
    profile_update,
    profile_delete,
    update_user_role,
    get_user_role,
    record_donation,
    profile_completion,
    eligibility_check,
    get_donors,
    send_otp,
    verify_otp,
    resend_otp,
    toggle_availability,
    update_location,
    nearby_donors,
    donor_profile_detail,
    medical_info_update,
    upload_profile_picture,
    update_combined_profile,
    update_fcm_token,
)


app_name = 'account'

urlpatterns = [
    # Authentication endpoints
    path('register/', register, name='register'),
    path('login/', login, name='login'),
    path('logout/', logout, name='logout'),

    # Password reset endpoints
    path('forgot-password/', forgot_password, name='forgot_password'),
    path('reset-password/', reset_password, name='reset_password'),

    # Profile management (Basic user profile)
    path('profile/', profile, name='profile'),
    path('profile/update/', update_profile, name='update_profile'),
    path('profile/update-medical/', medical_info_update, name='medical_info_update'),
    path('profile/upload-picture/', upload_profile_picture, name='upload_profile_picture'),
    path('profile/update-combined/', update_combined_profile, name='update_combined_profile'),
    path('change-password/', change_password, name='change_password'),

    # Profile CRUD endpoints (Extended user profile)
    path('profile/detail/', profile_detail, name='profile_detail'),
    path('profile/create/', profile_create, name='profile_create'),
    path('profile/update/full/', profile_update, name='profile_update_full'),
    path('profile/delete/', profile_delete, name='profile_delete'),
    path('profile/role/', get_user_role, name='get_user_role'),
    path('profile/update-role/', update_user_role, name='update_user_role'),
    path('profile/record-donation/', record_donation, name='record_donation'),
    path('profile/completion/', profile_completion, name='profile_completion'),
    path('profile/eligibility/', eligibility_check, name='eligibility_check'),

    # Donors endpoints
    path('donors/', get_donors, name='get_donors'),
    path('donors/nearby/', nearby_donors, name='nearby_donors'),
    path('donors/<uuid:donor_id>/', donor_profile_detail, name='donor_profile_detail'),

    # Donor profile endpoints
    path('donor/toggle-availability/', toggle_availability, name='toggle_availability'),
    path('donor/update-location/', update_location, name='update_location'),

    # OTP endpoints
    path('send-otp/', send_otp, name='send_otp'),
    path('verify-otp/', verify_otp, name='verify_otp'),
    path('resend-otp/', resend_otp, name='resend_otp'),

    # Push notifications
    path('fcm-token/', update_fcm_token, name='update_fcm_token'),

    # JWT token refresh
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('token/', TokenRefreshView.as_view(), name='token_refresh_alt'),
]
