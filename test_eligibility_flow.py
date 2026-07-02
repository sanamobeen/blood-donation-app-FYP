"""
Test script to verify the health eligibility flow works correctly.
Run this to verify the backend is returning correct data.
"""

import requests
import json

BASE_URL = "http://localhost:8000"

def test_eligibility_api():
    """Test the eligibility API endpoint"""
    print("Testing Health Eligibility API...")
    print("=" * 50)

    # Test credentials
    email = "fatima@gmail.com"
    password = "testpass123"  # Update with actual password

    # First, login to get token
    print(f"1. Logging in as {email}...")
    login_response = requests.post(f"{BASE_URL}/api/auth/login/", json={
        "email": email,
        "password": password
    })

    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.status_code}")
        print(login_response.text)
        return

    login_data = login_response.json()
    access_token = login_data.get('access')
    print(f"✅ Login successful")

    # Now test eligibility endpoint
    print("\n2. Testing eligibility endpoint...")
    eligibility_response = requests.get(
        f"{BASE_URL}/api/health/eligibility/",
        headers={"Authorization": f"Bearer {access_token}"}
    )

    if eligibility_response.status_code != 200:
        print(f"❌ Eligibility check failed: {eligibility_response.status_code}")
        print(eligibility_response.text)
        return

    eligibility_data = eligibility_response.json()
    print("✅ Eligibility response received:")
    print(json.dumps(eligibility_data, indent=2))

    # Check the key fields
    print("\n3. Checking key fields...")
    eligibility = eligibility_data.get('eligibility', {})
    health_quiz_completed = eligibility.get('health_quiz_completed')
    is_still_valid = eligibility_data.get('is_still_valid')

    print(f"   health_quiz_completed: {health_quiz_completed} (type: {type(health_quiz_completed).__name__})")
    print(f"   is_still_valid: {is_still_valid} (type: {type(is_still_valid).__name__})")

    # Check if the values are correct
    if health_quiz_completed is True and is_still_valid is True:
        print("\n✅ SUCCESS: Both values are True - User should NOT see quiz dialog")
        print("   Expected behavior: App should proceed to donor home")
    else:
        print(f"\n❌ ISSUE: Values are not both True")
        print(f"   This would cause the quiz dialog to be shown")
        print(f"   Expected: health_quiz_completed=True, is_still_valid=True")
        print(f"   Actual: health_quiz_completed={health_quiz_completed}, is_still_valid={is_still_valid}")

    print("\n" + "=" * 50)

if __name__ == "__main__":
    try:
        test_eligibility_api()
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to backend server.")
        print("   Make sure Django server is running on http://localhost:8000")
    except Exception as e:
        print(f"❌ Error: {e}")
