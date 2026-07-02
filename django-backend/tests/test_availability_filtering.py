"""
Test script for Donor Availability Filtering functionality.
Run with: python test_availability_filtering.py

This tests the availability time slot matching logic that ensures
donors only see blood requests within their available time slots.
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from datetime import datetime, timedelta
from django.utils import timezone
from blood_requests.utils import (
    parse_time_slot,
    parse_time_string,
    is_time_in_slot,
    is_donor_available_at_time,
    filter_requests_by_availability,
    get_donor_availability_summary,
    WEEKDAY_MAP
)
from blood_requests.models import BloodRequest
from account.models import UserProfile, CustomUser


def test_parse_time_string():
    """Test parsing time strings like '8am', '4pm' into hours."""
    print("\n" + "=" * 60)
    print("TEST 1: Parse Time String")
    print("=" * 60)

    test_cases = [
        ('8am', 8),
        ('8pm', 20),
        ('12am', 0),
        ('12pm', 12),
        ('1am', 1),
        ('1pm', 13),
        ('11am', 11),
        ('11pm', 23),
        ('4pm', 16),
        ('6pm', 18),
    ]

    all_passed = True
    for time_str, expected in test_cases:
        result = parse_time_string(time_str)
        status = "✅" if result == expected else "❌"
        print(f"  {status} parse_time_string('{time_str}') = {result} (expected {expected})")
        if result != expected:
            all_passed = False

    return all_passed


def test_parse_time_slot():
    """Test parsing time slot strings like '8am_10am' into hour tuples."""
    print("\n" + "=" * 60)
    print("TEST 2: Parse Time Slot")
    print("=" * 60)

    test_cases = [
        ('8am_10am', (8, 10)),
        ('4pm_6pm', (16, 18)),
        ('12pm_2pm', (12, 14)),
        ('9am_5pm', (9, 17)),
        ('11am_1pm', (11, 13)),
    ]

    all_passed = True
    for slot_str, expected in test_cases:
        result = parse_time_slot(slot_str)
        status = "✅" if result == expected else "❌"
        print(f"  {status} parse_time_slot('{slot_str}') = {result} (expected {expected})")
        if result != expected:
            all_passed = False

    return all_passed


def test_is_time_in_slot():
    """Test checking if a datetime falls within a time slot."""
    print("\n" + "=" * 60)
    print("TEST 3: Time In Slot Check")
    print("=" * 60)

    # Create test datetimes
    # Monday 9 AM (hour 9)
    dt_9am = datetime(2024, 1, 15, 9, 0)  # Jan 15, 2024 is a Monday
    # Monday 5 PM (hour 17)
    dt_5pm = datetime(2024, 1, 15, 17, 0)
    # Monday 8 PM (hour 20)
    dt_8pm = datetime(2024, 1, 15, 20, 0)

    test_cases = [
        (dt_9am, (8, 10), True, "9 AM within 8 AM - 10 AM"),
        (dt_5pm, (16, 18), True, "5 PM within 4 PM - 6 PM"),
        (dt_8pm, (16, 18), False, "8 PM NOT within 4 PM - 6 PM"),
        (dt_9am, (16, 18), False, "9 AM NOT within 4 PM - 6 PM"),
    ]

    all_passed = True
    for dt, slot, expected, description in test_cases:
        result = is_time_in_slot(dt, slot)
        status = "✅" if result == expected else "❌"
        print(f"  {status} {description}: {result}")
        if result != expected:
            all_passed = False

    return all_passed


def test_is_donor_available_at_time():
    """Test checking donor availability at specific times."""
    print("\n" + "=" * 60)
    print("TEST 4: Donor Availability Check")
    print("=" * 60)

    # Donor availability: Monday-Friday 8am-10am and 4pm-6pm
    availability = {
        'monday': ['8am_10am', '4pm_6pm'],
        'tuesday': ['8am_10am', '4pm_6pm'],
        'wednesday': ['8am_10am', '4pm_6pm'],
        'thursday': ['8am_10am', '4pm_6pm'],
        'friday': ['8am_10am', '4pm_6pm'],
        # Saturday and Sunday not available
    }

    test_cases = [
        # Monday 9 AM - Should be available (8-10 AM slot)
        (datetime(2024, 1, 15, 9, 0), availability, False, True, "Monday 9 AM"),
        # Monday 5 PM - Should be available (4-6 PM slot)
        (datetime(2024, 1, 15, 17, 0), availability, False, True, "Monday 5 PM"),
        # Monday 2 PM - Should NOT be available (no slot)
        (datetime(2024, 1, 15, 14, 0), availability, False, False, "Monday 2 PM"),
        # Monday 7 PM - Should NOT be available
        (datetime(2024, 1, 15, 19, 0), availability, False, False, "Monday 7 PM"),
        # Saturday 9 AM - Should NOT be available (no Saturday slot)
        (datetime(2024, 1, 13, 9, 0), availability, False, False, "Saturday 9 AM"),
        # With available_all_day=True - Should always be available
        (datetime(2024, 1, 15, 14, 0), availability, True, True, "Monday 2 PM (all_day=True)"),
        # Sunday with available_all_day=True
        (datetime(2024, 1, 14, 10, 0), availability, True, True, "Sunday 10 AM (all_day=True)"),
    ]

    all_passed = True
    for dt, avail, all_day, expected, description in test_cases:
        result = is_donor_available_at_time(dt, avail, all_day)
        status = "✅" if result == expected else "❌"
        print(f"  {status} {description}: {result} (expected {expected})")
        if result != expected:
            all_passed = False

    return all_passed


def test_filter_requests_by_availability():
    """Test filtering blood requests by donor availability."""
    print("\n" + "=" * 60)
    print("TEST 5: Filter Requests by Availability")
    print("=" * 60)

    # Get or create a test donor
    donor_user = CustomUser.objects.filter(email__contains='test').first()
    if not donor_user:
        donor_user = CustomUser.objects.first()

    if not donor_user:
        print("  ⚠️  No users found in database, skipping test")
        return True

    # Get or create donor profile
    donor_profile, created = UserProfile.objects.get_or_create(
        user=donor_user,
        defaults={
            'blood_group': 'A+',
            'available_all_day': False,
            'availability': {
                'monday': ['8am_10am', '4pm_6pm'],
                'tuesday': ['8am_10am', '4pm_6pm'],
                'wednesday': ['8am_10am', '4pm_6pm'],
                'thursday': ['8am_10am', '4pm_6pm'],
                'friday': ['8am_10am', '4pm_6pm'],
            }
        }
    )

    if not created:
        # Update existing profile
        donor_profile.availability = {
            'monday': ['8am_10am', '4pm_6pm'],
            'tuesday': ['8am_10am', '4pm_6pm'],
            'wednesday': ['8am_10am', '4pm_6pm'],
            'thursday': ['8am_10am', '4pm_6pm'],
            'friday': ['8am_10am', '4pm_6pm'],
        }
        donor_profile.available_all_day = False
        donor_profile.save()

    # Create test blood requests with different needed_by times
    now = timezone.now()

    # Get a Monday at 9 AM (within slot)
    monday_9am = now + timedelta(days=(0 - now.weekday()))  # Next Monday
    monday_9am = monday_9am.replace(hour=9, minute=0, second=0, microsecond=0)

    # Get a Monday at 2 PM (outside slot)
    monday_2pm = monday_9am.replace(hour=14)

    # Get a Saturday (no slot available)
    saturday = monday_9am + timedelta(days=5)

    # Create requests
    requests_to_create = [
        (monday_9am, "Monday 9 AM (in slot)"),
        (monday_2pm, "Monday 2 PM (outside slot)"),
        (saturday, "Saturday (no slot)"),
    ]

    created_requests = []
    for needed_time, description in requests_to_create:
        try:
            req = BloodRequest.objects.create(
                patient_name=f"Test Patient {description}",
                blood_group="A+",
                units_needed=1,
                urgency_level="normal",
                contact_number="+923001234567",
                needed_by=needed_time,
                status='pending',
                is_active=True
            )
            created_requests.append(req)
            print(f"  ✅ Created test request: {description} at {needed_time}")
        except Exception as e:
            print(f"  ❌ Failed to create request: {e}")

    # Now filter by availability
    print("\n  Filtering requests by donor availability...")
    filtered = filter_requests_by_availability(created_requests, donor_profile, now)

    print(f"\n  Results: {len(filtered)}/{len(created_requests)} requests passed availability filter")
    for req in filtered:
        day_name = WEEKDAY_MAP.get(req.needed_by.weekday(), 'Unknown')
        print(f"    ✅ {req.patient_name} - {day_name} at {req.needed_by.hour}:00")

    # Clean up test requests
    for req in created_requests:
        req.delete()

    # Expected: Only 1 request (Monday 9 AM) should pass
    expected_count = 1
    passed = len(filtered) == expected_count
    status = "✅" if passed else "❌"
    print(f"\n  {status} Test passed: {len(filtered)} requests (expected {expected_count})")

    return passed


def test_get_donor_availability_summary():
    """Test getting donor availability summary."""
    print("\n" + "=" * 60)
    print("TEST 6: Donor Availability Summary")
    print("=" * 60)

    availability = {
        'monday': ['8am_10am', '4pm_6pm'],
        'wednesday': ['9am_11am'],
        'friday': ['8am_10am', '4pm_6pm', '7pm_9pm'],
    }

    # Mock donor profile
    class MockProfile:
        available_all_day = False
        availability = availability

    profile = MockProfile()
    summary = get_donor_availability_summary(profile)

    print(f"  Available all day: {summary['available_all_day']}")
    print(f"  Available days: {summary['available_days']}")
    print(f"  Time slots:")
    for day, slots in summary['time_slots'].items():
        print(f"    {day}: {slots}")

    # Verify
    expected_days = 3  # Monday, Wednesday, Friday
    passed = (
        summary['available_all_day'] == False and
        len(summary['available_days']) == expected_days and
        len(summary['time_slots']) == expected_days
    )

    status = "✅" if passed else "❌"
    print(f"\n  {status} Test passed: Summary has {len(summary['available_days'])} days (expected {expected_days})")

    return passed


def run_all_tests():
    """Run all availability filtering tests."""
    print("\n" + "=" * 60)
    print("DONOR AVAILABILITY FILTERING TESTS")
    print("=" * 60)

    results = []

    results.append(("Parse Time String", test_parse_time_string()))
    results.append(("Parse Time Slot", test_parse_time_slot()))
    results.append(("Time In Slot Check", test_is_time_in_slot()))
    results.append(("Donor Availability Check", test_is_donor_available_at_time()))
    results.append(("Filter Requests by Availability", test_filter_requests_by_availability()))
    results.append(("Donor Availability Summary", test_get_donor_availability_summary()))

    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)

    all_passed = True
    for test_name, passed in results:
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"  {status}: {test_name}")
        if not passed:
            all_passed = False

    print("\n" + "=" * 60)
    if all_passed:
        print("✅ ALL TESTS PASSED")
    else:
        print("❌ SOME TESTS FAILED")
    print("=" * 60)

    return all_passed


if __name__ == "__main__":
    run_all_tests()
