"""
Django Management Command to Load FAQs from JSON/CSV File

Usage:
    python manage.py load_faqs faqs.json
    python manage.py load_faqs faq.csv
    python manage.py load_faqs faqs.json --update
"""

import json
import csv
import os
from django.core.management.base import BaseCommand
from django.db import transaction
from assistant.models import FAQ


class Command(BaseCommand):
    help = 'Load FAQs from JSON or CSV file into the database'

    def add_arguments(self, parser):
        parser.add_argument(
            'file_path',
            type=str,
            help='Path to the JSON or CSV file containing FAQs'
        )
        parser.add_argument(
            '--update',
            action='store_true',
            help='Update existing FAQs instead of skipping them'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear all existing FAQs before loading'
        )

    def handle(self, *args, **options):
        file_path = options['file_path']
        update_mode = options['update']
        clear_mode = options['clear']

        # Check if file exists
        if not os.path.exists(file_path):
            self.stdout.write(
                self.style.ERROR(f'File not found: {file_path}')
            )
            return

        # Clear existing FAQs if requested
        if clear_mode:
            count = FAQ.objects.count()
            FAQ.objects.all().delete()
            self.stdout.write(
                self.style.WARNING(f'Cleared {count} existing FAQs')
            )

        # Determine file type and load
        if file_path.endswith('.json'):
            self.load_from_json(file_path, update_mode)
        elif file_path.endswith('.csv'):
            self.load_from_csv(file_path, update_mode)
        else:
            self.stdout.write(
                self.style.ERROR('Unsupported file format. Use .json or .csv')
            )

    def load_from_json(self, file_path, update_mode):
        """Load FAQs from JSON file"""
        self.stdout.write(f'Loading FAQs from JSON: {file_path}')

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                faqs_data = json.load(f)

            if not isinstance(faqs_data, list):
                self.stdout.write(
                    self.style.ERROR('JSON must be a list of FAQ objects')
                )
                return

            self.process_faqs(faqs_data, update_mode)

        except json.JSONDecodeError as e:
            self.stdout.write(
                self.style.ERROR(f'Invalid JSON: {e}')
            )
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error reading file: {e}')
            )

    def load_from_csv(self, file_path, update_mode):
        """Load FAQs from CSV file"""
        self.stdout.write(f'Loading FAQs from CSV: {file_path}')

        try:
            faqs_data = []
            with open(file_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    faqs_data.append(row)

            self.process_faqs(faqs_data, update_mode)

        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error reading CSV: {e}')
            )

    @transaction.atomic
    def process_faqs(self, faqs_data, update_mode):
        """Process and save FAQs to database"""
        created_count = 0
        updated_count = 0
        skipped_count = 0
        error_count = 0

        total = len(faqs_data)
        self.stdout.write(f'Processing {total} FAQs...')

        for i, faq_dict in enumerate(faqs_data, 1):
            try:
                # Check if FAQ already exists (by question)
                question = faq_dict.get('question', '').strip()
                if not question:
                    self.stdout.write(
                        self.style.WARNING(f'{i}/{total}: Skipping - empty question')
                    )
                    skipped_count += 1
                    continue

                existing = FAQ.objects.filter(question=question).first()

                if existing:
                    if update_mode:
                        # Update existing FAQ
                        existing.answer = faq_dict.get('answer', '')
                        existing.category = faq_dict.get('category', '')
                        existing.keywords = faq_dict.get('keywords', '')
                        existing.priority = int(faq_dict.get('priority', 0))
                        existing.target_role = faq_dict.get('target_role', 'both')
                        existing.is_active = True
                        existing.save()
                        updated_count += 1
                        self.stdout.write(
                            self.style.SUCCESS(f'{i}/{total}: Updated - "{question[:50]}..."')
                        )
                    else:
                        skipped_count += 1
                        self.stdout.write(
                            self.style.NOTICE(f'{i}/{total}: Skipped (already exists) - "{question[:50]}..."')
                        )
                else:
                    # Create new FAQ
                    FAQ.objects.create(
                        question=question,
                        answer=faq_dict.get('answer', ''),
                        category=faq_dict.get('category', ''),
                        keywords=faq_dict.get('keywords', ''),
                        priority=int(faq_dict.get('priority', 0)),
                        target_role=faq_dict.get('target_role', 'both'),
                        is_active=True
                    )
                    created_count += 1
                    self.stdout.write(
                        self.style.SUCCESS(f'{i}/{total}: Created - "{question[:50]}..."')
                    )

            except Exception as e:
                error_count += 1
                self.stdout.write(
                    self.style.ERROR(f'{i}/{total}: Error - {str(e)}')
                )

        # Summary
        self.stdout.write('\n' + '=' * 70)
        self.stdout.write(self.style.SUCCESS('LOAD SUMMARY'))
        self.stdout.write('=' * 70)
        self.stdout.write(f'Total processed: {total}')
        self.stdout.write(self.style.SUCCESS(f'Created: {created_count}'))
        self.stdout.write(self.style.WARNING(f'Updated: {updated_count}'))
        self.stdout.write(self.style.NOTICE(f'Skipped: {skipped_count}'))
        self.stdout.write(self.style.ERROR(f'Errors: {error_count}'))

        # Reload chatbot cache
        try:
            from assistant.chatbot_service import reload_chatbot
            reload_chatbot()
            self.stdout.write(
                self.style.SUCCESS('\n✓ Chatbot cache reloaded successfully')
            )
        except Exception as e:
            self.stdout.write(
                self.style.WARNING(f'\n⚠ Could not reload chatbot cache: {e}')
            )
