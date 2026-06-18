"""
Celery Configuration for Blood Donation Backend.

This file configures Celery for background tasks and scheduled jobs.
"""
import os
from celery import Celery

# Set the default Django settings module for the 'celery' program.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')

app = Celery('blood_donation')

# Load configuration from Django settings
app.config_from_object('django.conf:settings', namespace='CELERY')

# Auto-discover tasks in all installed apps
app.autodiscover_tasks()


@app.task(bind=True)
def debug_task(self):
    """
    Debug task to verify Celery is working.
    Call with: celery -A backend call backend.celery.debug_task
    """
    print(f'Request: {self.request!r}')


@app.task(bind=True)
def test_task(self):
    """
    Test task for development.
    """
    print(f'Test task executed at: {self.request!r}')
    return 'Task completed successfully'
