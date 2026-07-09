import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from account.models import CustomUser
from blood_requests.models import BloodRequest, DonorResponse
from notifications.models import Notification

print("=" * 50)
print("INTERNAL DONOR NOTIFICATION TEST")
print("=" * 50)

# Get users
users = CustomUser.objects.all()
print(f"\nTotal users: {users.count()}")
for u in users:
    print(f"- {u.email} (ID: {u.id})")

# Get blood requests
requests = BloodRequest.objects.all()
print(f"\nTotal blood requests: {requests.count()}")
for r in requests:
    print(f"- Request: {r.patient_name}, Created by: {r.requested_by.email if r.requested_by else 'None'}")

# Get pledges
pledges = DonorResponse.objects.all()
print(f"\nTotal pledges: {pledges.count()}")
for p in pledges:
    donor_email = p.donor.email if p.donor else "External"
    print(f"- Pledge: {p.id}, Donor: {donor_email}, Status: {p.status}")

# Check notifications for internal pledges
print("\n" + "=" * 50)
print("NOTIFICATIONS BY TYPE")
print("=" * 50)

internal_pledge_notifs = Notification.objects.filter(type='new_pledge')
external_pledge_notifs = Notification.objects.filter(type='external_pledge')

print(f"\nInternal pledge notifications: {internal_pledge_notifs.count()}")
for n in internal_pledge_notifs:
    print(f"- ID: {n.id}, User: {n.user.email}, Created: {n.created_at}")

print(f"\nExternal pledge notifications: {external_pledge_notifs.count()}")
for n in external_pledge_notifs:
    print(f"- ID: {n.id}, User: {n.user.email}, Created: {n.created_at}")

# Test internal pledge notification creation
print("\n" + "=" * 50)
print("SIMULATING INTERNAL PLEDGE NOTIFICATION")
print("=" * 50)

try:
    # Get a blood request and donor
    blood_request = BloodRequest.objects.first()
    donor_user = CustomUser.objects.exclude(id=blood_request.requested_by.id).first() if blood_request else None

    if not blood_request:
        print("ERROR: No blood requests found")
    elif not donor_user:
        print("ERROR: Need at least 2 users to test internal pledge")
    else:
        print(f"Blood request: {blood_request.patient_name}")
        print(f"Requester: {blood_request.requested_by.email}")
        print(f"Test donor: {donor_user.email}")

        # Test the notification creation function
        from notifications.views import send_push_notification

        notification = send_push_notification(
            user=blood_request.requested_by,
            title='TEST: Internal Pledge Received!',
            message=f'{donor_user.email} has pledged to donate {blood_request.blood_group} blood.',
            notif_type='new_pledge',
            data={
                'request_id': str(blood_request.id),
                'pledge_id': 'test-pledge-id',
            },
            send_push=False  # Don't send FCM for test
        )

        print(f"SUCCESS: Internal pledge notification created")
        print(f"Notification ID: {notification.id}")
        print(f"User: {notification.user.email}")
        print(f"Title: {notification.title}")

        # Verify it exists
        new_count = Notification.objects.filter(type='new_pledge').count()
        print(f"Total internal pledge notifications: {new_count}")

        # Clean up - delete test notification
        notification.delete()
        print(f"Test notification deleted")

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()

print("\nTest complete!")
