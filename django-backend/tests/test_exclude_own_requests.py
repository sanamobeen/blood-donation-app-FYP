"""
Unit test for the fix that prevents donors from seeing their own blood requests.
This tests the view logic directly with a mock request.
"""
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIRequestFactory, force_authenticate
from blood_requests.models import BloodRequest
from blood_requests.views import blood_request_list, nearby_blood_requests


class ExcludeOwnRequestsUnitTest(TestCase):
    """Unit test that the filter logic works correctly."""

    def setUp(self):
        """Set up test data."""
        self.factory = APIRequestFactory()

        # Create a test user
        self.user = get_user_model().objects.create_user(
            email='testuser@example.com',
            password='testpass123',
            full_name='Test User'
        )

        # Create another user
        self.other_user = get_user_model().objects.create_user(
            email='otheruser@example.com',
            password='testpass123',
            full_name='Other User'
        )

        # Create blood request by the test user
        self.user_request = BloodRequest.objects.create(
            patient_name='John Doe',
            blood_group='A+',
            units_needed=2,
            urgency_level='urgent',
            contact_number='+923001234567',
            hospital_name='Test Hospital',
            requested_by=self.user
        )

        # Create blood request by another user
        self.other_request = BloodRequest.objects.create(
            patient_name='Jane Smith',
            blood_group='A+',
            units_needed=1,
            urgency_level='normal',
            contact_number='+923009876543',
            hospital_name='Other Hospital',
            requested_by=self.other_user
        )

        # Create anonymous blood request
        self.anonymous_request = BloodRequest.objects.create(
            patient_name='Anonymous Patient',
            blood_group='A+',
            units_needed=1,
            urgency_level='critical',
            contact_number='+923005551234',
            hospital_name='City Hospital',
            requested_by=None
        )

    def test_anonymous_user_sees_all_requests(self):
        """Test that anonymous users see all blood requests."""
        # Create a request without authentication
        request = self.factory.get('/api/blood-requests/')

        response = blood_request_list(request)
        data = response.data

        # Should see all 3 requests
        self.assertEqual(data['count'], 3)
        print("PASS: Anonymous user sees all 3 requests")

    def test_authenticated_user_does_not_see_own_request(self):
        """Test that authenticated user doesn't see their own blood requests."""
        # Create a request with authentication using DRF's force_authenticate
        request = self.factory.get('/api/blood-requests/')
        force_authenticate(request, user=self.user)

        response = blood_request_list(request)
        data = response.data

        # Should only see 2 requests (other user's and anonymous)
        self.assertEqual(data['count'], 2)

        # Verify request IDs
        request_ids = [req['id'] for req in data['blood_requests']]
        self.assertNotIn(str(self.user_request.id), request_ids)  # Own excluded
        self.assertIn(str(self.other_request.id), request_ids)  # Other's included
        self.assertIn(str(self.anonymous_request.id), request_ids)  # Anonymous included
        print("PASS: Authenticated user does NOT see their own request")

    def test_nearby_requests_excludes_own(self):
        """Test that nearby blood requests also exclude user's own requests."""
        request = self.factory.get('/api/blood-requests/nearby/?lat=40.7128&lng=-74.0060')
        force_authenticate(request, user=self.user)

        response = nearby_blood_requests(request)
        data = response.data

        # Should only see 2 requests
        self.assertEqual(data['count'], 2)

        # Verify request IDs
        request_ids = [req['id'] for req in data['requests']]
        self.assertNotIn(str(self.user_request.id), request_ids)
        self.assertIn(str(self.other_request.id), request_ids)
        self.assertIn(str(self.anonymous_request.id), request_ids)
        print("PASS: Nearby requests exclude user's own requests")


if __name__ == '__main__':
    import django
    import os

    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
    django.setup()

    from django.test.utils import get_runner
    from django.conf import settings

    TestRunner = get_runner(settings)
    test_runner = TestRunner(verbosity=2, interactive=False, keepdb=False)
    test_runner.run_tests(['__main__'])
