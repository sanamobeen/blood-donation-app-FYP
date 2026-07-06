"""
Celery tasks for SOS (Emergency) maintenance.

These tasks run automatically via Celery Beat to manage SOS requests
and responses that may need attention or automated cleanup.
"""
from celery import shared_task
from django.utils import timezone
from django.core.cache import cache
from .models import SOSRequest, SOSResponse
from account.models import CustomUser
import logging

logger = logging.getLogger(__name__)


@shared_task
def expire_old_sos_requests(hours: int = 4):
    """
    Scheduled task to expire SOS requests with no responses.

    This task runs every hour to check for SOS requests that have
    been active for more than the specified hours without any responses.

    Args:
        hours: Number of hours after which to expire (default: 4)

    Returns:
        int: Number of SOS requests expired
    """
    cutoff = timezone.now() - timezone.timedelta(hours=hours)

    # Find active SOS requests with no responses
    expired_requests = SOSRequest.objects.filter(
        status='active',
        created_at__lt=cutoff,
        responses__isnull=True
    )

    count = expired_requests.count()

    if count > 0:
        # Update their status to expired
        expired_requests.update(status='expired')
        logger.info(f"Expired {count} SOS requests with no responses")

        # Optionally notify the requesters
        for sos_request in expired_requests:
            try:
                from notifications.services.fcm_service import send_push_notification
                # Get requester's device tokens
                from notifications.models import DeviceToken
                tokens = list(
                    DeviceToken.objects.filter(
                        user=sos_request.requester,
                        is_active=True
                    ).values_list('token', flat=True)
                )

                if tokens:
                    send_push_notification_to_multiple(
                        tokens=tokens,
                        title="SOS Request Expired",
                        body=f"Your SOS request for {sos_request.blood_type} blood has expired with no responses.",
                        data={
                            'type': 'sos_expired',
                            'sos_id': str(sos_request.id),
                        }
                    )
            except Exception as e:
                logger.warning(f"Failed to notify user about expired SOS: {str(e)}")

    return count


@shared_task
def check_long_running_sos_requests(hours: int = 8):
    """
    Scheduled task to check for SOS requests running longer than expected.

    This task runs every hour to check for SOS requests that have been
    active for more than the specified hours. These may need follow-up.

    Args:
        hours: Number of hours to check (default: 8)

    Returns:
        dict: Statistics about long-running requests
    """
    cutoff = timezone.now() - timezone.timedelta(hours=hours)

    # Find active SOS requests older than cutoff
    long_running = SOSRequest.objects.filter(
        status='active',
        created_at__lt=cutoff
    )

    stats = {
        'total_long_running': long_running.count(),
        'with_responses': 0,
        'without_responses': 0,
    }

    for sos_request in long_running:
        response_count = sos_request.responses.count()
        if response_count > 0:
            stats['with_responses'] += 1
        else:
            stats['without_responses'] += 1

    if stats['total_long_running'] > 0:
        logger.info(f"Found {stats['total_long_running']} SOS requests running longer than {hours} hours")

    return stats


@shared_task
def mark_no_show_donors(minutes: int = 60):
    """
    Scheduled task to mark accepted donors as no-show if they haven't confirmed arrival.

    This task runs every 30 minutes to check for donors who were accepted
    but haven't confirmed arrival within the specified minutes.

    Args:
        minutes: Minutes after acceptance to mark as no-show (default: 60)

    Returns:
        int: Number of responses marked as no-show
    """
    cutoff = timezone.now() - timezone.timedelta(minutes=minutes)

    # Find accepted responses where accepted_at is older than cutoff
    # and no arrival confirmation
    no_show_responses = SOSResponse.objects.filter(
        status='accepted',
        accepted_at__lt=cutoff,
        arrived_at__isnull=True
    )

    count = no_show_responses.count()

    if count > 0:
        # Update status to no_show
        no_show_responses.update(status='no_show')
        logger.info(f"Marked {count} donors as no-show")

        # Notify the requesters and responders
        for response in no_show_responses:
            try:
                # Notify patient
                from notifications.services.fcm_service import send_push_notification
                from notifications.models import DeviceToken, Notification

                sos_request = response.sos_request

                # Create in-app notification for patient
                Notification.objects.create(
                    user=sos_request.requester,
                    title="⚠️ Donor No-Show",
                    message=f"The donor you accepted has been marked as no-show. You may want to accept another responder.",
                    type='donor_no_show',
                    related_request_id=str(sos_request.id),
                    data={
                        'sos_id': str(sos_request.id),
                        'response_id': str(response.id),
                    }
                )

                # Get patient's device tokens
                patient_tokens = list(
                    DeviceToken.objects.filter(
                        user=sos_request.requester,
                        is_active=True
                    ).values_list('token', flat=True)
                )

                if patient_tokens:
                    send_push_notification_to_multiple(
                        tokens=patient_tokens,
                        title="⚠️ Donor No-Show",
                        body=f"The accepted donor hasn't confirmed arrival. You may want to accept another responder.",
                        data={
                            'type': 'donor_no_show',
                            'sos_id': str(sos_request.id),
                        }
                    )

                # Notify donor
                Notification.objects.create(
                    user=response.responder,
                    title="Response Marked as No-Show",
                    message=f"Your response to the SOS request at {sos_request.hospital_name} has been marked as no-show.",
                    type='marked_no_show',
                    related_request_id=str(sos_request.id),
                    data={
                        'sos_id': str(sos_request.id),
                    }
                )

            except Exception as e:
                logger.warning(f"Failed to send notifications about no-show: {str(e)}")

    return count


