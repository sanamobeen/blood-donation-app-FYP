"""
WebSocket routing for Chat app.

Phase 9: WebSocket URL patterns for real-time messaging.
"""
from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'^ws/chat/(?P<conversation_id>[^/]+)/$', consumers.ChatConsumer.as_asgi()),
]
