"""
Test script for Blood Request API endpoints.
Run with: python test_blood_requests.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from account.models import CustomUser
from blood_requests.models import BloodRequest
from django.utils import timezone
import json

def test_blood_requests():
    print("=" * 60)
    print("BLOOD REQUEST API TEST")
    print("=" * 60)

    # Test 1: Create a blood request
    print("\n[1] Creating a blood request...")
    try:
        # Get a test user
        test_user = CustomUser.objects.filter(email__contains='gmail').first()
        if not test_user:
            test_user = CustomUser.objects.first()

        blood_request = BloodRequest.objects.create(
            patient_name="Ahmed Khan",
            blood_group="A+",
            units_needed=2,
            urgency_level="urgent",
            contact_number="+923001234567",
            hospital_name="City Hospital Lahore",
            location="Lahore, Pakistan",
            additional_notes="Patient needs blood urgently for surgery",
            requested_by=test_user
        )
        print(f"   [OK] Blood request created: {blood_request.id}")
        print(f"   Patient: {blood_request.patient_name}")
        print(f"   Blood Group: {blood_request.blood_group}")
        print(f"   Units Needed: {blood_request.units_needed}")
        print(f"   Urgency: {blood_request.urgency_level}")

    except Exception as e:
        print(f"   [ERROR] Failed to create blood request: {e}")
        return

    # Test 2: Create multiple blood requests for testing
    print("\n[2] Creating sample blood requests...")
    sample_requests = [
        {
            "patient_name": "Fatima Ali",
            "blood_group": "B+",
            "units_needed": 1,
            "urgency_level": "critical",
            "contact_number": "+923009876543",
            "hospital_name": "Shaukat Khanum Hospital",
            "location": "Lahore"
        },
        {
            "patient_name": "Hassan Raza",
            "blood_group": "O+",
            "units_needed": 3,
            "urgency_level": "normal",
            "contact_number": "+923005551234",
            "hospital_name": "Jinnah Hospital",
            "location": "Lahore"
        },
        {
            "patient_name": "Ayesha Siddiqui",
            "blood_group": "AB-",
            "units_needed": 2,
            "urgency_level": "urgent",
            "contact_number": "+923005556789",
            "hospital_name": "Services Hospital",
            "location": "Lahore"
        }
    ]

    for req_data in sample_requests:
        try:
            BloodRequest.objects.create(
                patient_name=req_data["patient_name"],
                blood_group=req_data["blood_group"],
                units_needed=req_data["units_needed"],
                urgency_level=req_data["urgency_level"],
                contact_number=req_data["contact_number"],
                hospital_name=req_data.get("hospital_name", ""),
                location=req_data.get("location", ""),
                requested_by=None  # Anonymous request
            )
            print(f"   [OK] Created: {req_data['patient_name']} ({req_data['blood_group']})")
        except Exception as e:
            print(f"   [ERROR] Failed to create {req_data['patient_name']}: {e}")

    # Test 3: List all active blood requests
    print("\n[3] Listing all active blood requests...")
    try:
        all_requests = BloodRequest.objects.filter(is_active=True).order_by('-urgency_level', '-created_at')
        print(f"   Total active requests: {all_requests.count()}")
        print("\n   Blood Requests:")
        for req in all_requests[:5]:  # Show first 5
            status_icon = "🔴" if req.urgency_level == "critical" else "🟠" if req.urgency_level == "urgent" else "🟢"
            print(f"      {status_icon} {req.patient_name} | {req.blood_group} | {req.units_needed} units | {req.hospital_name or 'N/A'}")
    except Exception as e:
        print(f"   [ERROR] Failed to list requests: {e}")

    # Test 4: Filter by blood group
    print("\n[4] Filtering by blood group (A+)...")
    try:
        a_positive = BloodRequest.objects.filter(blood_group="A+", is_active=True)
        print(f"   Found {a_positive.count()} A+ blood requests")
    except Exception as e:
        print(f"   [ERROR] Failed to filter: {e}")

    # Test 5: Filter by urgency
    print("\n[5] Filtering by urgency level (critical)...")
    try:
        critical = BloodRequest.objects.filter(urgency_level="critical", is_active=True)
        print(f"   Found {critical.count()} critical blood requests")
    except Exception as e:
        print(f"   [ERROR] Failed to filter: {e}")

    # Test 6: Test update functionality
    print("\n[6] Testing update functionality...")
    try:
        if blood_request:
            blood_request.status = "fulfilled"
            blood_request.save()
            print(f"   [OK] Updated blood request status to: {blood_request.status}")
    except Exception as e:
        print(f"   [ERROR] Failed to update: {e}")

    # Test 7: Test soft delete
    print("\n[7] Testing soft delete (is_active=False)...")
    try:
        if blood_request:
            blood_request.is_active = False
            blood_request.save()
            print(f"   [OK] Soft deleted blood request")

        # Verify it's not in active list
        active_count = BloodRequest.objects.filter(is_active=True).count()
        print(f"   Active requests count: {active_count}")
    except Exception as e:
        print(f"   [ERROR] Failed to soft delete: {e}")

    print("\n" + "=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)

    # Print API endpoints summary
    print("\nAvailable API Endpoints:")
    print("  GET    /api/auth/blood-requests/")
    print("         - List all active blood requests")
    print("         - Query params: blood_group, urgency_level, status")
    print()
    print("  POST   /api/auth/blood-requests/create/")
    print("         - Create a new blood request")
    print("         - Body: patient_name, blood_group, units_needed, urgency_level, contact_number, etc.")
    print()
    print("  GET    /api/auth/blood-requests/{request_id}/")
    print("         - Get details of a specific blood request")
    print()
    print("  PUT    /api/auth/blood-requests/{request_id}/update/")
    print("         - Update a blood request (requires authentication)")
    print()
    print("  DELETE /api/auth/blood-requests/{request_id}/delete/")
    print("         - Delete a blood request (requires authentication)")
    print()
    print("  GET    /api/auth/blood-requests/my-requests/")
    print("         - Get blood requests created by current user (requires authentication)")
    print("=" * 60)

if __name__ == "__main__":
    test_blood_requests()
