"""
Management command to seed blood types with compatibility data.
"""
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = 'Seeds blood types with compatibility data'

    def handle(self, *args, **options):
        from blood_types.models import BloodType

        # Blood type compatibility data for donation
        blood_types_data = [
            {
                'code': 'O+',
                'name': 'O Positive',
                'compatibility': ['O+', 'A+', 'B+', 'AB+'],
                'sort_order': 1,
            },
            {
                'code': 'O-',
                'name': 'O Negative',
                'compatibility': ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'],
                'sort_order': 2,
            },
            {
                'code': 'A+',
                'name': 'A Positive',
                'compatibility': ['A+', 'AB+'],
                'sort_order': 3,
            },
            {
                'code': 'A-',
                'name': 'A Negative',
                'compatibility': ['A+', 'A-', 'AB+', 'AB-'],
                'sort_order': 4,
            },
            {
                'code': 'B+',
                'name': 'B Positive',
                'compatibility': ['B+', 'AB+'],
                'sort_order': 5,
            },
            {
                'code': 'B-',
                'name': 'B Negative',
                'compatibility': ['B+', 'B-', 'AB+', 'AB-'],
                'sort_order': 6,
            },
            {
                'code': 'AB+',
                'name': 'AB Positive',
                'compatibility': ['AB+'],
                'sort_order': 7,
            },
            {
                'code': 'AB-',
                'name': 'AB Negative',
                'compatibility': ['AB+', 'AB-'],
                'sort_order': 8,
            },
        ]

        created_count = 0
        updated_count = 0

        for blood_type_data in blood_types_data:
            obj, created = BloodType.objects.get_or_create(
                code=blood_type_data['code'],
                defaults=blood_type_data
            )
            if created:
                created_count += 1
                self.stdout.write(
                    self.style.SUCCESS(f"Created blood type: {obj.code}")
                )
            else:
                # Update existing
                for key, value in blood_type_data.items():
                    setattr(obj, key, value)
                obj.save()
                updated_count += 1
                self.stdout.write(
                    self.style.WARNING(f"Updated blood type: {obj.code}")
                )

        self.stdout.write(
            self.style.SUCCESS(
                f"\nSummary: {created_count} created, {updated_count} updated"
            )
        )
