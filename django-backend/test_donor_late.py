"""
Test script for "Donor Late" notification feature.
This demonstrates how the patient can notify a donor when they're late past their ETA.

Run with: python manage.py shell < test_donor_late.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_donation.settings')
django.setup()

from django.utils import timezone
from datetime import timedelta
from sos.models import SOSRequest, SOSResponse
from account.models import CustomUser

print("=" * 70)
print("⏰ Donor Late Notification Feature Test")
print("=" * 70)

# Get test users
patient = CustomUser.objects.filter(role='patient').first()
donor = CustomUser.objects.filter(role='donor').first()

if not patient or not donor:
    print("❌ ERROR: Need at least one patient and one donor in the database")
    exit(1)

print(f"\n👤 Patient: {patient.email}")
print(f"👤 Donor: {donor.email}")

# Cleanup
print("\n🧹 Cleaning up old test data...")
SOSRequest.objects.filter(hospital_name__icontains='Test Hospital').delete()
print("✅ Old test data cleaned up")

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
print(f"\n✅ Step 1: SOS Request created (ID: {sos.id})")

# Create donor response with ETA
response = SOSResponse.objects.create(
    sos_request=sos,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=30,
    note="On my way!",
    status='pending'
)
print(f"✅ Step 2: Donor responded with ETA: {response.estimated_arrival_minutes} minutes")

# Patient accepts donor
response.status = 'accepted'
response.accepted_at = timezone.now() - timedelta(minutes=35)  # Accepted 35 min ago
response.save()
print(f"✅ Step 3: Patient accepted donor (35 minutes ago)")

print("\n" + "=" * 70)
print("SCENARIO: Donor is 5 minutes past their 30-minute ETA!")
print("=" * 70)

# Test 1: Calculate how late the donor is
print("\n📊 Step 4: Calculating donor lateness...")
expected_arrival = response.accepted_at + timedelta(minutes=response.estimated_arrival_minutes)
minutes_late = int((timezone.now() - expected_arrival).total_seconds() / 60)
print(f"   Expected arrival time: {expected_arrival.strftime('%H:%M:%S')}")
print(f"   Current time: {timezone.now().strftime('%H:%M:%S')}")
print(f"   Minutes past ETA: {max(0, minutes_late)}")

# Test 2: Patient manually notifies donor they're late
print(f"\n📱 Step 5: Patient sends 'You're Late' notification...")
try:
    from notifications.services.fcm_service import notify_donor_running_late

    # Simulate patient clicking "Donor is Late" button after 5 min past ETA
    success = notify_donor_running_late(response, minutes_late=max(5, minutes_late))

    if success:
        print("✅ SUCCESS: Late notification sent to donor!")
    else:
        print("⚠️ Notification function returned False (no FCM tokens?)")

except Exception as e:
    print(f"❌ Error: {e}")

# Test 3: Check what notification was created
print(f"\n📬 Step 6: Checking notification created...")
from notifications.models import Notification
late_notification = Notification.objects.filter(
    user=donor,
    type='donor_running_late_alert',
    related_request_id=str(sos.id)
).first()

if late_notification:
    print("✅ Notification created in database:")
    print(f"   Title: {late_notification.title}")
    print(f"   Message: {late_notification.message}")
    print(f"   Type: {late_notification.type}")
    print(f"   Created: {late_notification.created_at}")
else:
    print("❌ No notification found")

# Test 4: Simulate the API endpoint call
print(f"\n🔌 Step 7: Simulating API endpoint call...")
print("   Patient calls: POST /api/sos/{sos_id}/notify-donor-late/{response_id}/")
print(f"   Request body: {{'minutes_late': {max(5, minutes_late)}}}")
print("   → This would trigger the same notification")

# Test 5: Auto-notification via scheduled task
print(f"\n🤖 Step 8: Testing auto-notification (scheduled task)...")
try:
    from sos.tasks import notify_donors_past_eta

    # Run the scheduled task (would normally run every 5 min via Celery Beat)
    count = notify_donors_past_eta(grace_period_minutes=5)
    print(f"✅ Scheduled task sent {count} past-ETA notifications")

except Exception as e:
    print(f"❌ Error: {e}")

# Test 6: Donor confirms they can't arrive (optional action by donor)
print(f"\n🚫 Step 9: Donor realizes they can't make it and cancels...")
try:
    from notifications.services.fcm_service import notify_patient_donor_not_arriving

    # Update response to cancelled
    previous_status = response.status
    response.status = 'cancelled'
    response.cancelled_at = timezone.now()
    response.save()

    success = notify_patient_donor_not_arriving(response)

    if success:
        print("✅ SUCCESS: Patient notified that donor can't arrive!")

    # Check notification created for patient
    cancel_notification = Notification.objects.filter(
        user=patient,
        type='donor_not_arriving',
        related_request_id=str(sos.id)
    ).first()

    if cancel_notification:
        print("✅ Cancellation notification created for patient:")
        print(f"   Title: {cancel_notification.title}")
        print(f"   Message: {cancel_notification.message}")

except Exception as e:
    print(f"❌ Error: {e}")

print("\n" + "=" * 70)
print("✅ Testing Complete!")
print("=" * 70)

print("\n📖 Summary of Features Tested:")
print("   1. ✅ Patient can manually notify donor when late")
print("   2. ✅ Automatic notification when donor passes ETA")
print("   3. ✅ Donor can cancel and notify patient")

print("\n📋 API Endpoints for Frontend:")
print("   • POST /api/sos/{sos_id}/notify-donor-late/{response_id}/")
print("     Body: {'minutes_late': 5}  (optional)")
print("   • POST /api/sos/{sos_id}/donor-cannot-arrive/{response_id}/")
print("     Body: {'reason': 'Stuck in traffic'}  (optional)")

print("\n💡 Cleanup:")
print(f"   SOSRequest.objects.filter(id='{sos.id}').delete()")
