"""
Quick script to create admin user.
Run: python create_admin.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from account.models import CustomUser, UserProfile
from django.contrib.auth.hashers import make_password

# Check if admin already exists
if CustomUser.objects.filter(email='admin@lifedrop.com').exists():
    print("⚠️ Admin already exists!")
    admin = CustomUser.objects.get(email='admin@lifedrop.com')
    print(f"✅ Login with: admin@lifedrop.com")
else:
    # Create admin user
    user = CustomUser.objects.create(
        email='admin@lifedrop.com',
        full_name='Admin User',
        phone_num='+1234567890',
        password=make_password('Admin123!'),
        is_active=True,
        is_staff=True,
        is_superuser=True,
        role='admin'
    )

    UserProfile.objects.create(
        user=user,
        blood_group='O+',
        country='USA'
    )

    print("✅ Admin created successfully!")
    print("📧 Email: admin@lifedrop.com")
    print("🔑 Password: Admin123!")
    print("🌐 Login at Flutter Web App")
