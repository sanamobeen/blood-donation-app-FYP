"""
Models for Blood Types app.
"""
from django.db import models


class BloodType(models.Model):
    """
    Blood Type model representing different blood groups and their compatibility.
    """
    BLOOD_GROUP_CHOICES = [
        ('A+', 'A Positive'),
        ('A-', 'A Negative'),
        ('B+', 'B Positive'),
        ('B-', 'B Negative'),
        ('AB+', 'AB Positive'),
        ('AB-', 'AB Negative'),
        ('O+', 'O Positive'),
        ('O-', 'O Negative'),
    ]

    code = models.CharField(
        max_length=5,
        choices=BLOOD_GROUP_CHOICES,
        unique=True,
        help_text="Blood group code (e.g., O+, A-)"
    )
    name = models.CharField(
        max_length=20,
        help_text="Full name of blood group (e.g., O Positive)"
    )
    compatibility = models.JSONField(
        default=list,
        help_text="List of compatible blood types for donation"
    )
    sort_order = models.IntegerField(
        default=0,
        help_text="Order for displaying blood types"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this blood type is active"
    )

    class Meta:
        verbose_name = "Blood Type"
        verbose_name_plural = "Blood Types"
        ordering = ['sort_order', 'code']
        indexes = [
            models.Index(fields=['code']),
            models.Index(fields=['is_active']),
        ]

    def __str__(self):
        return f"{self.code} - {self.name}"

    def save(self, *args, **kwargs):
        # Auto-generate name from code if not provided
        if not self.name:
            self.name = self.get_code_display()
        super().save(*args, **kwargs)
