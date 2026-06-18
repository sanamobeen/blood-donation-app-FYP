# Notification System Implementation Plan

## Overview
This document outlines the implementation plan for a comprehensive notification system for the Blood Donation Django backend application. The plan ensures **zero breaking changes** to existing functionality while adding new capabilities.

## Current State Analysis

### Existing Infrastructure ✅
- **Models**: `DeviceToken`, `Notification`
- **FCM Service**: `fcm_service.py` with push notification capabilities
- **SOS Notifications**: Signal-based notifications for SOS events
- **Partial Blood Request Notifications**: Ad-hoc notification calls in `blood_requests/views.py`
- **Chat System**: WebSocket-based real-time messaging

### Missing Features ❌
1. No endpoint to list user notifications
2. No endpoint to mark notifications as read
3. No endpoint to get unread count
4. No WebSocket consumer for real-time notification delivery
5. No notification preferences system
6. No centralized notification service
7. No notification templates
8. No notification aggregation/batching

---

## Implementation Plan

### Phase 1: Core Notification API Endpoints (Day 1)

#### 1.1 Create Notification Views
**File**: `django-backend/notifications/views.py` (extend existing)

**New Endpoints**:
```python
# GET /api/notifications/
# List notifications for authenticated user with pagination
def list_notifications(request)

# POST /api/notifications/{notification_id}/read/
# Mark a single notification as read
def mark_notification_read(request, notification_id)

# POST /api/notifications/mark-all-read/
# Mark all notifications as read for user
def mark_all_notifications_read(request)

# POST /api/notifications/{notification_id}/dismiss/
# Dismiss/notification without marking as read
def dismiss_notification(request, notification_id)

# GET /api/notifications/unread-count/
# Get count of unread notifications
def get_unread_count(request)

# DELETE /api/notifications/{notification_id}/
# Delete a notification
def delete_notification(request, notification_id)
```

#### 1.2 Create Notification Serializers
**File**: `django-backend/notifications/serializers.py` (extend existing)

```python
class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for Notification model with related data."""
    
class NotificationListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for list views."""
    
class UnreadCountSerializer(serializers.Serializer):
    """Serializer for unread count response."""
```

#### 1.3 Update URL Configuration
**File**: `django-backend/notifications/urls.py`

```python
urlpatterns = [
    # Existing token endpoints...
    
    # Notification management
    path('', views.list_notifications, name='list_notifications'),
    path('<uuid:notification_id>/read/', views.mark_notification_read, name='mark_read'),
    path('mark-all-read/', views.mark_all_notifications_read, name='mark_all_read'),
    path('<uuid:notification_id>/dismiss/', views.dismiss_notification, name='dismiss'),
    path('unread-count/', views.get_unread_count, name='unread_count'),
    path('<uuid:notification_id>/delete/', views.delete_notification, name='delete'),
]
```

---

### Phase 2: Centralized Notification Service (Day 2)

#### 2.1 Create Notification Service
**File**: `django-backend/notifications/services/notification_service.py`

**Purpose**: Centralize all notification creation logic

```python
class NotificationService:
    """Centralized notification creation and management."""
    
    @staticmethod
    def create_notification(user, title, message, type, **kwargs)
    
    @staticmethod
    def create_and_send_notification(user, title, message, type, **kwargs)
    
    @staticmethod
    def bulk_create_notifications(users, title, message, type, **kwargs)
    
    # Convenience methods for common notification types
    @staticmethod
    def notify_pledge_confirmed(pledge)
    @staticmethod
    def notify_pledge_rejected(pledge)
    @staticmethod
    def notify_donation_confirmed(pledge)
    @staticmethod
    def notify_donation_status_update(pledge, status)
    @staticmethod
    def notify_new_pledge(request, pledge)
    @staticmethod
    def notify_message_received(conversation, message)
    @staticmethod
    def notify_no_show_reported(pledge)
    @staticmethod
    def notify_blood_request_created(request)
```

