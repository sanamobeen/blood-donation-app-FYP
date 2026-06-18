"""
URL configuration for the blood_types app.

Defines all API endpoints for blood type management.
"""
from django.urls import path
from . import views

app_name = 'blood_types'

urlpatterns = [
    path('', views.blood_type_list, name='blood_type_list'),
    path('<int:type_id>/', views.blood_type_detail, name='blood_type_detail'),
]
