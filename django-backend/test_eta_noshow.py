"""
Test script for ETA-based no-show detection.
Run with: python manage.py shell < test_eta_noshow.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'blood_donation.settings')
django.setup()

from django.utils import timezone
from datetime import timedelta
from sos.models import SOSRequest, SOSResponse
from account.models import CustomUser

print("=" * 60)
print("ETA-Based No-Show Detection Test")
print("=" * 60)

# Get test users
patient = CustomUser.objects.filter(role='patient').first()
donor = CustomUser.objects.filter(role='donor').first()

if not patient or not donor:
    print("❌ ERROR: Need at least one patient and one donor")
    exit(1)

print(f"\n👤 Patient: {patient.email}")
print(f"👤 Donor: {donor.email}")

# Cleanup
print("\n🧹 Cleaning up old test data...")
SOSRequest.objects.filter(hospital_name__icontains='ETA Test').delete()

# ========================================
# TEST 1: ETA = 5 minutes, should be no-show after 15 minutes
# ========================================
print("\n" + "=" * 60)
print("TEST 1: Donor with ETA = 5 minutes")
print("=" * 60)

sos1 = SOSRequest.objects.create(
    requester=patient,
    blood_type='O+',
    patient_name='ETA Test Patient 1',
    age=30,
    gender='male',
    hospital_name='ETA Test Hospital',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=1,
    urgency='critical',
    status='active'
)

# Simulate donor was accepted 20 minutes ago with ETA of 5 minutes
# 20 minutes > 5 + 10 grace period = 15 minutes, so should be marked no-show
past_time = timezone.now() - timedelta(minutes=20)

response1 = SOSResponse.objects.create(
    sos_request=sos1,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=5,  # ETA was 5 minutes
    status='accepted',
    accepted_at=past_time,  # Accepted 20 minutes ago
    created_at=past_time
)

print(f"✅ Created SOS: {sos1.id}")
print(f"✅ Donor responded with ETA: 5 minutes")
print(f"✅ Accepted at: {past_time.strftime('%H:%M:%S')} (20 minutes ago)")
print(f"✅ Current time: {timezone.now().strftime('%H:%M:%S')}")
print(f"\n📊 Timeline:")
print(f"   - Accepted: 20 minutes ago")
print(f"   - ETA was: 5 minutes")
print(f"   - Grace period: 10 minutes")
print(f"   - Total deadline: 15 minutes")
print(f"   - Current elapsed: 20 minutes")
print(f"   - Should be no-show: YES ✅")

# Run the no-show detection task
print(f"\n🔍 Running ETA-based no-show detection...")
from sos.tasks import mark_eta_based_no_show_donors
result = mark_eta_based_no_show_donors(grace_period_minutes=10)

print(f"✅ Task completed. Marked {result} donors as no-show")

# Verify
response1.refresh_from_db()
print(f"\n📝 Result:")
print(f"   Status before: accepted")
print(f"   Status now: {response1.status}")

if response1.status == 'no_show':
    print(f"   ✅ SUCCESS: Donor correctly marked as no-show!")
else:
    print(f"   ❌ FAIL: Should be no-show")

# ========================================
# TEST 2: ETA = 5 minutes, but only 10 minutes passed
# Should NOT be no-show yet (need 15 total)
# ========================================
print("\n" + "=" * 60)
print("TEST 2: Donor with ETA = 5 minutes (not yet overdue)")
print("=" * 60)

sos2 = SOSRequest.objects.create(
    requester=patient,
    blood_type='A+',
    patient_name='ETA Test Patient 2',
    age=25,
    gender='female',
    hospital_name='ETA Test Hospital 2',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=1,
    urgency='critical',
    status='active'
)

# Only 10 minutes have passed (less than 5+10=15)
recent_time = timezone.now() - timedelta(minutes=10)

response2 = SOSResponse.objects.create(
    sos_request=sos2,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=5,
    status='accepted',
    accepted_at=recent_time,
    created_at=recent_time
)

print(f"✅ Created SOS: {sos2.id}")
print(f"✅ Donor responded with ETA: 5 minutes")
print(f"✅ Accepted at: {recent_time.strftime('%H:%M:%S')} (10 minutes ago)")
print(f"\n📊 Timeline:")
print(f"   - Accepted: 10 minutes ago")
print(f"   - ETA was: 5 minutes")
print(f"   - Grace period: 10 minutes")
print(f"   - Total deadline: 15 minutes")
print(f"   - Current elapsed: 10 minutes")
print(f"   - Should be no-show: NO ✅")

# Run the task
result2 = mark_eta_based_no_show_donors(grace_period_minutes=10)
print(f"\n🔍 Running ETA-based no-show detection...")
print(f"✅ Task completed. Marked {result2} donors as no-show")

# Verify
response2.refresh_from_db()
print(f"\n📝 Result:")
print(f"   Status before: accepted")
print(f"   Status now: {response2.status}")

if response2.status == 'accepted':
    print(f"   ✅ SUCCESS: Donor correctly NOT marked as no-show (still within deadline)")
else:
    print(f"   ❌ FAIL: Should still be accepted")

# ========================================
# TEST 3: Different ETAs
# ========================================
print("\n" + "=" * 60)
print("TEST 3: Various ETA scenarios")
print("=" * 60)

etas_to_test = [
    (1, 12, "1 minute ETA, 12 min passed"),   # 1 + 10 = 11 deadline, 12 > 11 = no-show
    (10, 25, "10 minute ETA, 25 min passed"),  # 10 + 10 = 20 deadline, 25 > 20 = no-show
    (30, 35, "30 minute ETA, 35 min passed"),  # 30 + 10 = 40 deadline, 35 < 40 = NOT no-show
]

for eta, elapsed, description in etas_to_test:
    sos = SOSRequest.objects.create(
        requester=patient,
        blood_type='B+',
        patient_name=f'ETA Test {eta}min',
        age=30,
        gender='male',
        hospital_name='ETA Test Hospital Var',
        hospital_lat=40.7128,
        hospital_lng=-74.0060,
        units_needed=1,
        urgency='critical',
        status='active'
    )

    past = timezone.now() - timedelta(minutes=elapsed)
    resp = SOSResponse.objects.create(
        sos_request=sos,
        responder=donor,
        can_help=True,
        estimated_arrival_minutes=eta,
        status='accepted',
        accepted_at=past,
        created_at=past
    )

    mark_eta_based_no_show_donors(grace_period_minutes=10)
    resp.refresh_from_db()

    deadline = eta + 10
    expected = 'no-show' if elapsed > deadline else 'accepted'
    status_match = '✅' if resp.status == expected else '❌'

    print(f"\n   {description}")
    print(f"   Deadline: {deadline} minutes | Elapsed: {elapsed} minutes")
    print(f"   Expected: {expected} | Actual: {resp.status} {status_match}")

# ========================================
# TEST 4: Donor confirms arrival (should NOT be marked no-show)
# ========================================
print("\n" + "=" * 60)
print("TEST 4: Donor confirms arrival (should not be no-show)")
print("=" * 60)

sos4 = SOSRequest.objects.create(
    requester=patient,
    blood_type='AB+',
    patient_name='ETA Test Confirmed',
    age=35,
    gender='female',
    hospital_name='ETA Test Hospital Confirmed',
    hospital_lat=40.7128,
    hospital_lng=-74.0060,
    units_needed=1,
    urgency='critical',
    status='active'
)

long_past = timezone.now() - timedelta(minutes=50)

response4 = SOSResponse.objects.create(
    sos_request=sos4,
    responder=donor,
    can_help=True,
    estimated_arrival_minutes=5,
    status='accepted',
    accepted_at=long_past,
    arrived_at=timezone.now(),  # Donor confirmed arrival!
    created_at=long_past
)

print(f"✅ Created response where donor CONFIRMED ARRIVAL")
print(f"✅ ETA was 5 minutes, 50 minutes elapsed")
print(f"✅ But arrived_at is set: {response4.arrived_at}")

# Run task
result4 = mark_eta_based_no_show_donors(grace_period_minutes=10)

response4.refresh_from_db()
print(f"\n📝 Result:")
print(f"   Status: {response4.status}")

if response4.status == 'accepted':
    print(f"   ✅ SUCCESS: Donor who confirmed arrival is NOT marked no-show")
else:
    print(f"   ❌ FAIL: Should remain accepted")

# ========================================
# Summary
# ========================================
print("\n" + "=" * 60)
print("TEST SUMMARY")
print("=" * 60)

all_responses = SOSResponse.objects.filter(
    sos_request__hospital_name__icontains='ETA Test'
)

print(f"\nTotal test responses created: {all_responses.count()}")
print(f"No-show responses: {all_responses.filter(status='no_show').count()}")
print(f"Still accepted: {all_responses.filter(status='accepted').count()}")

print("\n✅ All tests completed!")
print("\n💡 Cleanup:")
print(f"   SOSRequest.objects.filter(hospital_name__icontains='ETA Test').delete()")
