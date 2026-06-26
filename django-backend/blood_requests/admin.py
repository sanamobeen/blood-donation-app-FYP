from django.contrib import admin
from django.utils.html import format_html
from .models import BloodRequest, DonorResponse, PatientQuiz


@admin.register(BloodRequest)
class BloodRequestAdmin(admin.ModelAdmin):
    list_display = ('share_id_link', 'patient_name', 'blood_group', 'units_needed', 'urgency_level', 'status', 'has_location', 'created_at')
    list_filter = ('status', 'urgency_level', 'blood_group', 'created_at')
    search_fields = ('patient_name', 'hospital_name', 'location', 'share_id')
    readonly_fields = ('share_id', 'public_page_link', 'quiz_responses_display', 'created_at', 'updated_at', 'responders_count', 'units_pledged', 'units_received')
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
        ('Patient Quiz Responses', {
            'fields': ('quiz_responses_display',),
            'classes': ('collapse',),
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

    def quiz_responses_display(self, obj):
        """Display quiz responses in a readable format"""
        if not obj.quiz_responses:
            return format_html('<span style="color: #999;">No quiz responses</span>')

        responses = []
        for key, value in obj.quiz_responses.items():
            # Convert key to readable format
            label = key.replace('_', ' ').replace('-', ' ').title()
            responses.append(f'<div style="margin: 8px 0;"><strong>{label}:</strong> {value}</div>')

        return format_html('<div style="max-height: 300px; overflow-y: auto; background: #f9f9f9; padding: 12px; border-radius: 8px;">{}</div>'.format(''.join(responses)))
    quiz_responses_display.short_description = 'Quiz Responses'


@admin.register(DonorResponse)
class DonorResponseAdmin(admin.ModelAdmin):
    list_display = ('id', 'blood_request', 'donor', 'units_pledged', 'status', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('donor__email', 'blood_request__patient_name')
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('-created_at',)


@admin.register(PatientQuiz)
class PatientQuizAdmin(admin.ModelAdmin):
    """Admin interface for Patient Quiz model"""
    list_display = ('blood_request_link', 'risk_factors_summary', 'created_at')
    list_filter = ('had_blood_transfusion', 'had_tattoo_piercing', 'had_surgery', 'on_medication', 'has_chronic_disease', 'traveled_malaria_area', 'created_at')
    search_fields = ('blood_request__patient_name', 'other_medical_info')
    readonly_fields = ('created_at', 'updated_at', 'risk_summary_display')
    ordering = ('-created_at',)

    fieldsets = (
        ('Blood Request', {
            'fields': ('blood_request',)
        }),
        ('Quiz Responses', {
            'fields': (
                'had_blood_transfusion',
                'had_tattoo_piercing',
                'had_surgery',
                'on_medication',
                'has_chronic_disease',
                'traveled_malaria_area',
            )
        }),
        ('Additional Information', {
            'fields': ('other_medical_info', 'risk_summary_display')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at')
        }),
    )

    def blood_request_link(self, obj):
        """Display link to associated blood request"""
        url = f'/admin/blood_requests/bloodrequest/{obj.blood_request.id}/change/'
        return format_html('<a href="{}">{}</a>', url, obj.blood_request.patient_name)
    blood_request_link.short_description = 'Patient Name'
    blood_request_link.admin_order_field = 'blood_request__patient_name'

    def risk_factors_summary(self, obj):
        """Show summary of positive risk factors"""
        summary = obj.get_quiz_summary()
        if "No risk factors" in summary:
            return format_html('<span style="color: #4CAF50;">✓ No risk factors</span>')

        # Show count of risk factors
        count = len(summary)
        return format_html('<span style="color: #FF5722;">⚠ {} risk factor(s)</span>', count)
    risk_factors_summary.short_description = 'Risk Factors'

    def risk_summary_display(self, obj):
        """Display detailed risk summary"""
        summary = obj.get_quiz_summary()
        if "No risk factors" in summary:
            return format_html('<div style="padding: 12px; background: #E8F5E9; border-radius: 8px; color: #2E7D32;">✓ No significant risk factors identified</div>')

        items = []
        for risk in summary:
            items.append(f'<div style="padding: 8px; margin: 4px 0; background: #FFEBEE; border-radius: 6px; color: #C62828;">⚠ {risk}</div>')

        if obj.other_medical_info:
            items.append(f'<div style="padding: 8px; margin: 8px 0 0 0; background: #FFF3E0; border-radius: 6px; color: #EF6C00;">📝 Additional: {obj.other_medical_info}</div>')

        return format_html('<div style="margin-top: 8px;">{}</div>'.format(''.join(items)))
    risk_summary_display.short_description = 'Risk Summary'
