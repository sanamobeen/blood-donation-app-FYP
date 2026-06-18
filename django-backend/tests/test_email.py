"""
Test script to verify email configuration is working
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.core.mail import send_mail
from django.conf import settings

print("=" * 60)
print("TESTING EMAIL CONFIGURATION")
print("=" * 60)
print(f"EMAIL_BACKEND: {settings.EMAIL_BACKEND}")
print(f"EMAIL_HOST: {settings.EMAIL_HOST}")
print(f"EMAIL_PORT: {settings.EMAIL_PORT}")
print(f"EMAIL_USE_TLS: {settings.EMAIL_USE_TLS}")
print(f"EMAIL_HOST_USER: {settings.EMAIL_HOST_USER}")
print(f"DEFAULT_FROM_EMAIL: {settings.DEFAULT_FROM_EMAIL}")
print(f"APP_DEEP_LINK_SCHEME: {settings.APP_DEEP_LINK_SCHEME}")
print("=" * 60)

print("\nSending test email to sanamobin7@gmail.com...")

try:
    result = send_mail(
        "Blood Donation - Test Email",
        """
Hello!

This is a test email from your Blood Donation application.

If you receive this email, your SMTP configuration is working correctly!

Best regards,
Blood Donation Team
        """.strip(),
        settings.DEFAULT_FROM_EMAIL,
        ["sanamobin7@gmail.com"],
        fail_silently=False,
    )

    if result == 1:
        print("SUCCESS! Email sent successfully!")
        print("Please check your inbox (and spam folder)")
    else:
        print(f"Unexpected result: {result}")

except Exception as e:
    print(f"ERROR: {e}")
    print("\nCOMMON FIXES:")
    print("1. Generate a new Gmail App Password:")
    print("   --> Go to: https://myaccount.google.com/apppasswords")
    print("   --> Select: Mail + Windows")
    print("   --> Click Generate")
    print("   --> Copy the 16-character password")
    print("\n2. Update your .env file:")
    print("   EMAIL_HOST_PASSWORD = 'your-16-char-password'")
    print("\n3. Restart Django server:")
    print("   python manage.py runserver")

print("\n" + "=" * 60)
