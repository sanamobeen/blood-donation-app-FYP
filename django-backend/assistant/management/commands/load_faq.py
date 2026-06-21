"""
Management command to load FAQ data from CSV file.

Usage:
    python manage.py load_faq [--file path/to/faq.csv] [--clear]
"""
import os
import pandas as pd
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from assistant.models import FAQ


class Command(BaseCommand):
    help = 'Load FAQ data from CSV file into database'

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            default='faq.csv',
            help='Path to FAQ CSV file (default: faq.csv)'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing FAQs before loading'
        )

    def handle(self, *args, **options):
        """Load FAQ data from CSV file."""
        file_path = options['file']
        clear_existing = options['clear']

        # Check if file exists
        if not os.path.exists(file_path):
            self.stdout.write(
                self.style.ERROR(f'File not found: {file_path}')
            )
            self.stdout.write(
                self.style.WARNING('Looking for FAQ file in project root...')
            )
            # Try project root
            project_root = settings.BASE_DIR.parent
            alt_path = os.path.join(project_root, file_path)
            if os.path.exists(alt_path):
                file_path = alt_path
                self.stdout.write(
                    self.style.SUCCESS(f'Found file at: {file_path}')
                )
            else:
                raise CommandError(f'Could not find FAQ file: {file_path}')

        # Clear existing FAQs if requested
        if clear_existing:
            count = FAQ.objects.all().delete()[0]
            self.stdout.write(
                self.style.WARNING(f'Cleared {count} existing FAQs')
            )

        # Load FAQ data
        self.stdout.write(f'Loading FAQs from: {file_path}')
        try:
            df = pd.read_csv(file_path)
        except Exception as e:
            raise CommandError(f'Error reading CSV file: {e}')

        # Validate columns
        required_columns = ['question', 'answer', 'category']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise CommandError(
                f'Missing required columns: {missing_columns}\n'
                f'Found columns: {list(df.columns)}'
            )

        # Create FAQs
        created_count = 0
        updated_count = 0
        error_count = 0

        for index, row in df.iterrows():
            try:
                question = row['question'].strip()
                answer = row['answer'].strip()
                category = row['category'].strip()
                keywords = row.get('keywords', '').strip() if 'keywords' in row else ''
                priority = int(row.get('priority', 0)) if 'priority' in row else 0

                # Check if FAQ already exists (by question)
                existing = FAQ.objects.filter(question=question).first()

                if existing:
                    # Update existing
                    existing.answer = answer
                    existing.category = category
                    existing.keywords = keywords
                    existing.priority = priority
                    existing.is_active = True
                    existing.save()
                    updated_count += 1
                else:
                    # Create new
                    FAQ.objects.create(
                        question=question,
                        answer=answer,
                        category=category,
                        keywords=keywords,
                        priority=priority,
                        is_active=True
                    )
                    created_count += 1

            except Exception as e:
                error_count += 1
                self.stdout.write(
                    self.style.ERROR(f'Error processing row {index + 1}: {e}')
                )

        # Summary
        total_processed = created_count + updated_count + error_count
        self.stdout.write(
            self.style.SUCCESS(
                f'\nFAQ Loading Complete:\n'
                f'  Total rows: {total_processed}\n'
                f'  Created: {created_count}\n'
                f'  Updated: {updated_count}\n'
                f'  Errors: {error_count}\n'
                f'  Total FAQs in database: {FAQ.objects.filter(is_active=True).count()}'
            )
        )

        # Reload chatbot cache
        try:
            from assistant.chatbot_service import reload_chatbot
            reload_chatbot()
            self.stdout.write(
                self.style.SUCCESS('Chatbot cache reloaded successfully!')
            )
        except Exception as e:
            self.stdout.write(
                self.style.WARNING(f'Could not reload chatbot cache: {e}')
            )
