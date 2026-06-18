"""
Admin URL configuration for the blood_requests app.

Defines admin API endpoints for blood request management.
"""
from django.urls import path
from .views import admin_blood_requests_list, admin_blood_request_detail


app_name = 'blood_requests_admin'

urlpatterns = [
    # Admin blood request management endpoints
    path('', admin_blood_requests_list, name='admin_blood_requests_list'),
    path('<uuid:request_id>/', admin_blood_request_detail, name='admin_blood_request_detail'),
]
