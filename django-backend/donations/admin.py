from django.contrib import admin
from .models import Donation


@admin.register(Donation)
class DonationAdmin(admin.ModelAdmin):
    list_display = ('id', 'donor', 'blood_type', 'units', 'donation_date', 'donation_center', 'acknowledged_by_patient')
    list_filter = ('acknowledged_by_patient', 'donation_date', 'blood_type')
    search_fields = ('donor__username', 'donor__email', 'donation_center')
    readonly_fields = ('id', 'created_at', 'updated_at')
    ordering = ('-donation_date',)

    fieldsets = (
        ('Basic Information', {
            'fields': ('donor', 'blood_type', 'units', 'donation_date')
        }),
        ('Location', {
            'fields': ('donation_center', 'donation_center_address', 'blood_request')
        }),
        ('Health Data', {
            'fields': ('hemoglobin_level', 'blood_pressure', 'health_status', 'notes')
        }),
        ('Acknowledgment', {
            'fields': ('acknowledged_by_patient', 'acknowledged_at')
        }),
        ('System', {
            'fields': ('id', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
