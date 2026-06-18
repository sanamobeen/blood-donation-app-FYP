"""
Django signal handlers for SOS events that trigger push notifications.

These handlers listen for SOS model changes and automatically send
push notifications to relevant users.
"""
import logging
from django.db.models.signals import post_save, post_save
from django.dispatch import receiver
from django.db.models import F

from sos.models import SOSRequest, SOSResponse
from .services.fcm_service import (
    notify_nearby_users_sos_created,
    notify_sos_creator_new_response,
    notify_sos_responders_status_change,
)


logger = logging.getLogger(__name__)


@receiver(post_save, sender=SOSRequest)
def on_sos_request_created(sender, instance, created, **kwargs):
    """
    Handle SOS request creation - notify nearby donors.

    Triggered when a new SOSRequest is created.
    """
    if not created:
        return

    try:
        logger.info(f"SOS request created: {instance.id}, triggering notifications...")

        # Notify nearby users within 50km radius
        # You can make this configurable via settings
        notified_count = notify_nearby_users_sos_created(
            sos_request=instance,
            radius_km=getattr(instance, 'notification_radius_km', 50)
        )

        logger.info(f"Notified {notified_count} nearby users about SOS {instance.id}")

    except Exception as e:
        logger.error(f"Error handling SOS creation signal: {str(e)}", exc_info=True)


@receiver(post_save, sender=SOSResponse)
def on_sos_response_created(sender, instance, created, **kwargs):
    """
    Handle SOS response creation - notify the SOS creator.

    Triggered when a donor responds to an SOS request.
    """
    if not created:
        return

    try:
        logger.info(f"SOS response created: {instance.id}, notifying creator...")

        # Update the responders count on the SOS request
        instance.sos_request.responders_count = F('responders_count') + 1
        instance.sos_request.save(update_fields=['responders_count'])

        # Notify the SOS creator
        responder_name = instance.responder.full_name or instance.resonder.email.split('@')[0]

        notify_sos_creator_new_response(
            sos_request=instance.sos_request,
            responder_name=responder_name
        )

        logger.info(f"Notified SOS creator about response from {responder_name}")

    except Exception as e:
        logger.error(f"Error handling SOS response signal: {str(e)}", exc_info=True)


def on_sos_status_changed(sender, instance, **kwargs):
    """
    Handle SOS status changes - notify all responders.

    This should be called manually when SOS status is updated.
    We use a custom signal approach or call this directly in views.
    """
    # Track old status to detect changes
    try:
        old_instance = sender.objects.get(pk=instance.pk)
        old_status = old_instance.status
    except sender.DoesNotExist:
        old_status = None

    # Only notify if status changed to resolved or cancelled
    if old_status and old_status != instance.status:
        if instance.status in ['resolved', 'cancelled']:
            try:
                logger.info(f"SOS {instance.id} status changed to {instance.status}, notifying responders...")

                notify_sos_responders_status_change(
                    sos_request=instance,
                    new_status=instance.status
                )

                logger.info(f"Notified responders about SOS {instance.id} being {instance.status}")

            except Exception as e:
                logger.error(f"Error handling SOS status change: {str(e)}", exc_info=True)
