"""
Test SMTP connection directly to diagnose Gmail authentication issues.
"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Your Gmail credentials
SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587
EMAIL = "sanamobin7@gmail.com"
PASSWORD = "kyyr xmyw gshe kwuo"  # Try without quotes first

def test_smtp():
    print("=" * 60)
    print("GMAIL SMTP CONNECTION TEST")
    print("=" * 60)

    try:
        # Try to connect to Gmail SMTP
        print(f"\n[1] Connecting to {SMTP_HOST}:{SMTP_PORT}...")
        server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
        print("   [OK] Connected")

        # Start TLS
        print("\n[2] Starting TLS encryption...")
        server.starttls()
        print("   [OK] TLS started")

        # Login
        print(f"\n[3] Logging in as {EMAIL}...")
        server.login(EMAIL, PASSWORD)
        print("   [OK] Login successful!")

        # Send test email
        print("\n[4] Sending test email to yourself...")
        msg = MIMEMultipart()
        msg['From'] = EMAIL
        msg['To'] = EMAIL
        msg['Subject'] = "TEST: SMTP Connection Successful"

        body = """
This is a test email from the SMTP connection test.

If you receive this, the Gmail SMTP credentials are working correctly.

- Your Blood Donation System
"""
        msg.attach(MIMEText(body, 'plain'))

        server.send_message(msg)
        print("   [OK] Email sent!")

        server.quit()
        print("\n" + "=" * 60)
        print("TEST PASSED - Check your Gmail inbox!")
        print("=" * 60)

    except smtplib.SMTPAuthenticationError as e:
        print(f"\n   [ERROR] Authentication failed!")
        print(f"   Error: {e}")
        print("\nPossible solutions:")
        print("1. Generate a new Gmail App Password")
        print("2. Enable 2-Step Verification on your Google Account")
        print("3. Check that the password doesn't have extra quotes/spaces")
        print("\nGo to: https://myaccount.google.com/apppasswords")

    except Exception as e:
        print(f"\n   [ERROR] {type(e).__name__}: {e}")

if __name__ == "__main__":
    test_smtp()
