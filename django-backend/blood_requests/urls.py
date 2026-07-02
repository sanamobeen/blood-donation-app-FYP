"""
URL configuration for the blood_requests app.

Defines all API endpoints for blood request management.
"""
from django.urls import path
from . import views

app_name = 'blood_requests'

urlpatterns = [
    # Blood request endpoints
    path('', views.blood_request_list, name='blood_request_list'),
    path('create/', views.blood_request_create, name='blood_request_create'),
    path('my-requests/', views.my_blood_requests, name='my_blood_requests'),
    path('nearby/', views.nearby_blood_requests, name='nearby_blood_requests'),
    path('<uuid:request_id>/', views.blood_request_detail, name='blood_request_detail'),
    path('<uuid:request_id>/update/', views.blood_request_update, name='blood_request_update'),
    path('<uuid:request_id>/delete/', views.blood_request_delete, name='blood_request_delete'),
    path('<uuid:request_id>/cancel/', views.blood_request_cancel, name='blood_request_cancel'),

    # Pledge/Donor response endpoints
    path('<uuid:request_id>/pledge/', views.create_pledge, name='create_pledge'),
    path('<uuid:request_id>/pledges/', views.get_request_pledges, name='get_pledges'),
    path('<uuid:request_id>/pledges/patient/', views.get_pledged_donors_for_patient, name='get_pledged_donors_for_patient'),
    path('<uuid:request_id>/pledges/<uuid:pledge_id>/accept/', views.accept_pledge, name='accept_pledge'),
    path('<uuid:request_id>/pledges/<uuid:pledge_id>/reject/', views.reject_pledge, name='reject_pledge'),
    path('<uuid:request_id>/pledges/<uuid:pledge_id>/confirm-donation/', views.confirm_donation, name='confirm_donation'),
    path('<uuid:request_id>/pledges/<uuid:pledge_id>/complete/', views.complete_pledge_donation, name='complete_pledge_donation'),
    path('<uuid:request_id>/pledges/accept-batch/', views.accept_pledges_batch, name='accept_pledges_batch'),
    path('<uuid:request_id>/progress/', views.get_request_progress, name='get_progress'),
    path('pledges/<uuid:pledge_id>/cancel/', views.cancel_pledge, name='cancel_pledge'),
    path('donor-eligibility/', views.donor_eligibility_status, name='donor_eligibility'),

    # Donor's pledges management
    path('my-pledges/', views.get_my_pledges, name='get_my_pledges'),

    # Patient: Get all responding donors for their requests
    path('responding-donors/', views.get_responding_donors_for_patient, name='get_responding_donors_for_patient'),

    # Phase 5: Donation status tracking
    path('pledges/<uuid:pledge_id>/status/', views.update_pledge_status, name='update_pledge_status'),

    # Phase 6: No-show reporting
    path('<uuid:request_id>/pledges/<uuid:pledge_id>/no-show/', views.report_no_show, name='report_no_show'),

    # Phase 7: Pre-donation verification
    path('pledges/<uuid:pledge_id>/verify/', views.verify_pledge, name='verify_pledge'),

    # External Pledge System (Web-based public sharing)
    path('by-share/<str:share_id>/', views.get_blood_request_by_share_id, name='get_by_share_id'),
]

# Public web page URLs (served at root level, not under /api/)
public_urlpatterns = [
    path('request/<str:share_id>/', views.public_blood_request_page, name='public_request_page'),
    path('api/external-pledge/', views.create_external_pledge, name='external_pledge_api'),
    path('api/external-pledge-status/<uuid:pledge_id>/', views.external_pledge_status, name='external_pledge_status_api'),
    path('api/request-progress/<str:share_id>/', views.public_request_progress_api, name='request_progress_api'),
]

# Admin URLs - imported in backend/urls.py
admin_urlpatterns = [
    path('', views.admin_blood_requests_list, name='admin_blood_requests_list'),
    path('<uuid:request_id>/', views.admin_blood_request_detail, name='admin_blood_request_detail'),
]
