# Generated migration for SOS response status fields

from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ('sos', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='sosresponse',
            name='status',
            field=models.CharField(
                max_length=20,
                choices=[('pending', 'Pending'), ('accepted', 'Accepted by Patient'),
                         ('rejected', 'Rejected by Patient'), ('donated', 'Donated - Completed'),
                         ('no_show', 'No Show')],
                default='pending',
                help_text='Status of the donor response'
            ),
        ),
        migrations.AddField(
            model_name='sosresponse',
            name='accepted_at',
            field=models.DateTimeField(
                null=True,
                blank=True,
                help_text='When patient accepted this donor'
            ),
        ),
        migrations.AddField(
            model_name='sosresponse',
            name='donated_at',
            field=models.DateTimeField(
                null=True,
                blank=True,
                help_text='When donor completed donation'
            ),
        ),
    ]
