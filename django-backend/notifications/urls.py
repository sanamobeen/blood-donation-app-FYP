"""
URL configuration for the notifications app.
"""
from django.urls import path
from . import views


app_name = 'notifications'

urlpatterns = [
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
]
