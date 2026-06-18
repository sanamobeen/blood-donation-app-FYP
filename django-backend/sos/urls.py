"""
URL configuration for the SOS (Emergency) app.

Defines all API endpoints for emergency blood request management.
"""
from django.urls import path
from . import views

app_name = 'sos'

urlpatterns = [
    # SOS endpoints
    path('', views.create_sos, name='create_sos'),
    path('active/', views.list_active_sos, name='list_active_sos'),
    path('notify-donors/', views.notify_donors, name='notify_donors'),
    path('<uuid:sos_id>/', views.sos_detail, name='sos_detail'),
    path('<uuid:sos_id>/respond/', views.respond_to_sos, name='respond_to_sos'),
    path('<uuid:sos_id>/resolve/', views.resolve_sos, name='resolve_sos'),
    path('<uuid:sos_id>/cancel/', views.cancel_sos, name='cancel_sos'),
]
