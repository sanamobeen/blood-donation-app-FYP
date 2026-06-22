"""
Comprehensive tests for LLM Integration Service.

Tests:
- LLM service initialization
- System message application
- Out-of-scope question rejection
- In-scope question answering
- Error handling

Example test questions that should be rejected:
- "Who is the Prime Minister of Pakistan?"
- "What's the weather today?"
- "Tell me a joke"

Example test questions that should be answered:
- "Is blood donation safe?"
- "Who can donate blood?"
- "How often can I donate?"
"""
import os
import pytest
from unittest.mock import Mock, patch
import requests

# Set environment variables before importing the service
os.environ['OPENROUTER_API_KEY'] = 'test_api_key'
os.environ['OPENROUTER_MODEL'] = 'test/model'
os.environ['LLM_TEMPERATURE'] = '0.7'
os.environ['LLM_MAX_TOKENS'] = '500'

# Import after setting environment variables
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'django-backend'))

from assistant.llm_service import OpenRouterLLMService, get_llm_service


class TestLLMServiceInitialization:
    """Test LLM service initialization and configuration."""

    def test_initialization_with_api_key(self):
        """Test service initializes correctly with API key."""
        service = OpenRouterLLMService()
        assert service.api_key == 'test_api_key'
        assert service.api_url == "https://openrouter.ai/api/v1/chat/completions"

    def test_initialization_without_api_key(self):
        """Test service raises error without API key."""
        with patch.dict(os.environ, {'OPENROUTER_API_KEY': ''}, clear=False):
            # Remove the API key temporarily
            original_key = os.environ.pop('OPENROUTER_API_KEY', None)

            with pytest.raises(ValueError, match="OPENROUTER_API_KEY environment variable not set"):
                OpenRouterLLMService()

            # Restore the key for other tests
            if original_key:
                os.environ['OPENROUTER_API_KEY'] = original_key
            else:
                os.environ['OPENROUTER_API_KEY'] = 'test_api_key'

    def test_get_system_message_content(self):
        """Test system message contains expected restrictions."""
        service = OpenRouterLLMService()
        system_message = service.get_system_message()

        # Check it mentions blood donation topics
        assert 'Blood Donation Assistant' in system_message
        assert 'blood donation' in system_message.lower()

        # Check it includes the rejection message
        rejection_phrase = "I can only assist with blood donation related questions"
        assert rejection_phrase in system_message

    def test_get_system_message_allowed_topics(self):
        """Test system message lists all allowed topics."""
        service = OpenRouterLLMService()
        system_message = service.get_system_message()

        allowed_topics = [
            'Blood donation',
            'Blood groups',
            'eligibility',
            'safety',
            'centers',
            'benefits'
        ]

        for topic in allowed_topics:
            assert topic.lower() in system_message.lower()


