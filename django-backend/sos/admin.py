from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from .models import SOSRequest, SOSResponse


@admin.register(SOSRequest)
class SOSRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'requester', 'patient_name', 'blood_type', 'units_needed',
                   'hospital_name', 'status', 'responses_count', 'created_at', 'time_elapsed')
    list_filter = ('status', 'blood_type', 'created_at')
    search_fields = ('requester__email', 'patient_name', 'hospital_name', 'hospital_address')
    readonly_fields = ('id', 'created_at', 'updated_at', 'resolved_at')
    ordering = ('-created_at',)

    fieldsets = (
        ('Basic Information', {
            'fields': ('requester', 'patient_name', 'age', 'gender', 'blood_type', 'units_needed')
        }),
        ('Hospital Details', {
            'fields': ('hospital_name', 'hospital_address', 'hospital_lat', 'hospital_lng')
        }),
        ('Contact', {
            'fields': ('contact_phone',)
        }),
        ('Status & Response', {
            'fields': ('status', 'resolution_note')
        }),
        ('Timestamps', {
            'fields': ('id', 'created_at', 'updated_at', 'resolved_at'),
            'classes': ('collapse',)
        }),
    )

    def responses_count(self, obj):
        """Display the number of responses"""
        count = obj.responses.count()
        color = 'green' if count > 0 else 'red'
        return format_html(
            '<span style="color: {};">{}</span>',
            color, count
        )
    responses_count.short_description = 'Responses'

    def time_elapsed(self, obj):
        """Display time elapsed since creation"""
        if not obj.created_at:
            return '-'

        elapsed = timezone.now() - obj.created_at
        hours = int(elapsed.total_seconds() // 3600)
        minutes = int((elapsed.total_seconds() % 3600) // 60)

        if hours > 24:
            days = hours // 24
            return f'{days}d {hours % 24}h'
        elif hours > 0:
            return f'{hours}h {minutes}m'
        else:
            return f'{minutes}m'
    time_elapsed.short_description = 'Elapsed'

    def accepted_response(self, obj):
        """Show which response was accepted"""
        accepted = obj.responses.filter(status__in=['accepted', 'donated', 'arrived', 'donating']).first()
        if accepted:
            donor_name = accepted.responder.get_full_name() or accepted.responder.email
            return format_html(
                '<span style="color: green;">✓ {}</span>',
                donor_name
            )
        return '-'
    accepted_response.short_description = 'Accepted Donor'


@admin.register(SOSResponse)
class SOSResponseAdmin(admin.ModelAdmin):
    list_display = ('id', 'sos_request_link', 'responder', 'status_badge', 'eta_display',
                   'accepted_at', 'arrived_at', 'donated_at', 'created_at')
    list_filter = ('status', 'created_at', 'accepted_at', 'arrived_at')
    search_fields = ('responder__email', 'sos_request__patient_name', 'sos_request__hospital_name',
                     'note')
    readonly_fields = ('id', 'created_at', 'accepted_at', 'departed_at', 'arrived_at',
                      'donated_at', 'cancelled_at')
    ordering = ('-created_at',)

    fieldsets = (
        ('SOS & Donor', {
            'fields': ('sos_request', 'responder', 'can_help')
        }),
        ('ETA & Note', {
            'fields': ('estimated_arrival_minutes', 'note')
        }),
        ('Status Tracking', {
            'fields': ('status', 'accepted_at', 'departed_at',
                      'arrived_at', 'donated_at', 'cancelled_at')
        }),
        ('Metadata', {
            'fields': ('id', 'created_at'),
            'classes': ('collapse',)
        }),
    )

    def sos_request_link(self, obj):
        """Link to the SOS request in admin"""
        url = f'/admin/sos/sosrequest/{obj.sos_request.id}/change/'
        return format_html('<a href="{}">{} - {}</a>',
                          url, obj.sos_request.blood_type, obj.sos_request.patient_name)
    sos_request_link.short_description = 'SOS Request'

    def status_badge(self, obj):
        """Display status with color coding"""
        colors = {
            'pending': 'orange',
            'accepted': 'blue',
            'rejected': 'red',
            'in_transit': 'purple',
            'arrived': 'green',
            'donating': 'darkgreen',
            'donated': 'darkgreen',
            'no_show': 'red',
            'cancelled': 'gray',
        }
        color = colors.get(obj.status, 'black')

        labels = {
            'pending': '⏳ Pending',
            'accepted': '✓ Accepted',
            'rejected': '✗ Rejected',
            'in_transit': '🚗 In Transit',
            'arrived': '🏥 Arrived',
            'donating': '🩸 Donating',
            'donated': '✅ Donated',
            'no_show': '❌ No-Show',
            'cancelled': '🚫 Cancelled',
        }
        label = labels.get(obj.status, obj.status)

        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            color, label
        )
    status_badge.short_description = 'Status'

    def eta_display(self, obj):
        """Display ETA with visual indicator"""
        if not obj.estimated_arrival_minutes:
            return '-'

        eta = obj.estimated_arrival_minutes
        if eta <= 10:
            color = 'green'
        elif eta <= 20:
            color = 'orange'
        else:
            color = 'red'

        return format_html(
            '<span style="color: {}; font-weight: bold;">{} min</span>',
            color, eta
        )
    eta_display.short_description = 'ETA'

    def time_to_arrive(self, obj):
        """Calculate if donor is late or on time"""
        if not obj.accepted_at or not obj.estimated_arrival_minutes:
            return '-'

        expected = obj.accepted_at + timezone.timedelta(minutes=obj.estimated_arrival_minutes)
        now = timezone.now()

        if obj.arrived_at:
            actual = obj.arrived_at
            diff = (actual - obj.accepted_at).total_seconds() / 60
            if diff <= obj.estimated_arrival_minutes:
                return format_html('<span style="color: green;">✓ On time ({} min)</span>', int(diff))
            else:
                late_by = int(diff - obj.estimated_arrival_minutes)
                return format_html('<span style="color: orange;">⚠ Late by {} min</span>', late_by)
        elif now > expected:
            late_by = int((now - expected).total_seconds() / 60)
            return format_html('<span style="color: red;">❌ {} min overdue</span>', late_by)
        else:
            remaining = int((expected - now).total_seconds() / 60)
            return format_html('<span style="color: green;">{} min remaining</span>', remaining)
    time_to_arrive.short_description = 'Time Status'