#### 2.2 Create Notification Templates
**File**: `django-backend/notifications/services/templates.py`

```python
NOTIFICATION_TEMPLATES = {
    'pledge_confirmed': {
        'title': 'Your Pledge Has Been Confirmed!',
        'message_template': '{patient_name} has confirmed your pledge to donate {blood_group} blood. Chat is now open.',
        'type': 'pledge_confirmed'
    },
    'pledge_rejected': {
        'title': 'Pledge Update',
        'message_template': 'The patient has reviewed your pledge for {blood_group} blood. Thank you for your willingness to help.',
        'type': 'pledge_rejected'
    },
    # ... more templates
}
```

---

### Phase 3: WebSocket Consumer for Real-time Notifications (Day 3)

#### 3.1 Create Notification Consumer
**File**: `django-backend/notifications/consumers.py`

```python
class NotificationConsumer(AsyncJsonWebsocketConsumer):
    """WebSocket consumer for real-time notification delivery."""
    
    async def connect(self):
        """Connect user to personal notification channel."""
        
    async def disconnect(self, close_code):
        """Disconnect from notification channel."""
        
    async def notify(self, event):
        """Send notification to connected client."""
```

#### 3.2 Update Routing
**File**: `django-backend/notifications/routing.py`

```python
websocket_urlpatterns = [
    re_path(r'ws/notifications/$', NotificationConsumer.as_asgi()),
]
```

#### 3.3 Update Project Routing
**File**: `django-backend/backend/routing.py`

```python
from channels.routing import URLRouter
from django.urls import re_path
import notifications.routing

websocket_urlpatterns = [
    # Existing chat routes...
    re_path(r'ws/notifications/', URLRouter(notifications.routing.websocket_urlpatterns)),
]
```

---

### Phase 4: Notification Preferences System (Day 4)

#### 4.1 Create Notification Preferences Model
**File**: `django-backend/notifications/models.py` (extend existing)

```python
class NotificationPreference(models.Model):
    """User notification preferences by category."""
    
    user = models.OneToOneField(CustomUser, ...)
    
    # Preferences by notification type
    enable_pledge_updates = models.BooleanField(default=True)
    enable_message_notifications = models.BooleanField(default=True)
    enable_request_updates = models.BooleanField(default=True)
    enable_promotional = models.BooleanField(default=False)
    enable_urgency_alerts = models.BooleanField(default=True)
    
    # Delivery preferences
    enable_push = models.BooleanField(default=True)
    enable_email = models.BooleanField(default=False)
    enable_sms = models.BooleanField(default=False)
    quiet_hours_start = models.TimeField(null=True, blank=True)
    quiet_hours_end = models.TimeField(null=True, blank=True)
```

#### 4.2 Create Preference Management Endpoints
**File**: `django-backend/notifications/views.py`

```python
# GET /api/notifications/preferences/
def get_preferences(request)

# PUT /api/notifications/preferences/
def update_preferences(request)

# GET /api/notifications/preferences/categories/
def get_preference_categories(request)
```

---

### Phase 5: Refactor Existing Notification Calls (Day 5)

#### 5.1 Update Blood Request Views
**File**: `django-backend/blood_requests/views.py`

Replace ad-hoc notification creation with centralized service:

**Before**:
```python
from notifications.models import Notification
Notification.objects.create(
    user=pledge.donor,
    title='Your Pledge Has Been Confirmed!',
    ...
)
```

**After**:
```python
from notifications.services.notification_service import notification_service
notification_service.notify_pledge_confirmed(pledge)
```

#### 5.2 Create Signal Handlers for Blood Requests
**File**: `django-backend/notifications/signals.py` (extend existing)

