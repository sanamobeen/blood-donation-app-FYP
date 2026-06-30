# Generated migration

from django.db import migrations, models
from django.utils import timezone
from datetime import timedelta


def forward(apps, schema_editor):
    """Set default value for existing NULL needed_by fields"""
    BloodRequest = apps.get_model('blood_requests', 'BloodRequest')
    for request in BloodRequest.objects.filter(needed_by__isnull=True):
        # Set default to 24 hours from created_at or now
        if request.created_at:
            request.needed_by = request.created_at + timedelta(hours=24)
        else:
            request.needed_by = timezone.now() + timedelta(hours=24)
        request.save(update_fields=['needed_by'])


class Migration(migrations.Migration):

    dependencies = [
        ('blood_requests', '0019_bloodrequest_needed_by'),
    ]

    operations = [
        # Run Python function to set defaults
        migrations.RunPython(forward, migrations.RunPython.noop),
        # Alter field to be non-nullable
        migrations.AlterField(
            model_name='bloodrequest',
            name='needed_by',
            field=models.DateTimeField(help_text='Date and time when blood is needed by'),
        ),
    ]
