# Generated migration for ineligibility period tracking

from django.db import migrations, models
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('health', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='eligibilityrecord',
            name='last_failed_quiz_date',
            field=models.DateTimeField(
                blank=True,
                help_text='Timestamp of the last failed quiz attempt',
                null=True
            ),
        ),
        migrations.AddField(
            model_name='eligibilityrecord',
            name='ineligible_until',
            field=models.DateTimeField(
                blank=True,
                help_text='User cannot donate/pledge until this datetime (30-day penalty after failed quiz)',
                null=True
            ),
        ),
    ]
