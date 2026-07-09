import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from blood_requests.models import BloodRequest

print("=" * 50)
print("BLOOD REQUESTS - requested_by STATUS")
print("=" * 50)

for r in BloodRequest.objects.all():
    has_user = "✅" if r.requested_by else "❌ None"
    user_email = r.requested_by.email if r.requested_by else "No User"
    print(f"{has_user} Request: {r.patient_name}")
    print(f"   Created by: {user_email}")
    print(f"   Request ID: {r.id}")
    print()

print("\nRequests without requested_by will NOT receive notifications!")
print("These requests need to be created by authenticated users.")
