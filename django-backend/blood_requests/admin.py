from django.contrib import admin
from .models import BloodRequest, DonorResponse


@admin.register(BloodRequest)
class BloodRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'patient_name', 'blood_group', 'units_needed', 'urgency_level', 'status', 'has_location', 'created_at')
    list_filter = ('status', 'urgency_level', 'blood_group', 'created_at')
    search_fields = ('patient_name', 'hospital_name', 'location')
    readonly_fields = ('created_at', 'updated_at', 'responders_count', 'units_pledged', 'units_received')
    ordering = ('-created_at',)

    fieldsets = (
        ('Basic Information', {
            'fields': ('patient_name', 'blood_group', 'units_needed', 'units_pledged', 'units_received')
        }),
        ('Location Details', {
            'fields': ('hospital_name', 'location', 'location_lat', 'location_lng')
        }),
        ('Contact & Requester', {
            'fields': ('contact_number', 'requested_by')
        }),
        ('Status & Urgency', {
            'fields': ('status', 'urgency_level', 'is_active')
        }),
        ('Additional Info', {
            'fields': ('additional_notes', 'responders_count')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at')
        }),
    )

    def has_location(self, obj):
        """Show if request has coordinates"""
        return bool(obj.location_lat and obj.location_lng)
    has_location.short_description = 'Has GPS'
    has_location.boolean = True


@admin.register(DonorResponse)
class DonorResponseAdmin(admin.ModelAdmin):
    list_display = ('id', 'blood_request', 'donor', 'units_pledged', 'status', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('donor__email', 'blood_request__patient_name')
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('-created_at',)
