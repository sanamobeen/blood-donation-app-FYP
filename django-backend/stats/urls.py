"""
URL configuration for the statistics app.

Defines all API endpoints for statistics.
"""
from django.urls import path
from . import views

app_name = 'stats'

urlpatterns = [
    # Statistics endpoints
    path('public/', views.public_stats, name='public_stats'),
    path('user/', views.user_stats, name='user_stats'),
]
