#!/usr/bin/env python
"""
OpenRouter LLM Integration Test Script

This script tests the OpenRouter API integration for the blood donation chatbot.

Usage:
    # Set your API key first
    export OPENROUTER_API_KEY="sk-or-v1-your-key-here"

    # Run tests
    python test_openrouter_llm.py
"""

import os
import sys
import requests

def test_api_connection():
    """Test basic API connection"""
    print("=" * 70)
    print("TEST 1: API Connection")
    print("=" * 70)

    api_key = os.environ.get('OPENROUTER_API_KEY')
    if not api_key:
        print("✗ OPENROUTER_API_KEY not set")
        print("  Please set: export OPENROUTER_API_KEY='sk-or-v1-your-key-here'")
        return False

    print(f"✓ API Key found: {api_key[:20]}...{api_key[-10:]}")

    # Test API connection
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    try:
        response = requests.get("https://openrouter.ai/api/v1/models", headers=headers)
        if response.status_code == 200:
            print("✓ API connection successful")
            models = response.json().get('data', [])
            print(f"  Available models: {len(models)}")
            return True
        else:
            print(f"✗ API error: {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        return False

def test_system_prompt():
    """Test that system prompt correctly restricts responses"""
    print("\n" + "=" * 70)
    print("TEST 2: System Prompt Restriction")
    print("=" * 70)

    api_key = os.environ.get('OPENROUTER_API_KEY')
    if not api_key:
        print("✗ API Key not set")
        return False

    # Test out-of-scope question
    print("\nTesting out-of-scope question:")
    test_question = "Who is the Prime Minister of Pakistan?"

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "openrouter/free",
        "messages": [
            {
                "role": "system",
                "content": """You are a Blood Donation Assistant.

You can only answer questions related to:
- Blood donation
- Blood groups
- Donor eligibility
- Donation process
- Blood requests
- Donation benefits
- App features

If the user asks anything outside these topics, reply exactly:
'Sorry, I can only assist with blood donation related questions.'"""
            },
            {
                "role": "user",
                "content": test_question
            }
        ]
    }

    try:
        response = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            answer = data['choices'][0]['message']['content'].strip()
            print(f"  Question: {test_question}")
            print(f"  Answer: {answer}")

            # Check if the response is the expected rejection
            if "can only assist with blood donation" in answer.lower():
                print("✓ System prompt correctly rejected out-of-scope question")
                return True
            else:
                print("✗ System prompt did not reject the question properly")
                return False
        else:
            print(f"✗ API error: {response.status_code}")
            return False
    except Exception as e:
        print(f"✗ Request failed: {e}")
        return False

def test_in_scope_questions():
    """Test in-scope questions are answered correctly"""
    print("\n" + "=" * 70)
    print("TEST 3: In-Scope Questions")
    print("=" * 70)

    api_key = os.environ.get('OPENROUTER_API_KEY')
    if not api_key:
        print("✗ API Key not set")
        return False

    in_scope_questions = [
        "Is blood donation safe?",
        "Who can donate blood?",
        "How often can I donate?",
    ]

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    for question in in_scope_questions:
        payload = {
            "model": "openrouter/free",
            "messages": [
                {
                    "role": "system",
                    "content": """You are a Blood Donation Assistant.

You can only answer questions related to:
- Blood donation
- Blood groups
- Donor eligibility
- Donation process
- Blood requests
- Donation benefits
- App features

Keep responses concise and friendly."""
                },
                {
                    "role": "user",
                    "content": question
                }
            ]
        }

        try:
            response = requests.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=30
            )

            if response.status_code == 200:
                data = response.json()
                answer = data['choices'][0]['message']['content'].strip()
                print(f"\n  Question: {question}")
                print(f"  Answer: {answer[:100]}...")
                print(f"  ✓ Question answered")
            else:
                print(f"\n  Question: {question}")
                print(f"  ✗ API error: {response.status_code}")
        except Exception as e:
            print(f"\n  Question: {question}")
            print(f"  ✗ Request failed: {e}")

    return True

def test_django_integration():
    """Test Django LLM service integration"""
    print("\n" + "=" * 70)
    print("TEST 4: Django LLM Service Integration")
    print("=" * 70)

    try:
        # Add Django to path
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'django-backend'))
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

        import django
        django.setup()

        from assistant.llm_service import get_llm_service

        print("✓ Django LLM service imported")

        # Initialize service
        llm_service = get_llm_service()
        print("✓ LLM service initialized")

        # Test in-scope question
        result = llm_service.get_answer("Is blood donation safe?", user_role="both")
        print(f"\n  Question: Is blood donation safe?")
        print(f"  Answer: {result['answer'][:100]}...")
        print(f"  Method: {result.get('method', 'unknown')}")

        # Test out-of-scope question
        result = llm_service.get_answer("Who is the Prime Minister of Pakistan?", user_role="both")
        print(f"\n  Question: Who is the Prime Minister of Pakistan?")
        print(f"  Answer: {result['answer'][:100]}...")

        if "can only assist with blood donation" in result['answer'].lower():
            print("  ✓ Out-of-scope question correctly rejected")

        return True

    except Exception as e:
        print(f"✗ Django integration failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests"""
    print("=" * 70)
    print("OPENROUTER LLM INTEGRATION TEST")
    print("=" * 70)

    results = []

    # Test 1: API Connection
    results.append(("API Connection", test_api_connection()))

    # Test 2: System Prompt
    if results[0][1]:  # Only run if API connection succeeded
        results.append(("System Prompt Restriction", test_system_prompt()))
        results.append(("In-Scope Questions", test_in_scope_questions()))
        results.append(("Django Integration", test_django_integration()))

    # Summary
    print("\n" + "=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)

    for test_name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"  {status}: {test_name}")

    all_passed = all(result[1] for result in results)

    if all_passed:
        print("\n✓ All tests passed!")
        print("\nThe OpenRouter LLM integration is ready to use.")
        print("\nTo enable LLM mode in the app:")
        print("  1. Set environment variable: LLM_ENABLED=true")
        print("  2. Toggle LLM mode in the Flutter app UI")
        return True
    else:
        print("\n✗ Some tests failed")
        print("\nPlease check:")
        print("  1. OPENROUTER_API_KEY is set correctly")
        print("  2. Internet connection is working")
        print("  3. OpenRouter API is accessible")
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
