from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import CustomUser, UserProfile, PasswordReset


@admin.register(CustomUser)
class CustomUserAdmin(BaseUserAdmin):
    list_display = ('email', 'full_name', 'phone_num', 'is_active', 'is_staff', 'date_joined')
    list_filter = ('is_active', 'is_staff', 'is_superuser', 'date_joined')
    search_fields = ('email', 'full_name', 'phone_num')
    ordering = ('-date_joined',)

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'phone_num', 'phone_verified')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_joined')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'full_name', 'password1', 'password2'),
        }),
    )


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'blood_group', 'city', 'has_location', 'gender', 'weight')
    list_filter = ('blood_group', 'city', 'gender')
    search_fields = ('user__email', 'user__full_name', 'city')

    fieldsets = (
        ('Basic Information', {
            'fields': ('user', 'blood_group', 'date_of_birth', 'gender', 'weight')
        }),
        ('Location Information', {
            'fields': ('city', 'location_lat', 'location_lng')
        }),
    )

    def has_location(self, obj):
        """Show if profile has coordinates"""
        return bool(obj.location_lat and obj.location_lng)
    has_location.short_description = 'Has GPS'
    has_location.boolean = True


@admin.register(PasswordReset)
class PasswordResetAdmin(admin.ModelAdmin):
    list_display = ('user', 'created_at', 'is_used')
    list_filter = ('is_used', 'created_at')
    search_fields = ('user__email', 'user__username')
