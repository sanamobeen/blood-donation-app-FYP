"""
WebSocket consumers for Chat app.

Phase 9: Real-time messaging via Django Channels.
"""
import json
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone
from .models import Conversation, Message
import logging

logger = logging.getLogger(__name__)


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket consumer for real-time chat.

    Handles:
    - Connection management
    - Message broadcasting
    - Typing indicators
    - Read receipts
    """

    async def connect(self):
        """Handle WebSocket connection."""
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group_name = f'chat_{self.conversation_id}'

        # Verify user is authenticated
        if not self.scope.get('user') or not self.scope['user'].is_authenticated:
            await self.close()
            return

        # Verify user is part of conversation
        if not await self.is_participant():
            await self.close()
            return

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()
        logger.info(f"WebSocket connected for conversation {self.conversation_id}")

    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
        logger.info(f"WebSocket disconnected for conversation {self.conversation_id}")

    async def receive_json(self, content):
        """Receive message from WebSocket."""
        message_type = content.get('type')

        if message_type == 'chat_message':
            await self.handle_chat_message(content)
        elif message_type == 'typing':
            await self.handle_typing(content)
        elif message_type == 'read_receipt':
            await self.handle_read_receipt(content)

    async def handle_chat_message(self, content):
        """Handle incoming chat message."""
        # Save message to database
        message = await self.save_message(
            content.get('content'),
            content.get('message_type', 'text'),
            content.get('location_lat'),
            content.get('location_lng')
        )

        if message:
            # Send to room group
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_message',
                    'message': message
                }
            )

    async def handle_typing(self, content):
        """Handle typing indicator."""
        # Broadcast typing status to room
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'typing_indicator',
                'user': self.scope['user'].email,
                'is_typing': content.get('is_typing', False)
            }
        )

    async def handle_read_receipt(self, content):
        """Handle read receipt."""
        # Mark messages as read in database
        await self.mark_messages_read(content.get('message_ids', []))

    async def chat_message(self, event):
        """Send chat message to WebSocket."""
        await self.send_json(event['message'])

    async def typing_indicator(self, event):
        """Send typing indicator to WebSocket."""
        await self.send_json({
            'type': 'typing',
            'user': event['user'],
            'is_typing': event['is_typing']
        })

    @database_sync_to_async
    def is_participant(self):
        """Check if user is part of conversation."""
        try:
            user = self.scope['user']
            if not user.is_authenticated:
                return False

            conversation = Conversation.objects.get(id=self.conversation_id)
            return conversation.patient == user or conversation.donor == user
        except Conversation.DoesNotExist:
            return False

    @database_sync_to_async
    def save_message(self, content, message_type, location_lat, location_lng):
        """Save message to database."""
        from account.models import CustomUser

        user = self.scope['user']
        try:
            conversation = Conversation.objects.get(id=self.conversation_id)

            # Check if conversation is blocked
            if conversation.blocked_by:
                return None

            message = Message.objects.create(
                conversation=conversation,
                sender=user,
                content=content,
                message_type=message_type,
                location_lat=location_lat,
                location_lng=location_lng
            )

            # Update conversation
            if user == conversation.patient:
                conversation.patient_message_count += 1
            else:
                conversation.donor_message_count += 1
            conversation.last_message_at = timezone.now()
            conversation.save()

            logger.info(f"Message saved via WebSocket: {message.id}")

            return {
                'id': str(message.id),
                'content': message.content,
                'message_type': message.message_type,
                'sender_name': user.full_name or user.email,
                'sender_picture': user.profile.profile_picture.url if user.profile.profile_picture else None,
                'created_at': message.created_at.isoformat(),
            }
        except Exception as e:
            logger.error(f"Error saving message: {e}")
            return None

    @database_sync_to_async
    def mark_messages_read(self, message_ids):
        """Mark messages as read."""
        try:
            Message.objects.filter(
                id__in=message_ids,
                conversation__id=self.conversation_id
            ).exclude(sender=self.scope['user']).update(
                is_read=True,
                read_at=timezone.now()
            )
        except Exception as e:
            logger.error(f"Error marking messages read: {e}")
