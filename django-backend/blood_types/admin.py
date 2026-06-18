from django.contrib import admin
from .models import BloodType


@admin.register(BloodType)
class BloodTypeAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'is_active', 'sort_order')
    list_filter = ('is_active', 'code')
    search_fields = ('code', 'name')
    list_editable = ('is_active', 'sort_order')
    ordering = ('sort_order', 'code')
