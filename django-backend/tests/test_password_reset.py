"""
Test script to verify password reset flow works correctly.
Run this with: python test_password_reset.py
"""
import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.core.mail import send_mail
from django.conf import settings
from account.models import CustomUser, PasswordReset
import uuid

def test_password_reset():
    print("=" * 60)
    print("PASSWORD RESET API TEST")
    print("=" * 60)

    # Test 1: Check Email Configuration
    print("\n[1] Checking Email Configuration...")
    print(f"   Email Backend: {settings.EMAIL_BACKEND}")
    print(f"   SMTP Host: {settings.EMAIL_HOST}")
    print(f"   SMTP Port: {settings.EMAIL_PORT}")
    print(f"   Use TLS: {settings.EMAIL_USE_TLS}")
    print(f"   From Email: {settings.DEFAULT_FROM_EMAIL}")
    print(f"   Deep Link Scheme: {settings.APP_DEEP_LINK_SCHEME}")

    # Test 2: List all users
    print("\n[2] Registered Users:")
    users = CustomUser.objects.all()
    for user in users:
        print(f"   - {user.email} ({user.full_name})")

    # Test 3: Check existing password reset tokens
    print("\n[3] Existing Password Reset Tokens:")
    resets = PasswordReset.objects.all().order_by('-created_at')[:5]
    if resets:
        for reset in resets:
            status = "USED" if reset.is_used else "VALID" if reset.is_valid() else "EXPIRED"
            print(f"   - {reset.user.email}: {reset.token} [{status}]")
    else:
        print("   No password reset tokens found")

    # Test 4: Create a test reset token
    print("\n[4] Creating Test Password Reset Token...")
    if users:
        # Use the admin's real Gmail for testing
        test_email = "sanamobin7@gmail.com"
        test_user = CustomUser.objects.filter(email=test_email).first()

        # Fallback to first user if admin not found
        if not test_user:
            test_user = users.first()
        # Delete old unused tokens
        PasswordReset.objects.filter(user=test_user, is_used=False).delete()

        # Create new token
        reset = PasswordReset.objects.create(user=test_user)
        reset_link = f"{settings.APP_DEEP_LINK_SCHEME}://reset-password?email={test_user.email}&token={reset.token}"

        print(f"   User: {test_user.email}")
        print(f"   Token: {reset.token}")
        print(f"   Reset Link: {reset_link}")
        print(f"   Valid Until: {reset.created_at.replace(tzinfo=None)} + 1 hour")

        # Test 5: Send test email
        print("\n[5] Sending Test Email...")
        try:
            subject = "TEST: Password Reset Request - Blood Donation System"
            message = f"""
Hello {test_user.full_name},

This is a TEST email for password reset functionality.

Click the link below to reset your password:
{reset_link}

This link will expire in 1 hour.

If you're using a mobile device, this will open the Blood Donation app.
If the app doesn't open, make sure you have the app installed.

If you didn't request this password reset, please ignore this email.

Best regards,
Blood Donation Team
"""
            send_mail(
                subject=subject,
                message=message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[test_user.email],
                fail_silently=False,
            )
            print("   [OK] Email sent successfully!")
        except Exception as e:
            print(f"   [ERROR] Failed to send email: {e}")

    print("\n" + "=" * 60)
    print("TEST COMPLETE")
    print("=" * 60)
    print("\nNext Steps:")
    print("1. Check your email inbox for the test password reset email")
    print("2. Click the link in the email")
    print("3. If using a mobile device with the app installed, it should open the app")
    print("4. The app should parse the email and token from the URL")
    print("=" * 60)

if __name__ == "__main__":
    test_password_reset()
