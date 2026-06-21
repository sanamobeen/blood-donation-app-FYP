"""
Blood Donation Chatbot - Test Script
Run this file to test the chatbot functionality
"""

from interactive_chatbot import BloodDonationChatbot

def test_chatbot():
    """Test the chatbot with various questions"""

    # Initialize chatbot
    print("Initializing Blood Donation Chatbot...")
    bot = BloodDonationChatbot('faq.csv', confidence_threshold=0.5)

    # Test questions covering different categories
    test_cases = [
        # Safety questions
        ("Is blood donation safe?", "safety_risks"),

        # Frequency questions
        ("How often can I donate blood?", "donation_frequency_limits"),

        # Blood type compatibility
        ("Who can donate to A+?", "blood_type_compatibility"),

        # Eligibility questions
        ("What is the minimum age?", "eligibility_requirements"),
        ("Can a diabetic donate blood?", "benefits_of_donation"),

        # Medical conditions
        ("Can people with tattoos donate?", "eligibility_requirements"),

        # Preparation
        ("What should I eat before donating?", "preparation_for_donation"),

        # Unrelated questions (should be filtered)
        ("How do I make a pizza?", None),
        ("What is the capital of France?", None),
    ]

    print("="*70)
    print("Blood Donation Chatbot - Test Results")
    print("="*70)

    passed = 0
    failed = 0

    for question, expected_category in test_cases:
        result = bot.get_answer(question)

        # Check if result contains expected category or error for unrelated
        if expected_category is None:
            # Should be filtered out
            if "[ERROR]" in result:
                status = "[PASS]"
                passed += 1
            else:
                status = "[FAIL]"
                failed += 1
        else:
            # Should have category in result
            if f"[{expected_category}]" in result or "[OK]" in result:
                status = "[PASS]"
                passed += 1
            else:
                status = "[FAIL]"
                failed += 1

        print(f"\n{status}")
        print(f"Q: {question}")
        if len(result) > 80:
            print(f"A: {result[:80]}...")
        else:
            print(f"A: {result}")

    print("\n" + "="*70)
    print(f"Test Results: {passed} passed, {failed} failed out of {len(test_cases)} tests")
    print("="*70)

    return passed, failed

def test_interactive():
    """Test interactive mode"""
    print("\n" + "="*70)
    print("Interactive Chatbot Test")
    print("="*70)
    print("Type 'exit' to quit interactive mode\n")

    bot = BloodDonationChatbot('faq.csv', confidence_threshold=0.5)

    while True:
        try:
            question = input("You: ").strip()
            if question.lower() in ['exit', 'quit']:
                print("Exiting interactive mode...")
                break

            if question:
                response = bot.get_answer(question)
                print(f"Bot: {response}\n")

        except KeyboardInterrupt:
            print("\nExiting...")
            break

if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "interactive":
        test_interactive()
    else:
        test_chatbot()
