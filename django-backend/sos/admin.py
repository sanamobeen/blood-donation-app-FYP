from django.contrib import admin
from .models import SOSRequest


@admin.register(SOSRequest)
class SOSRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'requester', 'patient_name', 'blood_type', 'units_needed', 'hospital_name', 'status', 'created_at')
    list_filter = ('status', 'blood_type', 'created_at')
    search_fields = ('requester__email', 'patient_name', 'hospital_name', 'hospital_address')
    readonly_fields = ('id', 'created_at', 'updated_at', 'responders_count', 'resolved_at')
    ordering = ('-created_at',)

    fieldsets = (
        ('Basic Information', {
            'fields': ('requester', 'patient_name', 'age', 'gender', 'blood_type', 'units_needed')
        }),
        ('Hospital Details', {
            'fields': ('hospital_name', 'hospital_address', 'hospital_lat', 'hospital_lng')
        }),
        ('Contact', {
            'fields': ('contact_phone', 'situation_description')
        }),
        ('Status & Response', {
            'fields': ('status', 'is_active', 'responders_count')
        }),
        ('Timestamps', {
            'fields': ('id', 'created_at', 'updated_at', 'resolved_at'),
            'classes': ('collapse',)
        }),
    )
