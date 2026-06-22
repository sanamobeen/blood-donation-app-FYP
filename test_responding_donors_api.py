"""
Test script to verify the responding donors API endpoint.
This will help debug why the Flutter app is showing empty results.
"""
import os
import sys
import django

# Setup Django environment
sys.path.append(os.path.join(os.path.dirname(__file__), 'django-backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.contrib.auth import get_user_model
from rest_framework.test import force_authenticate
from django.test import RequestFactory
from blood_requests.models import BloodRequest, DonorResponse
from blood_requests.views import get_responding_donors_for_patient
from account.models import UserProfile

User = get_user_model()

def test_responding_donors():
    print("=" * 80)
    print("TESTING RESPONDING DONORS API")
    print("=" * 80)

    # Get the patient user
    try:
        patient = User.objects.filter(role='patient').first()
        if not patient:
            print("[ERROR] No patient user found in database!")
            return

        print(f"[OK] Found patient: {patient.email}")

        # Check patient's blood requests
        patient_requests = BloodRequest.objects.filter(requested_by=patient)
        print(f"\n[OK] Patient has {patient_requests.count()} blood requests:")
        for req in patient_requests:
            print(f"  - Request ID: {req.id}, Blood Group: {req.blood_group}, Status: {req.status}")

        # Check pledges for these requests
        pledges = DonorResponse.objects.filter(blood_request__in=patient_requests)
        print(f"\n[OK] Total pledges for patient's requests: {pledges.count()}")
        for pledge in pledges:
            print(f"  - Pledge ID: {pledge.id}, Donor: {pledge.donor.email if pledge.donor else 'None'}, Status: {pledge.status}")

        # Create a mock request with authentication
        factory = RequestFactory()
        request = factory.get('/api/blood-requests/responding-donors/')
        force_authenticate(request, user=patient)

        # Call the view
        print("\n" + "=" * 80)
        print("CALLING API ENDPOINT")
        print("=" * 80)
        response = get_responding_donors_for_patient(request)

        # Print response data
        print(f"\n[OK] Response Status: {response.status_code}")
        response_data = response.data
        print(f"[OK] Success: {response_data.get('success')}")
        print(f"[OK] Message: {response_data.get('message')}")

        donors = response_data.get('donors', [])
        summary = response_data.get('summary', {})

        print(f"\n[OK] Total Donors in Response: {len(donors)}")
        print(f"[OK] Summary: {summary}")

        if donors:
            print("\n[OK] Donor Details:")
            for donor in donors[:5]:  # Show first 5
                donor_info = donor.get('donor', {})
                pledge_info = donor.get('pledge', {})
                print(f"  - Name: {donor_info.get('name')}")
                print(f"    Blood Group: {donor_info.get('blood_group')}")
                print(f"    Phone: {donor_info.get('phone')}")
                print(f"    Pledge Status: {pledge_info.get('status')}")
                print(f"    Request ID: {donor.get('request_id')}")
                print(f"    Patient Name: {donor.get('patient_name')}")
        else:
            print("[ERROR] No donors returned in response!")

    except Exception as e:
        print(f"[ERROR] Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    test_responding_donors()