@shared_task
def send_sos_reminder_notifications(minutes: int = 30):
    """
    Scheduled task to send reminder notifications to responders who haven't updated ETA.

    This task runs every 15 minutes to remind donors to update their ETA
    if they're close to their estimated arrival time.

    Args:
        minutes: Minutes before ETA to send reminder (default: 30)

    Returns:
        int: Number of reminders sent
    """
    from notifications.models import DeviceToken, Notification

    reminders_sent = 0

    # Find accepted responses with ETA that's approaching
    # but donor hasn't confirmed arrival
    upcoming_arrivals = SOSResponse.objects.filter(
        status='accepted',
        arrived_at__isnull=True
    )

    for response in upcoming_arrivals:
        if not response.estimated_arrival_minutes:
            continue

        # Calculate expected arrival time
        # We use accepted_at as the baseline
        if not response.accepted_at:
            continue

        expected_arrival = response.accepted_at + timezone.timedelta(minutes=response.estimated_arrival_minutes)
        time_until_arrival = (expected_arrival - timezone.now()).total_seconds() / 60  # Convert to minutes

        # Send reminder if ETA is approaching (within minutes threshold)
        # and hasn't arrived yet
        if 0 < time_until_arrival <= minutes:
            try:
                from notifications.services.fcm_service import send_push_notification

                responder = response.responder
                sos_request = response.sos_request

                # Get responder's device tokens
                tokens = list(
                    DeviceToken.objects.filter(
                        user=responder,
                        is_active=True
                    ).values_list('token', flat=True)
                )

                if tokens:
                    send_push_notification_to_multiple(
                        tokens=tokens,
                        title="⏰ ETA Reminder",
                        body=f"Remember to update your ETA for the SOS request at {sos_request.hospital_name}. Confirm arrival when you reach!",
                        data={
                            'type': 'eta_reminder',
                            'sos_id': str(sos_request.id),
                            'response_id': str(response.id),
                        }
                    )

                    # Create in-app notification
                    Notification.objects.create(
                        user=responder,
                        title="⏰ ETA Reminder",
                        message=f"Don't forget to update your ETA for the SOS request at {sos_request.hospital_name}.",
                        type='eta_reminder',
                        related_request_id=str(sos_request.id),
                        data={
                            'sos_id': str(sos_request.id),
                            'response_id': str(response.id),
                        }
                    )

                    reminders_sent += 1
                    logger.info(f"Sent ETA reminder to {responder.email} for SOS {sos_request.id}")

            except Exception as e:
                logger.warning(f"Failed to send ETA reminder: {str(e)}")

    return reminders_sent


@shared_task
def notify_donors_past_eta(grace_period_minutes: int = 5):
    """
    Scheduled task to automatically notify donors when they pass their ETA.

    This task runs every 5 minutes to check for donors who have passed
    their estimated arrival time by the specified grace period and
    haven't confirmed arrival yet.

    Args:
        grace_period_minutes: Minutes after ETA to send notification (default: 5)

    Returns:
        int: Number of notifications sent
    """
    from notifications.models import DeviceToken, Notification

    notifications_sent = 0

    # Find accepted responses with ETA that has passed
    past_eta_responses = SOSResponse.objects.filter(
        status__in=['accepted', 'in_transit'],
        arrived_at__isnull=True,
        accepted_at__isnull=False,
        estimated_arrival_minutes__isnull=False
    )

    for response in past_eta_responses:
        try:
            # Calculate expected arrival time
            expected_arrival = response.accepted_at + timezone.timedelta(minutes=response.estimated_arrival_minutes)
            minutes_past = int((timezone.now() - expected_arrival).total_seconds() / 60)

            # Check if we're in the notification window
            # Send notification if: grace_period <= minutes_past <= grace_period + 5
            # This avoids sending the same notification multiple times
            if grace_period_minutes <= minutes_past <= (grace_period_minutes + 5):

                from notifications.services.fcm_service import notify_donor_past_eta_auto

                # Send notification
                success = notify_donor_past_eta_auto(response, minutes_past)

                if success:
                    notifications_sent += 1
                    logger.info(f"Sent past-ETA notification to {response.responder.email} ({minutes_past} min late)")

        except Exception as e:
            logger.warning(f"Failed to check/send past-ETA notification: {str(e)}")

    return notifications_sent


