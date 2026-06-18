from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'notifications'
    verbose_name = 'Push Notifications'

    def ready(self):
        """
        Initialize Firebase Admin SDK when the app is ready.
        This is called when Django starts up.
        """
        from .services.fcm_service import initialize_firebase
        initialize_firebase()
