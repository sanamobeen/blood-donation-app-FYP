"""
App configuration for health app.
"""
from django.apps import AppConfig


class HealthConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'health'
    verbose_name = 'Health Eligibility Quiz'

    def ready(self):
        """
        Import signal handlers when app is ready.
        """
        pass
