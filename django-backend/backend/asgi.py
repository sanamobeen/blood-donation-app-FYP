"""
ASGI config for Blood Donation Backend with WebSocket support.

This configuration enables real-time communication via WebSockets
using Django Channels.
"""
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

# Initialize Django ASGI application
django_asgi_app = get_asgi_application()

# Import WebSocket routing for chat
from chat.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # HTTP requests go to Django
    "http": django_asgi_app,

    # WebSocket requests go to Channels
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
