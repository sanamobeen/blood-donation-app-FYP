from django.contrib import admin
from .models import HealthQuizQuestion, HealthQuizResponse, EligibilityRecord


@admin.register(HealthQuizQuestion)
class HealthQuizQuestionAdmin(admin.ModelAdmin):
    list_display = ('question_text', 'question_type', 'order', 'is_active')
    list_filter = ('question_type', 'is_active')
    search_fields = ('question_text',)
    list_editable = ('order', 'is_active')
    ordering = ('order',)


@admin.register(HealthQuizResponse)
class HealthQuizResponseAdmin(admin.ModelAdmin):
    list_display = ('user', 'is_eligible', 'completed_at')
    list_filter = ('is_eligible', 'completed_at')
    search_fields = ('user__username', 'user__email')
    readonly_fields = ('completed_at', 'responses', 'disqualification_reasons')
    ordering = ('-completed_at',)


@admin.register(EligibilityRecord)
class EligibilityRecordAdmin(admin.ModelAdmin):
    list_display = ('user', 'is_eligible', 'last_quiz_date', 'eligibility_valid_until')
    list_filter = ('is_eligible', 'last_quiz_date', 'eligibility_valid_until')
    search_fields = ('user__username', 'user__email')
    readonly_fields = ('created_at', 'updated_at')
    ordering = ('-updated_at',)
