"""
Serializers for health eligibility quiz system.
"""
from rest_framework import serializers
from .models import HealthQuizQuestion, HealthQuizResponse, EligibilityRecord


class HealthQuizQuestionSerializer(serializers.ModelSerializer):
    """Serializer for quiz questions."""

    class Meta:
        model = HealthQuizQuestion
        fields = ['id', 'question_text', 'question_type', 'options', 'order']
        read_only_fields = ['id']


class HealthQuizResponseSerializer(serializers.ModelSerializer):
    """Serializer for submitting quiz responses."""

    class Meta:
        model = HealthQuizResponse
        fields = ['responses']

    def validate_responses(self, value):
        """Validate that responses is a non-empty dictionary."""
        if not isinstance(value, dict):
            raise serializers.ValidationError("Responses must be a dictionary.")
        if not value:
            raise serializers.ValidationError("At least one response is required.")
        return value


class QuizResultSerializer(serializers.Serializer):
    """Serializer for quiz eligibility result."""

    is_eligible = serializers.BooleanField()
    message = serializers.CharField()
    disqualification_reasons = serializers.ListField(
        child=serializers.CharField(),
        allow_empty=True
    )
    can_proceed = serializers.BooleanField()


class EligibilityRecordSerializer(serializers.ModelSerializer):
    """Serializer for user's eligibility record."""

    last_quiz_date = serializers.DateTimeField(format='%Y-%m-%d %H:%M:%S')
    eligibility_valid_until = serializers.DateField(format='%Y-%m-%d', allow_null=True)

    class Meta:
        model = EligibilityRecord
        fields = [
            'is_eligible',
            'last_quiz_date',
            'eligibility_valid_until',
            'disqualification_reasons'
        ]
