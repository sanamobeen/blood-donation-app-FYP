"""
Quick script to change an existing user to admin.
Run: python make_admin.py <email>
Example: python make_admin.py user@example.com
"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from account.models import CustomUser, UserProfile

if len(sys.argv) < 2:
    print("Usage: python make_admin.py <email>")
    print("Example: python make_admin.py user@example.com")
    sys.exit(1)

email = sys.argv[1]

try:
    user = CustomUser.objects.get(email=email)
    user.role = 'admin'
    user.is_staff = True
    user.is_superuser = True
    user.save()

    print(f"✅ User {email} is now an admin!")
    print(f"   Name: {user.full_name}")
    print(f"   Role: {user.role}")
except CustomUser.DoesNotExist:
    print(f"❌ User with email {email} not found!")
    print("Available users:")
    for u in CustomUser.objects.all():
        print(f"  - {u.email} ({u.role or 'no role'})")
