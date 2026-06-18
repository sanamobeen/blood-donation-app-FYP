"""
Admin URL configuration for the account app.

Defines admin API endpoints for user management.
"""
from django.urls import path
from .admin_views import (
    admin_list_users,
    admin_user_detail,
    admin_activate_user,
    admin_deactivate_user,
    admin_delete_user,
)


app_name = 'account_admin'

urlpatterns = [
    # Admin user management endpoints
    path('users/', admin_list_users, name='admin_list_users'),
    path('users/<uuid:user_id>/', admin_user_detail, name='admin_user_detail'),
    path('users/<uuid:user_id>/activate/', admin_activate_user, name='admin_activate_user'),
    path('users/<uuid:user_id>/deactivate/', admin_deactivate_user, name='admin_deactivate_user'),
]
