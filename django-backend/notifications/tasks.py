"""
Celery tasks for Notifications maintenance.

These tasks run automatically via Celery Beat to maintain
the health of the notification system.
"""
from celery import shared_task
from django.utils import timezone
from .models import Notification
import logging

logger = logging.getLogger(__name__)


@shared_task
def cleanup_old_notifications():
    """
    Scheduled task to delete old notifications.

    This task runs daily to keep the database clean by removing
    notifications older than 30 days.

    Returns:
        int: Number of notifications deleted
    """
    cutoff = timezone.now() - timezone.timedelta(days=30)
    result = Notification.objects.filter(created_at__lt=cutoff).delete()

    deleted_count = result[0] if result else 0
    if deleted_count > 0:
        logger.info(f"Cleaned up {deleted_count} old notifications")

    return deleted_count
