#!/usr/bin/env python
"""
True RAG Implementation Test Script

This script tests the True RAG implementation with LLM generation.

Usage:
    # Set your API key first
    export OPENAI_API_KEY="sk-your-key-here"

    # Then run
    python test_rag_implementation.py
"""

import os
import sys

def check_dependencies():
    """Check if required dependencies are installed"""
    print("Checking dependencies...")

    missing = []

    try:
        import openai
        print("  ✓ openai installed")
    except ImportError:
        missing.append("openai")
        print("  ✗ openai NOT installed (run: pip install openai)")

    try:
        import anthropic
        print("  ✓ anthropic installed")
    except ImportError:
        print("  - anthropic optional (run: pip install anthropic for Claude)")

    try:
        import requests
        print("  ✓ requests installed")
    except ImportError:
        missing.append("requests")
        print("  ✗ requests NOT installed (run: pip install requests)")

    if missing:
        print(f"\n⚠ Missing dependencies: {', '.join(missing)}")
        return False
    return True

def check_api_key():
    """Check if API key is set"""
    print("\nChecking API configuration...")

    api_key = os.environ.get('OPENAI_API_KEY')
    if api_key:
        print(f"  ✓ OPENAI_API_KEY is set (sk-{api_key[-10:]}...")
        return True
    else:
        print("  ✗ OPENAI_API_KEY NOT set")
        print("  Please set: export OPENAI_API_KEY='sk-your-key-here'")
        return False

def setup_django():
    """Setup Django environment"""
    print("\nSetting up Django...")
    try:
        import django
        from pathlib import Path

        backend_dir = Path(__file__).parent / 'django-backend'
        sys.path.insert(0, str(backend_dir))
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
        django.setup()

        print("  ✓ Django setup complete")
        return True
    except Exception as e:
        print(f"  ✗ Django setup failed: {e}")
        return False

def test_rag_implementation():
    """Test the RAG implementation"""
    print("\n" + "=" * 70)
    print("TESTING TRUE RAG IMPLEMENTATION")
    print("=" * 70)

    try:
        from assistant.rag_chatbot_service import TrueRAGChatbot, get_rag_chatbot

        print("\n[1/4] Initializing RAG Chatbot...")
        chatbot = get_rag_chatbot()
        print("  ✓ RAG Chatbot initialized")
        print(f"  - LLM Provider: {chatbot.llm_provider}")
        print(f"  - LLM Model: {chatbot.llm_model}")
        print(f"  - Temperature: {chatbot.temperature}")
        print(f"  - Top-K FAQs: {chatbot.top_k}")
        print(f"  - Total FAQs loaded: {len(chatbot.faq_data) if chatbot.faq_data else 0}")

        print("\n[2/4] Testing Retrieval (TF-IDF Search)...")
        test_question = "Is blood donation safe?"
        relevant_faqs = chatbot._retrieve_relevant_faqs(test_question, user_role='both')
        print(f"  ✓ Retrieved {len(relevant_faqs)} relevant FAQs")
        for i, faq_item in enumerate(relevant_faqs[:3], 1):
            print(f"    {i}. {faq_item['faq']['question'][:50]}... (similarity: {faq_item['similarity']:.2f})")

        print("\n[3/4] Testing Context Building...")
        context = chatbot._build_context(relevant_faqs)
        print(f"  ✓ Context built ({len(context)} characters)")
        print(f"  Preview: {context[:200]}...")

        print("\n[4/4] Testing LLM Generation...")
        print("  This may take a few seconds...")
        result = chatbot.get_answer(test_question, user_role='both', use_rag=True)
        print("  ✓ Response generated")
        print(f"  - Method: {result.get('method', 'unknown')}")
        print(f"  - Confidence: {result['confidence']:.2f}")
        print(f"  - Category: {result.get('category', 'N/A')}")
        print(f"  - Answer: {result['answer'][:200]}...")

        return True

    except Exception as e:
        print(f"\n  ✗ Test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def compare_direct_vs_rag():
    """Compare direct FAQ vs RAG responses"""
    print("\n" + "=" * 70)
    print("COMPARING DIRECT FAQ vs TRUE RAG")
    print("=" * 70)

    try:
        from assistant.rag_chatbot_service import get_rag_chatbot
        from assistant.chatbot_service import get_chatbot

        rag_chatbot = get_rag_chatbot()
        direct_chatbot = get_chatbot()

        test_questions = [
            ("Hello", "both"),
            ("Is blood donation safe?", "donor"),
            ("How often can I donate?", "donor"),
        ]

        for question, role in test_questions:
            print(f"\n{'─' * 70}")
            print(f"Question: {question}")
            print(f"Role: {role}")

            # Direct FAQ
            direct_result = direct_chatbot.get_answer(question, user_role=role)
            print(f"\nDIRECT FAQ:")
            print(f"  Confidence: {direct_result['confidence']:.2f}")
            print(f"  Answer: {direct_result['answer'][:150]}...")

            # RAG
            rag_result = rag_chatbot.get_answer(question, user_role=role, use_rag=True)
            print(f"\nTRUE RAG:")
            print(f"  Method: {rag_result.get('method', 'unknown')}")
            print(f"  Confidence: {rag_result['confidence']:.2f}")
            print(f"  Answer: {rag_result['answer'][:150]}...")

        print("\n" + "=" * 70)
        print("COMPARISON COMPLETE")
        print("=" * 70)

    except Exception as e:
        print(f"Comparison failed: {e}")
        import traceback
        traceback.print_exc()

def main():
    """Main test function"""
    print("=" * 70)
    print("TRUE RAG IMPLEMENTATION TEST")
    print("=" * 70)

    # Step 1: Check dependencies
    if not check_dependencies():
        print("\n⚠ Please install missing dependencies first")
        return False

    # Step 2: Check API key
    if not check_api_key():
        print("\n⚠ Please set your API key first")
        print("\nFor OpenAI:")
        print("  export OPENAI_API_KEY='sk-your-key-here'")
        print("\nFor Anthropic:")
        print("  export ANTHROPIC_API_KEY='sk-your-key-here'")
        return False

    # Step 3: Setup Django
    if not setup_django():
        print("\n⚠ Django setup failed")
        return False

    # Step 4: Test RAG implementation
    if not test_rag_implementation():
        print("\n⚠ RAG implementation test failed")
        return False

    # Step 5: Compare direct vs RAG
    compare_direct_vs_rag()

    print("\n" + "=" * 70)
    print("✓ ALL TESTS COMPLETE")
    print("=" * 70)
    print("\nThe True RAG implementation is working!")
    print("You can now use it in your chatbot.")

    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
