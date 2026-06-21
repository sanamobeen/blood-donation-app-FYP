"""
API Views for AI Chatbot Assistant.

Provides endpoints for asking questions, getting chat history, and feedback.
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
import uuid
import logging

from .models import FAQ, ChatHistory, UserFeedback
from .serializers import (
    FAQSerializer,
    ChatHistorySerializer,
    ChatRequestSerializer,
    ChatResponseSerializer,
    FeedbackSerializer
)
from .chatbot_service import get_chatbot, reload_chatbot

logger = logging.getLogger(__name__)


def success_response(message, data=None, status_code=200):
    """Create a standardized success response."""
    response = {'success': True, 'message': message}
    if data:
        response.update(data)
    return Response(response, status=status_code)


def error_response(message, errors=None, status_code=400):
    """Create a standardized error response."""
    response = {'success': False, 'message': message}
    if errors:
        response['errors'] = errors
    return Response(response, status=status_code)


@api_view(['POST'])
@permission_classes([AllowAny])
def chat(request):
    """
    Ask the AI chatbot a question.

    POST /api/assistant/chat/

    Body: {
        "question": "Is blood donation safe?",
        "session_id": "uuid (optional)"
    }

    Returns the best matching answer with confidence score.
    """
    try:
        # Validate request
        serializer = ChatRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response('Invalid request.', errors=serializer.errors)

        user_question = serializer.validated_data['question']
        user_role = serializer.validated_data.get('role', 'both')
        session_id = serializer.validated_data.get('session_id')

        # Get answer from chatbot with role filtering
        chatbot = get_chatbot()
        result = chatbot.get_answer(user_question, user_role=user_role)

        # Generate session ID if not provided
        if not session_id:
            session_id = uuid.uuid4()

        # Save chat history
        chat_entry = ChatHistory.objects.create(
            session_id=session_id,
            user_question=user_question,
            bot_answer=result['answer'],
            confidence_score=result['confidence'],
            category=result.get('category'),
        )

        # Link matched FAQ if found
        if result.get('faq_id'):
            try:
                matched_faq = FAQ.objects.get(id=result['faq_id'])
                chat_entry.matched_faq = matched_faq
                chat_entry.save()
            except FAQ.DoesNotExist:
                pass

        logger.info(f"Chat query: {user_question[:50]}... -> confidence: {result['confidence']:.2f}")

        return success_response(
            'Answer retrieved.',
            {
                'answer': result['answer'],
                'confidence': result['confidence'],
                'category': result.get('category'),
                'matched_question': result.get('matched_question'),
                'session_id': session_id
            }
        )

    except Exception as e:
        logger.error(f"Error in chat: {str(e)}", exc_info=True)
        return error_response('Failed to process question.', status_code=500)


@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """
    Health check endpoint for the chatbot.

    GET /api/assistant/health/

    Returns the status of the chatbot service.
    """
    try:
        chatbot = get_chatbot()
        faq_count = len(chatbot.faq_data) if chatbot.faq_data else 0

        return success_response(
            'Chatbot is healthy.',
            {
                'status': 'healthy',
                'faq_count': faq_count,
                'confidence_threshold': chatbot.confidence_threshold
            }
        )
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}", exc_info=True)
        return error_response('Chatbot is not healthy.', status_code=503)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def chat_history(request):
    """
    Get chat history for a session or user.

    GET /api/assistant/history/

    Query params:
        - session_id: Get history for specific session
        - limit: Number of entries (default: 20)

    Returns chat history entries.
    """
    try:
        session_id = request.GET.get('session_id')
        limit = int(request.GET.get('limit', 20))

        # Filter by session if provided
        if session_id:
            history = ChatHistory.objects.filter(
                session_id=session_id
            ).order_by('-created_at')[:limit]
        else:
            # For authenticated users, could return their sessions
            # For now, return recent history
            history = ChatHistory.objects.all().order_by('-created_at')[:limit]

        serializer = ChatHistorySerializer(history, many=True)

        return success_response(
            'Chat history retrieved.',
            {
                'history': serializer.data,
                'count': history.count()
            }
        )

    except Exception as e:
        logger.error(f"Error getting chat history: {str(e)}", exc_info=True)
        return error_response('Failed to retrieve chat history.', status_code=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_feedback(request):
    """
    Submit feedback on a chatbot response.

    POST /api/assistant/feedback/

    Body: {
        "chat_history_id": "uuid",
        "is_helpful": true,
        "comment": "Optional comment",
        "suggested_answer": "Optional better answer"
    }
    """
    try:
        chat_history_id = request.data.get('chat_history_id')
        is_helpful = request.data.get('is_helpful')
        comment = request.data.get('comment', '')
        suggested_answer = request.data.get('suggested_answer', '')

        if not chat_history_id or is_helpful is None:
            return error_response('chat_history_id and is_helpful are required.')

        # Get chat history
        try:
            chat_entry = ChatHistory.objects.get(id=chat_history_id)
        except ChatHistory.DoesNotExist:
            return error_response('Chat entry not found.', status_code=404)

        # Create feedback
        feedback = UserFeedback.objects.create(
            chat_history=chat_entry,
            is_helpful=is_helpful,
            comment=comment,
            suggested_answer=suggested_answer
        )

        # Update chat entry satisfaction
        chat_entry.user_satisfied = is_helpful
        chat_entry.save()

        logger.info(f"Feedback submitted: is_helpful={is_helpful} for chat {chat_history_id}")

        return success_response(
            'Feedback submitted successfully.',
            {'feedback_id': str(feedback.id)}
        )

    except Exception as e:
        logger.error(f"Error submitting feedback: {str(e)}", exc_info=True)
        return error_response('Failed to submit feedback.', status_code=500)


@api_view(['GET'])
@permission_classes([AllowAny])
def faq_list(request):
    """
    Get list of all FAQs (for reference).

    GET /api/assistant/faqs/

    Returns all active FAQs.
    """
    try:
        faqs = FAQ.objects.filter(is_active=True).order_by('-priority', 'category')
        serializer = FAQSerializer(faqs, many=True)

        return success_response(
            'FAQs retrieved.',
            {
                'faqs': serializer.data,
                'count': faqs.count()
            }
        )

    except Exception as e:
        logger.error(f"Error getting FAQs: {str(e)}", exc_info=True)
        return error_response('Failed to retrieve FAQs.', status_code=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])  # Admin only in production
def reload_chatbot_cache(request):
    """
    Reload the chatbot cache (after updating FAQs).

    POST /api/assistant/reload/

    This reloads the FAQ data from database into the chatbot.
    """
    try:
        chatbot = reload_chatbot()

        return success_response(
            'Chatbot reloaded successfully.',
            {
                'faq_count': len(chatbot.faq_data) if chatbot.faq_data else 0
            }
        )

    except Exception as e:
        logger.error(f"Error reloading chatbot: {str(e)}", exc_info=True)
        return error_response('Failed to reload chatbot.', status_code=500)