@shared_task
def mark_eta_based_no_show_donors(grace_period_minutes: int = 10):
    """
    Scheduled task to mark donors as no-show based on their ETA + grace period.

    This task runs every minute to check for donors who:
    1. Were accepted by patient
    2. Provided an ETA
    3. Haven't confirmed arrival
    4. ETA + grace period has passed

    Example: If donor says ETA = 5 minutes, and grace period = 10 minutes,
    they will be marked no-show after 15 total minutes from acceptance.

    Args:
        grace_period_minutes: Grace period after ETA to mark as no-show (default: 10)

    Returns:
        int: Number of responses marked as no-show
    """
    from notifications.models import DeviceToken, Notification

    no_show_count = 0

    # Find all accepted responses that haven't arrived yet
    pending_arrivals = SOSResponse.objects.filter(
        status='accepted',
        arrived_at__isnull=True,
        estimated_arrival_minutes__isnull=False,
        accepted_at__isnull=False
    )

    for response in pending_arrivals:
        # Calculate when the donor should have arrived (ETA + grace period)
        accepted_time = response.accepted_at
        eta_minutes = response.estimated_arrival_minutes

        # Expected arrival time = when donor was accepted + their ETA
        expected_arrival_time = accepted_time + timezone.timedelta(minutes=eta_minutes)

        # Deadline = expected arrival + grace period
        deadline_time = expected_arrival_time + timezone.timedelta(minutes=grace_period_minutes)

        # Check if current time is past the deadline
        if timezone.now() > deadline_time:
            sos_request = response.sos_request

            # Mark as no-show
            response.status = 'no_show'
            response.save()

            no_show_count += 1
            logger.info(
                f"Marked donor {response.responder.email} as no-show. "
                f"ETA was {eta_minutes}min, grace period {grace_period_minutes}min exceeded"
            )

            try:
                # Notify patient
                Notification.objects.create(
                    user=sos_request.requester,
                    title="⚠️ Donor No-Show",
                    message=f"The donor you accepted has been marked as no-show (ETA + {grace_period_minutes}min exceeded). You may want to accept another responder.",
                    type='donor_no_show',
                    related_request_id=str(sos_request.id),
                    data={
                        'sos_id': str(sos_request.id),
                        'response_id': str(response.id),
                    }
                )

                # Get patient's device tokens for push notification
                patient_tokens = list(
                    DeviceToken.objects.filter(
                        user=sos_request.requester,
                        is_active=True
                    ).values_list('token', flat=True)
                )

                if patient_tokens:
                    send_push_notification_to_multiple(
                        tokens=patient_tokens,
                        title="⚠️ Donor No-Show",
                        body=f"The accepted donor hasn't confirmed arrival. ETA + {grace_period_minutes}min exceeded. You may want to accept another responder.",
                        data={
                            'type': 'donor_no_show',
                            'sos_id': str(sos_request.id),
                            'response_id': str(response.id),
                        }
                    )

                # Notify donor that they were marked as no-show
                Notification.objects.create(
                    user=response.responder,
                    title="Response Marked as No-Show",
                    message=f"Your response to SOS at {sos_request.hospital_name} was marked as no-show. You didn't confirm arrival within ETA + {grace_period_minutes} minutes.",
                    type='marked_no_show',
                    related_request_id=str(sos_request.id),
                    data={
                        'sos_id': str(sos_request.id),
                        'eta_minutes': eta_minutes,
                        'grace_period': grace_period_minutes,
                    }
                )

                # Try to send push to donor too
                donor_tokens = list(
                    DeviceToken.objects.filter(
                        user=response.responder,
                        is_active=True
                    ).values_list('token', flat=True)
                )

                if donor_tokens:
                    send_push_notification_to_multiple(
                        tokens=donor_tokens,
                        title="⚠️ Marked as No-Show",
                        body=f"Your response was marked as no-show. Please confirm arrival promptly in the future.",
                        data={
                            'type': 'marked_no_show',
                            'sos_id': str(sos_request.id),
                        }
                    )

            except Exception as e:
                logger.warning(f"Failed to send notifications for no-show: {str(e)}")

    if no_show_count > 0:
        logger.info(f"ETA-based no-show check: Marked {no_show_count} donors as no-show")

    return no_show_count


# Helper function for multicast notifications
def send_push_notification_to_multiple(tokens, title, body, data):
    """Helper function to send to multiple tokens."""
    from notifications.services.fcm_service import send_push_notification

    for token in tokens:
        try:
            send_push_notification(token, title, body, data)
        except Exception as e:
            logger.warning(f"Failed to send notification to token: {str(e)}")
