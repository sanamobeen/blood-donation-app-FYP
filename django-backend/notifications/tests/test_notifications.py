"""
Test script for SOS notification functions.
Run with: python manage.py shell < test_notifications.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_donation.settings')
django.setup()

from django.utils import timezone
from sos.models import SOSRequest, SOSResponse
from account.models import CustomUser

print("=" * 60)
print("SOS Notification Testing Script")
print("=" * 60)

# Get test users
patient = CustomUser.objects.filter(role='patient').first()
donor = CustomUser.objects.filter(role='donor').first()

if not patient or not donor:
    print("❌ ERROR: Need at least one patient and one donor in the database")
    print("Create them first using Django admin or shell")
    exit(1)

print(f"\n👤 Patient: {patient.email}")
print(f"👤 Donor: {donor.email}")

# Create test SOS request
sos = SOSRequest.objects.create(
    requester=patient,
    blood_type='O+',
    patient_name='Test Patient',
    age=30,
    gender='male',
    hospital_name='Test Hospital',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=2,
    urgency='critical',
    status='active'
)
print(f"\n✅ Step 1: SOS Request created")
print(f"   ID: {sos.id}")
print(f"   Status: {sos.status}")

# Create donor response
response = SOSResponse.objects.create(
    sos_request=sos,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=30,
    note="On my way!",
    status='pending'
)
print(f"\n✅ Step 2: Donor Response created")
print(f"   Response ID: {response.id}")
print(f"   ETA: {response.estimated_arrival_minutes} minutes")

# Test 1: Patient accepts donor - should notify donor
print(f"\n📧 Test 1: Patient accepts donor (notifies donor)...")
response.status = 'accepted'
response.accepted_at = timezone.now()
response.save()

try:
    from notifications.services.fcm_service import notify_donor_sos_accepted
    notify_donor_sos_accepted(response)
    print("✅ Acceptance notification sent to donor")
except Exception as e:
    print(f"❌ Error: {e}")

# Test 2: Donor updates ETA - should notify patient
print(f"\n📧 Test 2: Donor updates ETA (notifies patient)...")
try:
    from notifications.services.fcm_service import notify_patient_eta_update
    notify_patient_eta_update(response, 15)
    print("✅ ETA update notification sent to patient")
except Exception as e:
    print(f"❌ Error: {e}")

# Test 3: Donor running late - should notify patient
print(f"\n📧 Test 3: Donor running late (notifies patient)...")
try:
    from notifications.services.fcm_service import notify_patient_donor_running_late
    notify_patient_donor_running_late(response, 20, 10)
    print("✅ Running late notification sent to patient")
except Exception as e:
    print(f"❌ Error: {e}")

# Test 4: Donor arrives - should notify patient
print(f"\n📧 Test 4: Donor confirms arrival (notifies patient)...")
try:
    from notifications.services.fcm_service import notify_patient_donor_arrived
    notify_patient_donor_arrived(response)
    print("✅ Arrival notification sent to patient")
except Exception as e:
    print(f"❌ Error: {e}")

# Test 5: Donation confirmed - should notify donor
print(f"\n📧 Test 5: Patient confirms donation (notifies donor)...")
response.status = 'donated'
response.donated_at = timezone.now()
response.save()

try:
    from notifications.services.fcm_service import notify_donor_donation_confirmed
    notify_donor_donation_confirmed(response)
    print("✅ Donation confirmation notification sent to donor")
except Exception as e:
    print(f"❌ Error: {e}")

# Test 6: Response rejected
print(f"\n📧 Test 6: Patient rejects response (notifies donor)...")
response2 = SOSResponse.objects.create(
    sos_request=sos,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=45,
    status='pending'
)

try:
    from notifications.services.fcm_service import notify_donor_response_rejected
    notify_donor_response_rejected(response2)
    print("✅ Rejection notification sent to donor")
except Exception as e:
    print(f"❌ Error: {e}")

# Check created notifications
print(f"\n📬 Notifications created in database:")
from notifications.models import Notification
notifications = Notification.objects.filter(
    related_request_id=str(sos.id)
).order_by('-created_at')

for notif in notifications:
    print(f"\n  • To: {notif.user.email}")
    print(f"    Title: {notif.title}")
    print(f"    Type: {notif.type}")
    print(f"    Message: {notif.message}")

print(f"\n{'=' * 60}")
print(f"Testing Complete!")
print(f"Total notifications created: {notifications.count()}")
print(f"{'=' * 60}")

# Optional: Cleanup
print(f"\n💡 Cleanup: Delete test data? (sos.id = {sos.id})")
print(f"   Run: SOSRequest.objects.filter(id='{sos.id}').delete()")
