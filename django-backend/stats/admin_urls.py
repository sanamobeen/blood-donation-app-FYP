"""
Admin URL configuration for the stats app.

Defines admin API endpoints for statistics and analytics.
"""
from django.urls import path
from .admin_views import (
    admin_dashboard_stats,
    admin_analytics,
)


app_name = 'stats_admin'

urlpatterns = [
    # Admin statistics endpoints
    path('overview/', admin_dashboard_stats, name='admin_dashboard_stats'),
    path('analytics/', admin_analytics, name='admin_analytics'),
]
