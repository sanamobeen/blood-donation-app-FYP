"""
URL configuration for the donations app.

Defines all API endpoints for donation management.
"""
from django.urls import path
from . import views

app_name = 'donations'

urlpatterns = [
    # Donation endpoints
    path('my/', views.my_donations, name='my_donations'),
    path('', views.create_donation, name='create_donation'),
    path('stats/', views.donation_stats, name='donation_stats'),
    path('request-responses/<uuid:request_id>/', views.blood_request_responses, name='blood_request_responses'),
    path('<uuid:donation_id>/', views.donation_detail, name='donation_detail'),
    path('<uuid:donation_id>/acknowledge', views.acknowledge_donation, name='acknowledge_donation'),
]
