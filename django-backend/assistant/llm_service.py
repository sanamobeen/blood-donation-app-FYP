"""
OpenRouter LLM Service for Blood Donation Chatbot

This service integrates with OpenRouter API to provide LLM-powered responses
with streaming support while restricting answers to blood donation topics only.
"""
import os
import requests
import json
from typing import Dict, Optional, Generator


class OpenRouterLLMService:
    """LLM Service using OpenRouter API for blood donation chatbot with streaming"""

    def __init__(self):
        self.api_key = os.environ.get('OPENROUTER_API_KEY')
        self.api_url = os.environ.get('OPENROUTER_API_URL', 'https://openrouter.ai/api/v1/chat/completions')
        self.referer_url = os.environ.get('OPENROUTER_REFERER_URL', 'https://blood-donation-app.com')
        self.app_title = os.environ.get('OPENROUTER_APP_TITLE', 'Blood Donation App')

        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY environment variable not set")

    def get_system_message(self) -> str:
        """Get the system prompt that restricts the LLM to blood donation topics"""
        return """You are a Blood Donation Assistant.

You can answer questions related to:
- Blood donation
- Blood groups and compatibility
- Donor eligibility requirements
- Donation process and procedures
- Blood requests and finding donors
- Donation benefits and safety
- Post-donation care
- Blood donation centers
- Medical conditions related to donation
- App features and navigation
- Greetings and general conversation (hi, hello, bye, thanks, etc.)

If the user asks anything outside these topics (like tech specs, politics, weather, etc.), reply exactly:
'Sorry, I can only assist with blood donation related questions.'

For greetings like "hi", "hello", "hey", respond warmly and offer to help with blood donation questions.

Keep your responses:
- Clear and concise (2-4 sentences when possible)
- Friendly and helpful
- Factual and accurate
- Include relevant safety information when applicable
- For medical questions, always recommend consulting healthcare professionals"""

    def get_answer(self, user_message: str, user_role: str = 'both', stream: bool = False) -> Dict:
        """
        Get answer from LLM for user message (non-streaming)

        Args:
            user_message: The user's question
            user_role: User's role (donor/patient/both) for context
            stream: Whether to stream the response (ignored here, use stream_answer instead)

        Returns:
            Dict with answer, method, and metadata
        """
        # Build role context
        role_context = {
            'donor': 'The user is a potential blood donor.',
            'patient': 'The user is a patient or family member seeking blood.',
            'both': 'The user could be a donor or patient.'
        }.get(user_role, 'The user could be a donor or patient.')

        # Build messages
        messages = [
            {
                "role": "system",
                "content": self.get_system_message()
            },
            {
                "role": "user",
                "content": f"{role_context}\n\nUser question: {user_message}"
            }
        ]

        # Make API request
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "HTTP-Referer": self.referer_url,
            "X-Title": self.app_title
        }

        payload = {
            "model": os.environ.get('OPENROUTER_MODEL', 'openrouter/free'),
            "messages": messages,
            "temperature": float(os.environ.get('LLM_TEMPERATURE', '0.7')),
            "max_tokens": int(os.environ.get('LLM_MAX_TOKENS', '500'))
        }

        try:
            response = requests.post(
                self.api_url,
                headers=headers,
                json=payload,
                timeout=30
            )

            if response.status_code == 200:
                data = response.json()
                answer = data['choices'][0]['message']['content'].strip()

                return {
                    'answer': answer,
                    'method': 'llm',
                    'model': data.get('model', 'unknown'),
                    'usage': data.get('usage', {})
                }
            else:
                return {
                    'answer': "Sorry, I'm having trouble connecting right now. Please try again.",
                    'method': 'llm',
                    'error': f"API returned {response.status_code}"
                }

        except requests.exceptions.Timeout:
            return {
                'answer': "Sorry, the service is taking too long to respond. Please try again.",
                'method': 'llm',
                'error': 'timeout'
            }
        except Exception as e:
            return {
                'answer': "Sorry, I encountered an error. Please try again.",
                'method': 'llm',
                'error': str(e)
            }

    def stream_answer(self, user_message: str, user_role: str = 'both') -> Generator[str, None, None]:
        """
        Stream answer from LLM for user message

        Args:
            user_message: The user's question
            user_role: User's role (donor/patient/both) for context

        Yields:
            Chunks of the answer as they arrive
        """
        # Build role context
        role_context = {
            'donor': 'The user is a potential blood donor.',
            'patient': 'The user is a patient or family member seeking blood.',
            'both': 'The user could be a donor or patient.'
        }.get(user_role, 'The user could be a donor or patient.')

        # Build messages
        messages = [
            {
                "role": "system",
                "content": self.get_system_message()
            },
            {
                "role": "user",
                "content": f"{role_context}\n\nUser question: {user_message}"
            }
        ]

        # Make API request with streaming
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
            "HTTP-Referer": self.referer_url,
            "X-Title": self.app_title
        }

        payload = {
            "model": os.environ.get('OPENROUTER_MODEL', 'openrouter/free'),
            "messages": messages,
            "temperature": float(os.environ.get('LLM_TEMPERATURE', '0.7')),
            "max_tokens": int(os.environ.get('LLM_MAX_TOKENS', '500')),
            "stream": True  # Enable streaming
        }

        try:
            response = requests.post(
                self.api_url,
                headers=headers,
                json=payload,
                stream=True,  # Enable streaming in requests
                timeout=30
            )

            if response.status_code == 200:
                for line in response.iter_lines():
                    if line:
                        line = line.decode('utf-8') if isinstance(line, bytes) else line
                        if line.startswith('data: '):
                            data_str = line[6:]  # Remove 'data: ' prefix
                            if data_str == '[DONE]':
                                break
                            try:
                                data = json.loads(data_str)
                                if 'choices' in data and len(data['choices']) > 0:
                                    delta = data['choices'][0].get('delta', {})
                                    content = delta.get('content', '')
                                    if content:
                                        yield content
                            except json.JSONDecodeError:
                                continue
                yield '[DONE]'  # Signal completion
            else:
                yield f"Error: API returned {response.status_code}"

        except requests.exceptions.Timeout:
            yield "Error: Request timed out. Please try again."
        except Exception as e:
            yield f"Error: {str(e)}"


# Singleton instance
_llm_service_instance = None


def get_llm_service():
    """Get or create the LLM service instance"""
    global _llm_service_instance
    if _llm_service_instance is None:
        _llm_service_instance = OpenRouterLLMService()
    return _llm_service_instance