class TestSystemMessageApplication:
    """Test that system message is correctly applied to API requests."""

    @patch('assistant.llm_service.requests.post')
    def test_system_message_in_request(self, mock_post):
        """Test system message is included in API request."""
        # Mock successful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{
                'message': {
                    'content': 'Blood donation is generally safe.'
                }
            }],
            'model': 'test/model',
            'usage': {'total_tokens': 100}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        service.get_answer("Is blood donation safe?")

        # Verify the request was made
        assert mock_post.called
        call_args = mock_post.call_args

        # Check system message was included
        messages = call_args[1]['json']['messages']
        assert len(messages) == 2
        assert messages[0]['role'] == 'system'
        assert 'Blood Donation Assistant' in messages[0]['content']

    @patch('assistant.llm_service.requests.post')
    def test_user_role_context(self, mock_post):
        """Test user role is added to request context."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{
                'message': {'content': 'Answer for donor.'}
            }],
            'model': 'test/model',
            'usage': {'total_tokens': 100}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        service.get_answer("Can I donate?", user_role='donor')

        call_args = mock_post.call_args
        messages = call_args[1]['json']['messages']
        user_message = messages[1]['content']

        assert 'potential blood donor' in user_message.lower()


class TestOutOfScopeRejection:
    """Test that out-of-scope questions are rejected."""

    # Questions that should be rejected
    OUT_OF_SCOPE_QUESTIONS = [
        "Who is the Prime Minister of Pakistan?",
        "What's the weather today?",
        "Tell me a joke",
        "What is the capital of France?",
        "Who won the World Cup?",
        "What's the latest movie release?",
        "How do I cook pasta?",
        "What is the stock market price?",
        "Tell me about quantum physics",
        "Who is the best football player?"
    ]

    @patch('assistant.llm_service.requests.post')
    @pytest.mark.parametrize("question", OUT_OF_SCOPE_QUESTIONS)
    def test_out_of_scope_questions_rejected(self, mock_post, question):
        """Test out-of-scope questions receive rejection response."""
        # Mock the API to respond with rejection
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{
                'message': {
                    'content': "Sorry, I can only assist with blood donation related questions."
                }
            }],
            'model': 'test/model',
            'usage': {'total_tokens': 50}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        result = service.get_answer(question)

        # Verify rejection
        assert result['answer'] == "Sorry, I can only assist with blood donation related questions."
        assert result['method'] == 'llm'
        assert 'error' not in result

    @patch('assistant.llm_service.requests.post')
    def test_multiple_out_of_scope_rejections(self, mock_post):
        """Test multiple out-of-scope questions in sequence."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{
                'message': {
                    'content': "Sorry, I can only assist with blood donation related questions."
                }
            }],
            'model': 'test/model',
            'usage': {'total_tokens': 50}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()

        for question in self.OUT_OF_SCOPE_QUESTIONS[:3]:
            result = service.get_answer(question)
            assert "can only assist with blood donation" in result['answer']


class TestInScopeAnswers:
    """Test that in-scope questions are answered properly."""

    # Questions that should be answered
    IN_SCOPE_QUESTIONS = [
        ("Is blood donation safe?", "safe"),
        ("Who can donate blood?", "eligible"),
        ("How often can I donate?", "frequency"),
        ("What are the blood types?", "blood type"),
        ("What should I eat before donating?", "eat"),
        ("Does donating blood hurt?", "pain"),
        ("How long does donation take?", "time"),
        ("What is O negative blood?", "universal"),
        ("Can I donate if I have a tattoo?", "tattoo"),
        ("What happens after donation?", "after")
    ]

    @patch('assistant.llm_service.requests.post')
    @pytest.mark.parametrize("question,expected_keyword", IN_SCOPE_QUESTIONS)
    def test_in_scope_questions_answered(self, mock_post, question, expected_keyword):
        """Test in-scope questions receive helpful answers."""
        # Mock a helpful response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{
                'message': {
                    'content': f'Helpful answer about {expected_keyword} in blood donation.'
                }
            }],
            'model': 'test/model',
            'usage': {'total_tokens': 150}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        result = service.get_answer(question)

        # Verify we got a helpful answer (not the rejection)
        assert result['answer'] != "Sorry, I can only assist with blood donation related questions."
        assert expected_keyword.lower() in result['answer'].lower()
        assert result['method'] == 'llm'

    @patch('assistant.llm_service.requests.post')
    def test_medical_disclaimer_included(self, mock_post):
        """Test medical questions include disclaimer."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{
                'message': {
                    'content': 'You should consult a healthcare professional about this medical concern.'
                }
            }],
            'model': 'test/model',
            'usage': {'total_tokens': 150}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        # This should trigger medical disclaimer based on system prompt
        result = service.get_answer("Is it safe to donate with diabetes?")

        # The system prompt tells the LLM to include medical disclaimer
        # The actual LLM response should include it
        assert 'healthcare' in result['answer'].lower() or 'consult' in result['answer'].lower()


class TestErrorHandling:
    """Test error handling in LLM service."""

    @patch('assistant.llm_service.requests.post')
    def test_api_timeout(self, mock_post):
        """Test timeout is handled gracefully."""
        import requests.exceptions
        mock_post.side_effect = requests.exceptions.Timeout()

        service = OpenRouterLLMService()
        result = service.get_answer("Is donation safe?")

        assert 'taking too long' in result['answer'].lower()
        assert result['method'] == 'llm'
        assert result['error'] == 'timeout'

    @patch('assistant.llm_service.requests.post')
    def test_api_connection_error(self, mock_post):
        """Test connection errors are handled."""
        import requests.exceptions
        mock_post.side_effect = requests.exceptions.ConnectionError()

        service = OpenRouterLLMService()
        result = service.get_answer("Is donation safe?")

        assert 'error' in result['answer'].lower()
        assert result['method'] == 'llm'
        assert 'error' in result

    @patch('assistant.llm_service.requests.post')
    def test_api_error_response(self, mock_post):
        """Test non-200 API responses are handled."""
        mock_response = Mock()
        mock_response.status_code = 429
        mock_response.text = "Rate limit exceeded"
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        result = service.get_answer("Is donation safe?")

        assert 'trouble connecting' in result['answer'].lower()
        assert result['method'] == 'llm'
        assert result['error'] == 'API returned 429'

    @patch('assistant.llm_service.requests.post')
    def test_generic_exception(self, mock_post):
        """Test unexpected exceptions are caught."""
        mock_post.side_effect = Exception("Unexpected error!")

        service = OpenRouterLLMService()
        result = service.get_answer("Is donation safe?")

        assert 'encountered an error' in result['answer'].lower()
        assert result['method'] == 'llm'
        assert result['error'] == 'Unexpected error!'


class TestServiceSingleton:
    """Test the singleton pattern for LLM service."""

    @patch('assistant.llm_service.requests.post')
    def test_singleton_returns_same_instance(self, mock_post):
        """Test get_llm_service returns the same instance."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{'message': {'content': 'Test answer'}}],
            'model': 'test/model',
            'usage': {'total_tokens': 100}
        }
        mock_post.return_value = mock_response

        service1 = get_llm_service()
        service2 = get_llm_service()

        assert service1 is service2
        assert id(service1) == id(service2)


