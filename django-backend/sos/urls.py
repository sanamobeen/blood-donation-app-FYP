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
    path('my-active/', views.my_active_sos, name='my_active_sos'),
    path('notify-donors/', views.notify_donors, name='notify_donors'),
    path('<uuid:sos_id>/', views.sos_detail, name='sos_detail'),
    path('<uuid:sos_id>/respond/', views.respond_to_sos, name='respond_to_sos'),
    path('<uuid:sos_id>/accept-response/<uuid:response_id>/', views.accept_sos_response, name='accept_sos_response'),
    path('<uuid:sos_id>/reject-response/<uuid:response_id>/', views.reject_sos_response, name='reject_sos_response'),
    path('<uuid:sos_id>/mark-no-show/<uuid:response_id>/', views.mark_no_show, name='mark_no_show'),
    path('<uuid:sos_id>/notify-donor-late/<uuid:response_id>/', views.notify_donor_late, name='notify_donor_late'),
    path('<uuid:sos_id>/donor-cannot-arrive/<uuid:response_id>/', views.donor_cannot_arrive, name='donor_cannot_arrive'),
    path('<uuid:sos_id>/confirm-donation/<uuid:response_id>/', views.confirm_donation, name='confirm_donation'),
    path('<uuid:sos_id>/update-eta/<uuid:response_id>/', views.update_response_eta, name='update_response_eta'),
    path('<uuid:sos_id>/confirm-arrival/<uuid:response_id>/', views.confirm_donor_arrival, name='confirm_donor_arrival'),
    path('<uuid:sos_id>/confirm-on-my-way/<uuid:response_id>/', views.confirm_on_my_way, name='confirm_on_my_way'),
    path('<uuid:sos_id>/resolve/', views.resolve_sos, name='resolve_sos'),
    path('<uuid:sos_id>/cancel/', views.cancel_sos, name='cancel_sos'),
]
