"""
Views for health eligibility quiz system.
"""
import logging
from datetime import datetime, timedelta
from django.utils import timezone
from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from .models import HealthQuizQuestion, HealthQuizResponse, EligibilityRecord
from .serializers import (
    HealthQuizQuestionSerializer,
    HealthQuizResponseSerializer,
    QuizResultSerializer,
    EligibilityRecordSerializer
)

logger = logging.getLogger(__name__)


# Helper functions to create default quiz questions
def create_default_questions():
    """Create default health eligibility quiz questions."""
    default_questions = [
        {
            'question_text': 'Have you donated blood in the last 90 days?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 1
        },
        {
            'question_text': 'Are you currently taking any medications?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 2
        },
        {
            'question_text': 'Have you traveled outside your country in the last 28 days?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 3
        },
        {
            'question_text': 'Have you had any illness, fever, or infection in the last 14 days?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 4
        },
        {
            'question_text': 'Do you weigh at least 45 kg?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 5
        },
        {
            'question_text': 'Have you had any tattoos or piercings in the last 6 months?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 6
        },
        {
            'question_text': 'Have you had any major surgery in the last 6 months?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 7
        },
        {
            'question_text': 'Are you currently breastfeeding or pregnant?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 8
        },
        {
            'question_text': 'Have you ever received a blood transfusion?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 9
        },
        {
            'question_text': 'Do you have any chronic medical conditions (diabetes, HIV, hepatitis, etc.)?',
            'question_type': 'yes_no',
            'options': ['Yes', 'No'],
            'order': 10
        },
    ]

    for question_data in default_questions:
        HealthQuizQuestion.objects.get_or_create(
            order=question_data['order'],
            defaults=question_data
        )


