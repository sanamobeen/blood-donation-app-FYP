"""
URL configuration for the notifications app.
"""
from django.urls import path
from . import views


app_name = 'notifications'

urlpatterns = [
    # ================================
    # Device Token Management
    # ================================
    # Token registration
    path('register-token/', views.register_device_token, name='register_token'),

    # List user's tokens
    path('tokens/', views.list_user_tokens, name='list_tokens'),

    # Delete specific token
    path('token/<str:token_id>/', views.delete_device_token, name='delete_token'),

    # Deactivate all tokens (useful for logout)
    path('deactivate-all/', views.deactivate_all_tokens, name='deactivate_all'),

    # Test notification
    path('test/', views.test_notification, name='test_notification'),

    # ================================
    # Notification Management
    # ================================
    # List all notifications
    path('', views.list_notifications, name='list_notifications'),

    # Get unread count
    path('unread-count/', views.unread_count, name='unread_count'),

    # Mark notification as read
    path('<uuid:notification_id>/mark-read/', views.mark_notification_read, name='mark_read'),

    # Mark all as read
    path('mark-all-read/', views.mark_all_read, name='mark_all_read'),
]
