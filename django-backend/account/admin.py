from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import CustomUser, UserProfile, PasswordReset


@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    list_display = ('email', 'get_role_badge', 'full_name', 'phone_num', 'phone_verified', 'is_active', 'is_staff', 'date_joined')
    list_filter = ('role', 'is_active', 'is_staff', 'is_superuser', 'phone_verified', 'date_joined')
    search_fields = ('email', 'full_name', 'phone_num')
    ordering = ('-date_joined',)

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'phone_num', 'phone_verified', 'role')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_joined')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'full_name', 'password1', 'password2'),
        }),
    )

    def get_role_badge(self, obj):
        """Display role as colored badge"""
        if not obj.role:
            return '—'

        role_colors = {
            'donor': 'green',
            'patient': 'blue',
            'admin': 'red',
        }

        role_display = {
            'donor': '🩸 Donor',
            'patient': '🏥 Patient',
            'admin': '👨‍💼 Admin',
        }

        color = role_colors.get(obj.role, 'gray')
        display = role_display.get(obj.role, obj.role.capitalize())

        from django.utils.safestring import mark_safe
        return mark_safe(
            f'<span style="background-color: {color}; color: white; '
            f'padding: 4px 12px; border-radius: 12px; font-weight: bold;">'
            f'{display}</span>'
        )
    get_role_badge.short_description = 'Role'
    get_role_badge.admin_order_field = 'role'


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('get_user_email', 'get_role_badge', 'blood_group', 'city', 'has_location', 'has_health_quiz', 'gender', 'weight', 'is_available')
    list_filter = ('role', 'blood_group', 'city', 'gender', 'health_quiz_completed', 'is_available_for_donation')
    search_fields = ('user__email', 'user__full_name', 'city')

    fieldsets = (
        ('User Information', {
            'fields': ('user', 'role')
        }),
        ('Basic Information', {
            'fields': ('blood_group', 'date_of_birth', 'gender', 'weight')
        }),
        ('Location Information', {
            'fields': ('city', 'location_lat', 'location_lng')
        }),
        ('Health Quiz Status', {
            'fields': ('health_quiz_completed', 'health_quiz_completed_at')
        }),
        ('Donation Availability', {
            'fields': ('is_available_for_donation', 'last_donation_date')
        }),
    )

    def get_user_email(self, obj):
        """Get user email for display"""
        return obj.user.email
    get_user_email.short_description = 'User Email'
    get_user_email.admin_order_field = 'user__email'

    def get_role_badge(self, obj):
        """Display role as colored badge"""
        if not obj.role:
            return '—'

        role_colors = {
            'donor': 'green',
            'patient': 'blue',
            'admin': 'red',
        }

        role_display = {
            'donor': '🩸 Donor',
            'patient': '🏥 Patient',
            'admin': '👨‍💼 Admin',
        }

        color = role_colors.get(obj.role, 'gray')
        display = role_display.get(obj.role, obj.role.capitalize())

        from django.utils.safestring import mark_safe
        return mark_safe(
            f'<span style="background-color: {color}; color: white; '
            f'padding: 4px 12px; border-radius: 12px; font-weight: bold;">'
            f'{display}</span>'
        )
    get_role_badge.short_description = 'Role'
    get_role_badge.allow_tags = True

    def has_location(self, obj):
        """Show if profile has coordinates"""
        return bool(obj.location_lat and obj.location_lng)
    has_location.short_description = 'Has GPS'
    has_location.boolean = True

    def has_health_quiz(self, obj):
        """Show if health quiz is completed"""
        return obj.health_quiz_completed
    has_health_quiz.short_description = 'Health Quiz'
    has_health_quiz.boolean = True

    def is_available(self, obj):
        """Show if donor is available"""
        return obj.is_available_for_donation
    is_available.short_description = 'Available'
    is_available.boolean = True


@admin.register(PasswordReset)
class PasswordResetAdmin(admin.ModelAdmin):
    list_display = ('user', 'created_at', 'is_used')
    list_filter = ('is_used', 'created_at')
    search_fields = ('user__email', 'user__username')