@api_view(['GET'])
@permission_classes([AllowAny])
def get_quiz_questions(request):
    """
    Get all active health quiz questions.

    GET /api/health/quiz/

    Response:
    {
        "success": true,
        "questions": [...]
    }
    """
    try:
        # Create default questions if none exist
        if HealthQuizQuestion.objects.count() == 0:
            create_default_questions()

        questions = HealthQuizQuestion.objects.filter(is_active=True).order_by('order')
        serializer = HealthQuizQuestionSerializer(questions, many=True)

        return Response({
            'success': True,
            'questions': serializer.data
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error fetching quiz questions: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to fetch quiz questions'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_quiz_responses(request):
    """
    Submit user's quiz responses and determine eligibility.

    POST /api/health/quiz/submit/

    Body:
    {
        "responses": {
            "question_id_1": "Yes",
            "question_id_2": "No",
            ...
        }
    }

    Response:
    {
        "success": true,
        "is_eligible": true,
        "message": "...",
        "disqualification_reasons": [],
        "can_proceed": true
    }
    """
    try:
        serializer = HealthQuizResponseSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'message': 'Invalid responses data',
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        responses_data = serializer.validated_data['responses']
        disqualification_reasons = []

        # Check each response for disqualifying answers
        # Get all questions to validate responses
        question_ids = list(responses_data.keys())
        questions = {str(q.id): q for q in HealthQuizQuestion.objects.filter(id__in=question_ids)}

        for q_id, answer in responses_data.items():
            question = questions.get(q_id)
            if not question:
                continue

            # Check for disqualifying answers (typically "Yes" answers)
            # Questions where "Yes" disqualifies:
            disqualifying_questions = [
                'donated blood in the last 90 days',
                'currently taking any medications',
                'traveled outside your country',
                'illness, fever, or infection',
                'tattoos or piercings in the last 6 months',
                'major surgery in the last 6 months',
                'breastfeeding or pregnant',
                'chronic medical conditions'
            ]

            question_lower = question.question_text.lower()
            answer_lower = answer.lower() if isinstance(answer, str) else str(answer)

            # Check if this is a disqualifying question with a "Yes" answer
            if any(phrase in question_lower for phrase in disqualifying_questions):
                if answer_lower in ['yes', 'y', 'true']:
                    disqualification_reasons.append(question.question_text)

            # Specific check for weight question
            if 'weigh' in question_lower:
                if answer_lower in ['no', 'n']:
                    disqualification_reasons.append('Weight must be at least 45kg for blood donation')

        # Determine eligibility
        is_eligible = len(disqualification_reasons) == 0

        # Get client info
        ip_address = get_client_ip(request)
        user_agent = request.META.get('HTTP_USER_AGENT', '')[:500]  # Limit length

        # Save the quiz response
        quiz_response = HealthQuizResponse.objects.create(
            user=request.user,
            responses=responses_data,
            is_eligible=is_eligible,
            disqualification_reasons=disqualification_reasons,
            ip_address=ip_address,
            user_agent=user_agent
        )

        # Update or create eligibility record
        eligibility_record, created = EligibilityRecord.objects.get_or_create(
            user=request.user,
            defaults={
                'is_eligible': is_eligible,
                'last_quiz_date': timezone.now(),
                'last_quiz_response': quiz_response,
                'disqualification_reasons': disqualification_reasons,
                'eligibility_valid_until': timezone.now().date() + timedelta(days=30)
            }
        )

        if not created:
            eligibility_record.is_eligible = is_eligible
            eligibility_record.last_quiz_date = timezone.now()
            eligibility_record.last_quiz_response = quiz_response
            eligibility_record.disqualification_reasons = disqualification_reasons
            eligibility_record.eligibility_valid_until = timezone.now().date() + timedelta(days=30)
            eligibility_record.save()

        # Update user profile health quiz completion status
        from account.models import UserProfile
        try:
            user_profile = UserProfile.objects.get(user=request.user)
            user_profile.health_quiz_completed = True
            user_profile.health_quiz_completed_at = timezone.now()
            user_profile.save(update_fields=['health_quiz_completed', 'health_quiz_completed_at'])
            logger.info(f"Updated health quiz completion status for user {request.user.email}")
        except UserProfile.DoesNotExist:
            logger.warning(f"No profile found for user {request.user.email}")

        # Prepare response message
        if is_eligible:
            message = "Congratulations! You are eligible to request blood donation. You can proceed with creating your blood request."
        else:
            message = "Based on your responses, you may not be eligible to request blood donation at this time. Please consult with a healthcare provider for more information."

        result_serializer = QuizResultSerializer({
            'is_eligible': is_eligible,
            'message': message,
            'disqualification_reasons': disqualification_reasons,
            'can_proceed': is_eligible
        })

        return Response({
            'success': True,
            'data': result_serializer.data
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error submitting quiz responses: {str(e)}")
        return Response({
            'success': False,
            'message': 'Failed to submit quiz responses'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_eligibility_status(request):
    """
    Get user's current eligibility status.

    GET /api/health/eligibility/

    Response:
    {
        "success": true,
        "eligibility": {
            "is_eligible": true,
            "last_quiz_date": "...",
            "eligibility_valid_until": "...",
            "disqualification_reasons": []
        }
    }
    """
    try:
        eligibility_record = EligibilityRecord.objects.filter(
            user=request.user
        ).first()

        if eligibility_record:
            # Check if eligibility is still valid
            is_still_valid = True
            if eligibility_record.eligibility_valid_until:
                if eligibility_record.eligibility_valid_until < timezone.now().date():
                    is_still_valid = False

            serializer = EligibilityRecordSerializer(eligibility_record)
            response_data = serializer.data
            response_data['is_still_valid'] = is_still_valid

            # Add profile health quiz status
            from account.models import UserProfile
            try:
                user_profile = UserProfile.objects.get(user=request.user)
                response_data['health_quiz_completed'] = user_profile.health_quiz_completed
                response_data['health_quiz_completed_at'] = user_profile.health_quiz_completed_at.isoformat() if user_profile.health_quiz_completed_at else None
            except UserProfile.DoesNotExist:
                response_data['health_quiz_completed'] = False
                response_data['health_quiz_completed_at'] = None

            return Response({
                'success': True,
                'eligibility': response_data,
                'is_still_valid': is_still_valid
            }, status=status.HTTP_200_OK)
        else:
            # No eligibility record - check profile for quiz completion
            from account.models import UserProfile
            health_quiz_completed = False
            health_quiz_completed_at = None

            try:
                user_profile = UserProfile.objects.get(user=request.user)
                health_quiz_completed = user_profile.health_quiz_completed
                health_quiz_completed_at = user_profile.health_quiz_completed_at.isoformat() if user_profile.health_quiz_completed_at else None
            except UserProfile.DoesNotExist:
                pass

            return Response({
                'success': True,
                'eligibility': {
                    'is_eligible': None,
                    'last_quiz_date': None,
                    'eligibility_valid_until': None,
                    'disqualification_reasons': [],
                    'health_quiz_completed': health_quiz_completed,
                    'health_quiz_completed_at': health_quiz_completed_at
                },
                'is_still_valid': False,
                'message': 'No eligibility record found. Please complete the health quiz.'
            }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error fetching eligibility status: {str(e)}", exc_info=True)
        return Response({
            'success': False,
            'message': 'Failed to fetch eligibility status'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def get_client_ip(request):
    """Get client IP address from request."""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip
