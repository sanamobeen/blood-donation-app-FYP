from django.contrib import admin
from django.utils.html import format_html
from .models import BloodRequest, DonorResponse


@admin.register(BloodRequest)
class BloodRequestAdmin(admin.ModelAdmin):
    list_display = ('share_id_link', 'patient_name', 'blood_group', 'units_needed', 'urgency_level', 'status', 'has_location', 'created_at')
    list_filter = ('status', 'urgency_level', 'blood_group', 'created_at')
    search_fields = ('patient_name', 'hospital_name', 'location', 'share_id')
    readonly_fields = ('share_id', 'public_page_link', 'created_at', 'updated_at', 'responders_count', 'units_pledged', 'units_received')
    ordering = ('-created_at',)

    fieldsets = (
        ('Basic Information', {
            'fields': ('share_id', 'public_page_link', 'patient_name', 'blood_group', 'units_needed', 'units_pledged', 'units_received')
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

    def share_id_link(self, obj):
        """Display share_id as a link to public page"""
        if obj.share_id:
            from django.conf import settings
            # Use localhost in development, configure domain in production
            base_url = getattr(settings, 'PUBLIC_BASE_URL', 'http://localhost:8000')
            url = f'{base_url}/request/{obj.share_id}/'
            return format_html('<a href="{}" target="_blank">{}</a>', url, obj.share_id)
        return '-'
    share_id_link.short_description = 'Share ID'
    share_id_link.admin_order_field = 'share_id'

    def public_page_link(self, obj):
        """Display clickable link to public page"""
        if obj.share_id:
            from django.conf import settings
            base_url = getattr(settings, 'PUBLIC_BASE_URL', 'http://localhost:8000')
            url = f'{base_url}/request/{obj.share_id}/'
            return format_html(
                '<a href="{}" target="_blank" style="padding: 8px 16px; background: #e63946; color: white; text-decoration: none; border-radius: 4px;">🔗 View Public Page</a>',
                url
            )
        return format_html('<span style="color: #999;">No share ID generated yet</span>')
    public_page_link.short_description = 'Public Link'


@admin.register(DonorResponse)
class DonorResponseAdmin(admin.ModelAdmin):
    list_display = ('id', 'blood_request', 'donor', 'units_pledged', 'status', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('donor__email', 'blood_request__patient_name')
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('-created_at',)
