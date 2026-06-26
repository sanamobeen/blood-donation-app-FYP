import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from notifications.models import Notification
from account.models import CustomUser

print("=" * 50)
print("NOTIFICATION SYSTEM TEST")
print("=" * 50)

# Check total notifications
total = Notification.objects.count()
print(f"\nTotal notifications in database: {total}")

# List recent notifications
print("\nRecent notifications:")
for n in Notification.objects.all()[:5]:
    try:
        user_email = n.user.email if n.user else "None"
        title = n.title.encode('ascii', 'ignore').decode('ascii') if n.title else "None"
        print(f"- ID: {n.id}")
        print(f"  User: {user_email}")
        print(f"  Title: {title}")
        print(f"  Type: {n.type}")
        print(f"  Is Read: {n.is_read}")
        print(f"  Created: {n.created_at}")
        print()
    except Exception as e:
        print(f"- Error reading notification: {e}")

# Test creating a notification
print("\n" + "=" * 50)
print("TEST: Creating a notification")
print("=" * 50)

try:
    # Get a test user
    test_user = CustomUser.objects.first()
    if not test_user:
        print("ERROR: No users found in database")
    else:
        print(f"Test user: {test_user.email}")

        # Create a test notification
        new_notification = Notification.objects.create(
            user=test_user,
            title="TEST NOTIFICATION",
            message="This is a test notification created by the test script",
            type="test",
        )
        print(f"SUCCESS: Notification created with ID: {new_notification.id}")

        # Verify it was created
        updated_count = Notification.objects.count()
        print(f"Updated total notifications: {updated_count}")

        # Clean up - delete the test notification
        new_notification.delete()
        print(f"Test notification deleted")
        print(f"Final count: {Notification.objects.count()}")

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 50)
print("NOTIFICATION API TEST")
print("=" * 50)

# Check if notification views are accessible
try:
    from notifications.views import list_notifications, send_push_notification
    print("SUCCESS: Notification views are accessible")
except Exception as e:
    print(f"ERROR: Cannot import notification views: {e}")

print("\nTest complete!")