```python
@receiver(post_save, sender=DonorResponse)
def on_pledge_created(sender, instance, created, **kwargs):
    """Notify patient when new pledge is created."""
    
@receiver(pre_save, sender=DonorResponse)
def on_pledge_status_changed(sender, instance, **kwargs):
    """Notify relevant parties on pledge status change."""
```

---

### Phase 6: Enhanced FCM Service Features (Day 6)

#### 6.1 Add Notification Priority Logic
**File**: `django-backend/notifications/services/fcm_service.py`

```python
def send_notification_with_priority(user, title, body, data, priority='normal'):
    """Send notification with priority handling."""
    
def send_silent_notification(user, data):
    """Send silent data-only notification."""
```

#### 6.2 Add Notification Batching
**File**: `django-backend/notifications/services/batch_service.py`

```python
class NotificationBatcher:
    """Batch notifications to reduce API calls."""
    
    @staticmethod
    def queue_notification(user, notification_data)
    
    @staticmethod
    def flush_queue()
```

---

### Phase 7: Testing & Documentation (Day 7)

#### 7.1 Create API Tests
**File**: `django-backend/notifications/tests.py`

```python
class NotificationAPITestCase(TestCase):
    """Test notification API endpoints."""
    
    def test_list_notifications(self)
    def test_mark_as_read(self)
    def test_unread_count(self)
    def test_notification_preferences(self)
    
class NotificationServiceTestCase(TestCase):
    """Test notification service."""
    
    def test_create_and_send(self)
    def test_convenience_methods(self)
```

#### 7.2 Update API Documentation
**File**: `django-backend/notifications/API_DOCUMENTATION.md`

Document all endpoints with:
- Request/response examples
- Authentication requirements
- Error scenarios

---

## Database Migrations Required

### New Models
1. `NotificationPreference` model

### No Schema Changes Required For
- ✅ `Notification` model (already exists)
- ✅ `DeviceToken` model (already exists)

---

## Backward Compatibility Guarantees

### Existing Features That Will NOT Change
1. ✅ Existing notification creation in `blood_requests/views.py` will continue to work
2. ✅ Existing FCM service methods will remain unchanged
3. ✅ Existing SOS notification signals will continue to work
4. ✅ Chat WebSocket functionality will not be affected
5. ✅ All existing API endpoints will function identically

### Migration Strategy
1. **Phase 1-3**: Add new features alongside existing code
2. **Phase 5**: Gradually refactor existing code (non-breaking)
3. **Old code paths remain functional** during transition

---

## Notification Types

### For Donors
| Type | Trigger | Template |
|------|---------|----------|
| `pledge_confirmed` | Patient confirms pledge | "Your pledge to donate {blood_group} has been confirmed" |
| `pledge_rejected` | Patient rejects pledge | "The patient has reviewed your pledge..." |
| `donation_confirmed` | Donation completed | "Thank you for donating!" |
| `new_request_nearby` | New request in vicinity | "New {blood_group} blood request nearby" |
| `reminder_donate` | Eligible to donate again | "You're eligible to donate again!" |
| `no_show_reported` | Patient reports no-show | "No-show has been reported" |

### For Patients
| Type | Trigger | Template |
|------|---------|----------|
| `new_pledge` | Donor pledges to request | "{donor_name} pledged to donate" |
| `donation_on_way` | Donor en route | "Donor is on the way" |
| `donation_arrived` | Donor arrived | "Donor has arrived" |
| `request_expiring` | Request about to expire | "Your request expires in {hours}h" |
| `pledge_cancelled` | Donor cancels pledge | "A donor cancelled their pledge" |
| `message_received` | New chat message | "{name} sent you a message" |

---

## API Endpoint Summary

### Notification Management
```
GET    /api/notifications/                      List notifications
GET    /api/notifications/unread-count/        Get unread count
POST   /api/notifications/{id}/read/           Mark as read
POST   /api/notifications/mark-all-read/       Mark all as read
POST   /api/notifications/{id}/dismiss/        Dismiss notification
DELETE /api/notifications/{id}/                Delete notification
```

