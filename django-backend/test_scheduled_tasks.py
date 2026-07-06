"""
Test script for SOS scheduled tasks.
Run with: python manage.py shell < test_scheduled_tasks.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_donation.settings')
django.setup()

from django.utils import timezone
from datetime import timedelta
from sos.models import SOSRequest, SOSResponse
from account.models import CustomUser
from sos.tasks import expire_old_sos_requests, check_long_running_sos_requests, mark_no_show_donors, send_sos_reminder_notifications

print("=" * 60)
print("SOS Scheduled Tasks Testing Script")
print("=" * 60)

# Get test users
patient = CustomUser.objects.filter(role='patient').first()
donor = CustomUser.objects.filter(role='donor').first()

if not patient or not donor:
    print("❌ ERROR: Need at least one patient and one donor in the database")
    exit(1)

print(f"\n👤 Patient: {patient.email}")
print(f"👤 Donor: {donor.email}")

# Cleanup any existing test data
print("\n🧹 Cleaning up old test data...")
SOSRequest.objects.filter(
    hospital_name__icontains='Test Hospital'
).delete()
print("✅ Old test data cleaned up")

# Test 1: Create old SOS request (simulating one that should expire)
print("\n📝 Test 1: Expired SOS Request (no responses)")
old_time = timezone.now() - timedelta(hours=5)
old_sos = SOSRequest.objects.create(
    requester=patient,
    blood_type='O+',
    patient_name='Old Patient',
    age=30,
    gender='male',
    hospital_name='Test Hospital - Expired',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=2,
    urgency='critical',
    status='active',
    created_at=old_time  # Manually set old time
)
print(f"   Created SOS with timestamp: {old_sos.created_at}")
print(f"   Status before: {old_sos.status}")

# Run the expire task
result = expire_old_sos_requests(hours=4)
print(f"   ✅ Expired {result} SOS requests")

# Check if it was expired
old_sos.refresh_from_db()
print(f"   Status after: {old_sos.status}")

if old_sos.status == 'expired':
    print("   ✅ SUCCESS: SOS was correctly expired")
else:
    print("   ❌ FAIL: SOS should be expired")

# Test 2: Create long-running SOS with responses
print("\n📝 Test 2: Long-running SOS Request (with responses)")
long_running_time = timezone.now() - timedelta(hours=9)
long_sos = SOSRequest.objects.create(
    requester=patient,
    blood_type='A+',
    patient_name='Long Running Patient',
    age=25,
    gender='female',
    hospital_name='Test Hospital - Long Running',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=1,
    urgency='urgent',
    status='active',
    created_at=long_running_time
)
print(f"   Created SOS with timestamp: {long_sos.created_at}")

# Add a response
old_response = SOSResponse.objects.create(
    sos_request=long_sos,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=30,
    status='pending',
    created_at=long_running_time
)
print(f"   Created response: {old_response.id}")

# Run check task
result = check_long_running_sos_requests(hours=8)
print(f"   ✅ Check result: {result}")

# Test 3: No-show donor
print("\n📝 Test 3: No-show Donor (accepted but never arrived)")
no_show_time = timezone.now() - timedelta(minutes=70)
no_show_sos = SOSRequest.objects.create(
    requester=patient,
    blood_type='B+',
    patient_name='No Show Patient',
    age=40,
    gender='male',
    hospital_name='Test Hospital - No Show',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=1,
    urgency='critical',
    status='active'
)

no_show_response = SOSResponse.objects.create(
    sos_request=no_show_sos,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=30,
    status='accepted',
    accepted_at=no_show_time,  # Accepted 70 minutes ago
    created_at=no_show_time
)
print(f"   Created response accepted at: {no_show_response.accepted_at}")
print(f"   Status before: {no_show_response.status}")

# Run no-show task
result = mark_no_show_donors(minutes=60)
print(f"   ✅ Marked {result} donors as no-show")

# Check if marked as no-show
no_show_response.refresh_from_db()
print(f"   Status after: {no_show_response.status}")

if no_show_response.status == 'no_show':
    print("   ✅ SUCCESS: Response correctly marked as no-show")
else:
    print("   ❌ FAIL: Response should be no-show")

# Test 4: ETA reminder scenario
print("\n📝 Test 4: ETA Reminder (donor should update ETA)")
reminder_sos = SOSRequest.objects.create(
    requester=patient,
    blood_type='O-',
    patient_name='Reminder Patient',
    age=35,
    gender='female',
    hospital_name='Test Hospital - Reminder',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=2,
    urgency='critical',
    status='active'
)

# Accepted 25 minutes ago with 30 min ETA (should trigger reminder)
reminder_time = timezone.now() - timedelta(minutes=25)
reminder_response = SOSResponse.objects.create(
    sos_request=reminder_sos,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=30,
    status='accepted',
    accepted_at=reminder_time,
    created_at=reminder_time
)
print(f"   Created response with ETA: {reminder_response.estimated_arrival_minutes} min")
print(f"   Accepted at: {reminder_response.accepted_at}")

# Run reminder task (triggers for ETA within 30 min)
result = send_sos_reminder_notifications(minutes=30)
print(f"   ✅ Sent {result} ETA reminders")

# Summary
print("\n" + "=" * 60)
print("Test Summary")
print("=" * 60)
print(f"✅ Expired old SOS: {old_sos.status == 'expired'}")
print(f"✅ Checked long-running SOS: {result is not None}")
print(f"✅ Marked no-show donor: {no_show_response.status == 'no_show'}")
print(f"✅ ETA reminders sent: {result >= 0}")
print("=" * 60)

# Cleanup instructions
print(f"\n💡 Cleanup test data:")
print(f"   SOSRequest.objects.filter(hospital_name__icontains='Test Hospital').delete()")
print(f"\n   Total test SOS requests: {SOSRequest.objects.filter(hospital_name__icontains='Test Hospital').count()}")
