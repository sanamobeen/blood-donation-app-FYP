"""
Reliability scoring service layer for Blood Donation Backend.

PHASE 3: SERVICE-BASED SCORING (not signals)

Using service layer instead of signals because:
1. Signals can cause double updates in complex systems
2. Signals make debugging difficult
3. Services are explicit and testable
4. Services can be called anywhere intentionally

SCORING SYSTEM:
- Base score: 100
- Each on-time donation: +10
- Each late donation: +3
- Each cancellation: -10
- Each no-show: -20
- Minimum score: 0
- Maximum score: 100

BADGES:
- Top Donor: score >= 90
- Reliable: score >= 75
"""
from django.db import transaction
from django.utils import timezone
from blood_requests.models import DonorResponse
from .models import UserProfile
import logging

logger = logging.getLogger(__name__)


class ReliabilityScoringService:
    """Service for managing donor reliability scores."""

    @staticmethod
    @transaction.atomic
    def update_on_pledge_created(pledge: DonorResponse):
        """
        Update stats when pledge is created.

        Called explicitly from create_pledge view.
        """
        if not pledge.donor:
            return

        profile = getattr(pledge.donor, 'profile', None)
        if not profile:
            return

        profile.total_pledges += 1
        profile.save(update_fields=['total_pledges'])
        logger.info(f"Updated pledge count for user {pledge.donor.id}")

    @staticmethod
    @transaction.atomic
    def update_on_pledge_cancelled(pledge: DonorResponse):
        """
        Update stats and score when pledge is cancelled.

        Called explicitly from cancel_pledge view.
        Penalty: -10 points
        """
        if not pledge.donor:
            return

        profile = getattr(pledge.donor, 'profile', None)
        if not profile:
            return

        profile.cancelled_pledges += 1
        profile.save(update_fields=['cancelled_pledges'])

        # Recalculate score
        new_score = profile.update_reliability_score()
        logger.info(f"User {pledge.donor.id} cancelled pledge. New score: {new_score}")

    @staticmethod
    @transaction.atomic
    def update_on_donation_completed(pledge: DonorResponse, was_on_time: bool = True):
        """
        Update stats and score when donation is completed.

        Called explicitly from confirm_donation view.
        Reward: +10 points (on-time), +3 points (late)
        """
        if not pledge.donor:
            return

        profile = getattr(pledge.donor, 'profile', None)
        if not profile:
            return

        profile.successful_donations += 1
        if was_on_time:
            profile.on_time_arrivals += 1
        else:
            profile.late_arrivals += 1

        profile.save(update_fields=[
            'successful_donations', 'on_time_arrivals', 'late_arrivals'
        ])

        # Recalculate score
        new_score = profile.update_reliability_score()
        logger.info(f"User {pledge.donor.id} completed donation. New score: {new_score}")

    @staticmethod
    @transaction.atomic
    def update_on_no_show(pledge: DonorResponse):
        """
        Update stats and score when donor is reported as no-show.

        Called explicitly from report_no_show view.
        Penalty: -20 points
        """
        if not pledge.donor:
            return

        profile = getattr(pledge.donor, 'profile', None)
        if not profile:
            return

        profile.no_shows += 1
        profile.save(update_fields=['no_shows'])

        # Recalculate score
        new_score = profile.update_reliability_score()
        logger.warning(f"User {pledge.donor.id} reported as no-show. New score: {new_score}")

    @staticmethod
    def get_donor_ranking(user) -> dict:
        """
        Get donor's ranking information.
        Returns stats and badge information.

        Args:
            user: CustomUser instance

        Returns:
            dict: Donor ranking info with score, badge, and stats
        """
        profile = getattr(user, 'profile', None)
        if not profile:
            return {
                'score': 100,  # Default for new users
                'badge': 'new_donor',
                'stats': {
                    'total_pledges': 0,
                    'successful_donations': 0,
                    'cancelled_pledges': 0,
                    'no_shows': 0,
                    'on_time_arrivals': 0,
                    'late_arrivals': 0,
                }
            }

        # Determine badge based on score and history
        if profile.no_shows > 2:
            badge = 'unreliable'
        elif profile.reliability_score >= 90 and profile.successful_donations >= 5:
            badge = 'top_donor'
        elif profile.reliability_score >= 75 and profile.successful_donations >= 3:
            badge = 'reliable'
        elif profile.reliability_score >= 50:
            badge = 'average'
        else:
            badge = 'low_score'

        return {
            'score': profile.reliability_score,
            'badge': badge,
            'is_verified': profile.is_verified_donor,
            'is_top_donor': profile.is_top_donor,
            'is_reliable': profile.is_reliable,
            'stats': {
                'total_pledges': profile.total_pledges,
                'successful_donations': profile.successful_donations,
                'cancelled_pledges': profile.cancelled_pledges,
                'no_shows': profile.no_shows,
                'on_time_arrivals': profile.on_time_arrivals,
                'late_arrivals': profile.late_arrivals,
            }
        }

    @staticmethod
    def calculate_ranking_percentile(user) -> float:
        """
        Calculate donor's ranking percentile among all donors.

        Returns a value between 0 and 100 indicating what percentage
        of donors have a lower reliability score.

        Args:
            user: CustomUser instance

        Returns:
            float: Percentile (0-100)
        """
        from django.db.models import Q

        profile = getattr(user, 'profile', None)
        if not profile:
            return 50.0  # Default to 50th percentile

        # Count donors with lower scores
        total_donors = UserProfile.objects.filter(
            user__role='donor'
        ).count()

        if total_donors == 0:
            return 100.0

        donors_below = UserProfile.objects.filter(
            user__role='donor',
            reliability_score__lt=profile.reliability_score
        ).count()

        return (donors_below / total_donors) * 100


# Export the service instance
reliability_service = ReliabilityScoringService()
