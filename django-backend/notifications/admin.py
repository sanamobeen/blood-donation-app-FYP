from django.contrib import admin
from django.utils.html import format_html
from .models import Notification, DeviceToken


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user_email', 'title_truncated', 'type_badge', 'is_read',
                   'related_sos_link', 'created_at', 'created_ago')
    list_filter = ('type', 'is_read', 'created_at')
    search_fields = ('user__email', 'title', 'message', 'type')
    readonly_fields = ('id', 'user', 'title', 'message', 'type', 'related_request_id',
                      'data', 'is_read', 'created_at')
    ordering = ('-created_at',)

    fieldsets = (
        ('Recipient', {
            'fields': ('user', 'is_read')
        }),
        ('Content', {
            'fields': ('title', 'message', 'type')
        }),
        ('Related Data', {
            'fields': ('related_request_id', 'data')
        }),
        ('Metadata', {
            'fields': ('id', 'created_at'),
            'classes': ('collapse',)
        }),
    )

    def user_email(self, obj):
        """Display user email"""
        return obj.user.email if obj.user else '-'
    user_email.short_description = 'User'

    def title_truncated(self, obj):
        """Display truncated title"""
        if len(obj.title) > 40:
            return obj.title[:40] + '...'
        return obj.title
    title_truncated.short_description = 'Title'

    def type_badge(self, obj):
        """Display notification type with color coding"""
        colors = {
            'sos_alert': 'red',
            'sos_response': 'blue',
            'sos_response_accepted': 'green',
            'sos_response_rejected': 'orange',
            'donation_confirmed': 'darkgreen',
            'donor_arrived': 'purple',
            'donor_running_late': 'orange',
            'eta_update': 'blue',
            'donor_no_show': 'red',
            'marked_no_show': 'red',
            'eta_reminder': 'gray',
            'sos_created': 'red',
            'sos_resolved': 'green',
            'sos_cancelled': 'gray',
            'sos_expired': 'gray',
        }
        color = colors.get(obj.type, 'black')

        # Create icon for common types
        icons = {
            'sos_alert': '🆘',
            'sos_response': '💬',
            'sos_response_accepted': '✅',
            'sos_response_rejected': '❌',
            'donation_confirmed': '🎉',
            'donor_arrived': '🏥',
            'donor_running_late': '⚠️',
            'eta_update': '📍',
            'donor_no_show': '🚫',
            'marked_no_show': '📝',
            'eta_reminder': '⏰',
        }
        icon = icons.get(obj.type, '📌')

        return format_html(
            '<span style="color: {}; font-weight: bold;">{} {}</span>',
            color, icon, obj.type
        )
    type_badge.short_description = 'Type'

    def related_sos_link(self, obj):
        """Link to related SOS if exists"""
        if not obj.related_request_id:
            return '-'

        # Try to find the SOS request
        from sos.models import SOSRequest
        try:
            sos = SOSRequest.objects.get(id=obj.related_request_id)
            url = f'/admin/sos/sosrequest/{sos.id}/change/'
            return format_html('<a href="{}">{} - {}</a>',
                              url, sos.blood_type, sos.patient_name)
        except SOSRequest.DoesNotExist:
            return obj.related_request_id
    related_sos_link.short_description = 'Related SOS'

    def created_ago(self, obj):
        """Display time ago"""
        if not obj.created_at:
            return '-'

        from django.utils import timezone
        elapsed = timezone.now() - obj.created_at
        hours = int(elapsed.total_seconds() // 3600)
        minutes = int((elapsed.total_seconds() % 3600) // 60)

        if hours > 24:
            days = hours // 24
            return f'{days}d ago'
        elif hours > 0:
            return f'{hours}h ago'
        elif minutes > 0:
            return f'{minutes}m ago'
        else:
            return 'Just now'
    created_ago.short_description = 'Created'


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('id', 'user_email', 'token_truncated', 'is_active', 'device_info',
                   'last_used', 'created_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('user__email', 'token')
    readonly_fields = ('id', 'user', 'token', 'is_active', 'created_at')

    def user_email(self, obj):
        """Display user email"""
        return obj.user.email if obj.user else '-'
    user_email.short_description = 'User'

    def token_truncated(self, obj):
        """Display truncated token"""
        if obj.token and len(obj.token) > 20:
            return obj.token[:20] + '...'
        return obj.token or '-'
    token_truncated.short_description = 'Token'

    def device_info(self, obj):
        """Display device info from data"""
        if not obj.data:
            return '-'

        device_name = obj.data.get('device_name', '-')
        platform = obj.data.get('platform', '-')
        return f'{device_name} ({platform})'
    device_info.short_description = 'Device'

    def last_used(self, obj):
        """Display when token was last used"""
        if not obj.updated_at:
            return '-'

        from django.utils import timezone
        elapsed = timezone.now() - obj.updated_at
        hours = int(elapsed.total_seconds() // 3600)

        if hours > 24:
            return f'{hours // 24}d ago'
        elif hours > 0:
            return f'{hours}h ago'
        else:
            return 'Recently'
    last_used.short_description = 'Last Used'
