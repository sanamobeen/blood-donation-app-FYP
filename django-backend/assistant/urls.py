"""
URL configuration for Assistant app.
"""
from django.urls import path
from . import views

app_name = 'assistant'

urlpatterns = [
    # Chat endpoints
    path('chat/', views.chat, name='chat'),
    path('health/', views.health_check, name='health_check'),

    # FAQ endpoints
    path('faqs/', views.faq_list, name='faq_list'),

    # History and feedback
    path('history/', views.chat_history, name='chat_history'),
    path('feedback/', views.submit_feedback, name='submit_feedback'),

    # Admin endpoints
    path('reload/', views.reload_chatbot_cache, name='reload_chatbot'),
]
