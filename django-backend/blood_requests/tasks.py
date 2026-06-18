"""
Celery tasks for Blood Request maintenance.

These tasks run automatically via Celery Beat to maintain
the health of the blood donation system.
"""
from celery import shared_task
from django.utils import timezone
from django.db.models import Q
from .models import BloodRequest
import logging

logger = logging.getLogger(__name__)


@shared_task
def expire_old_requests():
    """
    Scheduled task to expire old blood requests.

    This task runs every 5 minutes (configured in settings.py)
    to automatically mark requests as expired if they've passed
    their expiration time.

    Process:
    1. Find all active pending requests with expires_at <= now
    2. Update their status to 'expired' and is_active to False
    3. Notify requesters that their requests have expired

    Returns:
        int: Number of requests expired
    """
    now = timezone.now()
    expired_requests = BloodRequest.objects.filter(
        is_active=True,
        status='pending',
        expires_at__lte=now
    )

    count = expired_requests.count()
    if count > 0:
        # Update in bulk for performance
        expired_requests.update(
            status='expired',
            is_active=False
        )
        logger.info(f"Expired {count} blood requests at {now}")

        # Notify requesters about expiration
        for req in expired_requests:
            if req.requested_by:
                try:
                    from notifications.models import Notification
                    Notification.objects.create(
                        user=req.requested_by,
                        title='Blood Request Expired',
                        message=f'Your blood request for {req.blood_group} blood has expired. You can create a new request if still needed.',
                        type='request_expired',
                        related_request_id=str(req.id)
                    )
                    logger.info(f"Sent expiration notification to {req.requested_by.email}")
                except Exception as e:
                    logger.error(f"Failed to send expiration notification: {e}")

    return count


@shared_task
def cleanup_old_notifications():
    """
    Scheduled task to delete old notifications.

    This task runs daily to keep the database clean by removing
    notifications older than 30 days.

    Returns:
        int: Number of notifications deleted
    """
    from notifications.models import Notification

    cutoff = timezone.now() - timezone.timedelta(days=30)
    result = Notification.objects.filter(created_at__lt=cutoff).delete()

    deleted_count = result[0] if result else 0
    if deleted_count > 0:
        logger.info(f"Cleaned up {deleted_count} old notifications")

    return deleted_count


@shared_task
def send_expiry_reminders():
    """
    Send reminders for requests about to expire.

    This task runs every hour to notify requesters when their
    requests are about to expire (within 1 hour).

    Returns:
        int: Number of reminders sent
    """
    one_hour_from_now = timezone.now() + timezone.timedelta(hours=1)

    requests_expiring_soon = BloodRequest.objects.filter(
        is_active=True,
        status='pending',
        expires_at__lte=one_hour_from_now,
        expires_at__gt=timezone.now()
    )

    reminder_count = 0
    for req in requests_expiring_soon:
        if req.requested_by:
            try:
                from notifications.models import Notification
                Notification.objects.create(
                    user=req.requested_by,
                    title='Blood Request Expiring Soon',
                    message=f'Your blood request for {req.blood_group} blood will expire in less than an hour. Please extend or create a new request.',
                    type='request_expiring_soon',
                    related_request_id=str(req.id)
                )
                reminder_count += 1
            except Exception as e:
                logger.error(f"Failed to send expiry reminder: {e}")

    if reminder_count > 0:
        logger.info(f"Sent {reminder_count} expiry reminders")

    return reminder_count
