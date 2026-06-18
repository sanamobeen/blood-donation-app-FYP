"""
Django management command to set roles for users with None role.

Usage:
    python manage.py set_user_roles --role donor        # Set all users with None role to donor
    python manage.py set_user_roles --role patient      # Set all users with None role to patient
    python manage.py set_user_roles --email user@example.com --role donor  # Set specific user's role
"""
from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth import get_user_model
from account.models import CustomUser


class Command(BaseCommand):
    help = 'Set role for users who have no role assigned'

    def add_arguments(self, parser):
        parser.add_argument(
            '--role',
            type=str,
            required=True,
            choices=['donor', 'patient', 'admin'],
            help='Role to assign to users (donor, patient, or admin)',
        )
        parser.add_argument(
            '--email',
            type=str,
            help='Specific user email to update (if not provided, updates all users with None role)',
        )
        parser.add_argument(
            '--force',
            action='store_true',
            help='Update role even if user already has a role set',
        )

    def handle(self, *args, **options):
        role = options['role']
        email = options.get('email')
        force = options.get('force', False)

        if email:
            # Update specific user
            try:
                user = CustomUser.objects.get(email=email)
                if user.role and not force:
                    self.stdout.write(
                        self.style.WARNING(f'User {email} already has role: {user.role}. Use --force to override.')
                    )
                    return

                old_role = user.role
                user.role = role
                user.save(update_fields=['role'])

                self.stdout.write(
                    self.style.SUCCESS(f'Updated user {email}: {old_role} -> {role}')
                )
            except CustomUser.DoesNotExist:
                raise CommandError(f'User with email {email} does not exist')
        else:
            # Update all users with None role
            users_to_update = CustomUser.objects.filter(role__isnull=True) | CustomUser.objects.filter(role='')

            if not force:
                users_to_update = users_to_update.filter(role__isnull=True)

            count = users_to_update.count()
            if count == 0:
                self.stdout.write(self.style.SUCCESS('No users found with None role'))
                return

            self.stdout.write(f'Found {count} users with None role')
            self.stdout.write('Users to be updated:')

            for user in users_to_update:
                self.stdout.write(f'  - {user.email}')

            # Confirm before bulk update
            confirm = input(f'\nProceed to set {count} users to role "{role}"? (yes/no): ')
            if confirm.lower() != 'yes':
                self.stdout.write(self.style.WARNING('Operation cancelled'))
                return

            # Update all users
            updated = users_to_update.update(role=role)
            self.stdout.write(
                self.style.SUCCESS(f'Successfully updated {updated} users to role "{role}"')
            )