### Preferences
```
GET    /api/notifications/preferences/          Get preferences
PUT    /api/notifications/preferences/          Update preferences
GET    /api/notifications/preferences/categories/ Get categories
```

### Device Tokens (Existing)
```
POST   /api/notifications/register-token/      Register device
GET    /api/notifications/tokens/              List tokens
DELETE /api/notifications/token/{id}/          Delete token
POST   /api/notifications/deactivate-all/      Deactivate all
POST   /api/notifications/test/               Test notification
```

### WebSocket
```
WS     /ws/notifications/                      Real-time notifications
```

---

## Success Metrics

### Technical Metrics
- ✅ All existing notification calls remain functional
- ✅ Zero API breaking changes
- ✅ WebSocket connection reliability > 99%
- ✅ Notification delivery success rate > 95%

### User Experience Metrics
- Reduced notification latency (real-time via WebSocket)
- Better notification organization with categories
- User control over notification preferences
- Improved notification clarity with templates

---

## Risk Mitigation

### Potential Issues & Solutions

| Risk | Mitigation |
|------|------------|
| Breaking existing notifications | Keep old code paths, add new ones |
| WebSocket scaling | Use Redis channel layers |
| FCM quota exceeded | Implement batching/queueing |
| Notification spam | Add rate limiting, preferences |
| Database load on notifications | Add indexes, pagination |

---

## Implementation Checklist

### Phase 1: Core API
- [ ] Create `list_notifications()` view
- [ ] Create `mark_notification_read()` view
- [ ] Create `mark_all_notifications_read()` view
- [ ] Create `dismiss_notification()` view
- [ ] Create `get_unread_count()` view
- [ ] Create `delete_notification()` view
- [ ] Create serializers
- [ ] Update URLs
- [ ] Add API tests

### Phase 2: Centralized Service
- [ ] Create `notification_service.py`
- [ ] Create convenience methods
- [ ] Create `templates.py`
- [ ] Add service tests

### Phase 3: Real-time WebSocket
- [ ] Create `NotificationConsumer`
- [ ] Create `routing.py`
- [ ] Update project routing
- [ ] Add consumer tests

### Phase 4: Preferences
- [ ] Create `NotificationPreference` model
- [ ] Create migration
- [ ] Create preference views
- [ ] Add preference tests

### Phase 5: Refactor
- [ ] Update `blood_requests/views.py`
- [ ] Create signal handlers
- [ ] Add integration tests

### Phase 6: FCM Enhancements
- [ ] Add priority logic
- [ ] Add batching service
- [ ] Add queue management

### Phase 7: Documentation
- [ ] Write API documentation
- [ ] Update README
- [ ] Create usage examples

---

## Flutter Integration Notes

### Payload Structure for Push Notifications

```json
{
  "notification": {
    "title": "Your Pledge Has Been Confirmed!",
    "body": "John Doe has confirmed your pledge to donate A+ blood.",
    "image": "https://example.com/icon.png"
  },
  "data": {
    "type": "pledge_confirmed",
    "request_id": "uuid",
    "pledge_id": "uuid",
    "conversation_id": "uuid",
    "deep_link": "blooddonation://conversation/uuid"
  }
}
```

### Flutter Handler
```dart
void _handleNotificationMessage(RemoteMessage message) {
  final type = message.data['type'];
  
  switch (type) {
    case 'pledge_confirmed':
      Navigator.push(context, ConversationPageRoute(
        conversationId: message.data['conversation_id'],
      ));
      break;
    // ... more cases
  }
}
```

---

## Next Steps

1. **Review this plan** and confirm requirements
2. **Prioritize phases** based on business needs
3. **Begin implementation** with Phase 1
4. **Test each phase** before moving to next
5. **Monitor performance** after deployment

---

*Last Updated: 2025-01-14*
*Status: Ready for Implementation*
