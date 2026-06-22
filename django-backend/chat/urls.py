"""
URL configuration for Chat app.

Phase 8: Chat endpoints with safety controls.
"""
from django.urls import path
from . import views

app_name = 'chat'

urlpatterns = [
    # Conversation endpoints
    path('conversations/create/', views.create_conversation, name='create_conversation'),
    path('conversations/', views.get_conversations, name='get_conversations'),
    path('conversations/<uuid:conversation_id>/messages/', views.get_messages, name='get_messages'),
    path('conversations/<uuid:conversation_id>/send/', views.send_message, name='send_message'),
    path('conversations/<uuid:conversation_id>/block/', views.block_conversation, name='block_conversation'),

    # Message endpoints
    path('messages/<uuid:message_id>/report/', views.report_message, name='report_message'),

    # Block management
    path('unblock/', views.unblock_user, name='unblock_user'),

    # Unread count endpoint
    path('unread-count/', views.unread_count, name='unread_count'),
]