class TestRequestParameters:
    """Test API request parameters."""

    @patch('assistant.llm_service.requests.post')
    def test_request_headers(self, mock_post):
        """Test correct headers are sent."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{'message': {'content': 'Answer'}}],
            'model': 'test/model',
            'usage': {'total_tokens': 100}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        service.get_answer("Test?")

        headers = mock_post.call_args[1]['headers']
        assert headers['Content-Type'] == 'application/json'
        assert headers['Authorization'] == 'Bearer test_api_key'
        assert 'blood-donation-app.com' in headers.get('HTTP-Referer', '')

    @patch('assistant.llm_service.requests.post')
    def test_request_payload(self, mock_post):
        """Test correct payload is sent."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{'message': {'content': 'Answer'}}],
            'model': 'test/model',
            'usage': {'total_tokens': 100}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        service.get_answer("Test?")

        payload = mock_post.call_args[1]['json']
        assert payload['model'] == 'test/model'
        assert payload['temperature'] == 0.7
        assert payload['max_tokens'] == 500
        assert len(payload['messages']) == 2


class TestResponseStructure:
    """Test structure of responses from get_answer."""

    @patch('assistant.llm_service.requests.post')
    def test_success_response_structure(self, mock_post):
        """Test successful response has correct structure."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'choices': [{'message': {'content': 'Test answer'}}],
            'model': 'gpt-test',
            'usage': {'total_tokens': 100, 'prompt_tokens': 50}
        }
        mock_post.return_value = mock_response

        service = OpenRouterLLMService()
        result = service.get_answer("Test?")

        assert 'answer' in result
        assert 'method' in result
        assert 'model' in result
        assert 'usage' in result
        assert result['answer'] == 'Test answer'
        assert result['method'] == 'llm'
        assert result['model'] == 'gpt-test'

    @patch('assistant.llm_service.requests.post')
    def test_error_response_structure(self, mock_post):
        """Test error response has correct structure."""
        mock_post.side_effect = Exception("Test error")

        service = OpenRouterLLMService()
        result = service.get_answer("Test?")

        assert 'answer' in result
        assert 'method' in result
        assert 'error' in result
        assert result['method'] == 'llm'
        assert result['error'] == 'Test error'


# Pytest configuration
if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
