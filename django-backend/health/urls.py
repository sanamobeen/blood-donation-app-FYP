"""
URL configuration for health app.
"""
from django.urls import path
from .views import get_quiz_questions, submit_quiz_responses, get_eligibility_status, health_check

app_name = 'health'

urlpatterns = [
    path('', health_check, name='health_check'),
    path('quiz/', get_quiz_questions, name='get_quiz_questions'),
    path('quiz/submit/', submit_quiz_responses, name='submit_quiz_responses'),
    path('eligibility/', get_eligibility_status, name='get_eligibility_status'),
]
