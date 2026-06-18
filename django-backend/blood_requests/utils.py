"""
Utility functions for Blood Requests app.

This module provides helper functions for:
- Blood compatibility checking
- GPS distance calculation using Haversine formula
- Optimized nearby request queries
"""
from math import radians, cos, sin, sqrt, asin


# Complete blood compatibility matrix (donor -> can donate to)
# Based on ABO and Rh factor compatibility rules
BLOOD_COMPATIBILITY = {
    'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],  # Universal donor
    'O+': ['A+', 'B+', 'AB+', 'O+'],
    'A-': ['A+', 'A-', 'AB+', 'AB-'],
    'A+': ['A+', 'AB+'],
    'B-': ['B+', 'B-', 'AB+', 'AB-'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB+', 'AB-'],
    'AB+': ['AB+'],  # Universal recipient
}


def can_donate(donor_blood_group: str, recipient_blood_group: str) -> bool:
    """
    Check if donor can donate to recipient based on blood compatibility.

    Args:
        donor_blood_group: Blood group of the donor (e.g., 'O+', 'A-')
        recipient_blood_group: Blood group of the recipient (e.g., 'A+', 'AB-')

    Returns:
        bool: True if donor can donate to recipient, False otherwise

    Examples:
        >>> can_donate('O-', 'A+')
        True
        >>> can_donate('A+', 'O-')
        False
    """
    if not donor_blood_group or not recipient_blood_group:
        return False
    return recipient_blood_group in BLOOD_COMPATIBILITY.get(donor_blood_group, [])


def get_compatible_blood_groups(recipient_blood_group: str) -> list:
    """
    Get all donor blood types that can donate to a recipient.

    Args:
        recipient_blood_group: Blood group of the recipient

    Returns:
        list: List of compatible donor blood groups

    Examples:
        >>> get_compatible_blood_groups('A+')
        ['A-', 'O-', 'A+', 'O+']
    """
    compatible = []
    for donor_type, recipients in BLOOD_COMPATIBILITY.items():
        if recipient_blood_group in recipients:
            compatible.append(donor_type)
    return compatible


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate distance between two coordinates using Haversine formula.

    The Haversine formula calculates the great-circle distance between
    two points on a sphere given their longitudes and latitudes.

    Args:
        lat1: Latitude of first point in decimal degrees
        lon1: Longitude of first point in decimal degrees
        lat2: Latitude of second point in decimal degrees
        lon2: Longitude of second point in decimal degrees

    Returns:
        float: Distance between the two points in kilometers

    Examples:
        >>> haversine_distance(24.8607, 67.0011, 24.8500, 67.0500)
        5.32
    """
    # Convert to radians
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    r = 6371  # Earth's radius in kilometers

    return c * r


def get_nearby_requests_optimized(donor_lat, donor_lng, radius_km, donor_blood_group=None, exclude_user=None):
    """
    Optimized version for finding nearby blood requests.

    STRATEGY for scalability:
    1. First filter by blood compatibility (DB query)
    2. Filter results within a BOUNDING BOX (faster than circle)
    3. Then filter by exact distance in Python (for accuracy)

    BOUNDING BOX CALCULATION:
    - ~ 1 degree lat ≈ 111 km
    - ~ 1 degree lng ≈ 111 km (at equator), varies by latitude

    Args:
        donor_lat: Donor's latitude
        donor_lng: Donor's longitude
        radius_km: Search radius in kilometers
        donor_blood_group: Donor's blood group (optional)
        exclude_user: User to exclude (usually the donor themselves)

    Returns:
        list: List of tuples (BloodRequest, distance_km) sorted by distance
    """
    from .models import BloodRequest

    # Calculate bounding box (approximate)
    lat_delta = radius_km / 111.0  # Convert km to degrees
    lng_delta = radius_km / (111.0 * max(0.1, abs(donor_lat)))  # Adjust for latitude

    min_lat = donor_lat - lat_delta
    max_lat = donor_lat + lat_delta
    min_lng = donor_lng - lng_delta
    max_lng = donor_lng + lng_delta

    # Build base queryset with bounding box filter
    queryset = BloodRequest.objects.filter(
        is_active=True,
        status='pending',
        location_lat__isnull=False,
        location_lng__isnull=False,
        location_lat__range=[min_lat, max_lat],
        location_lng__range=[min_lng, max_lng]
    )

    # Exclude donor's own requests
    if exclude_user:
        queryset = queryset.exclude(requested_by=exclude_user)

    # Filter by blood compatibility if donor blood group known
    if donor_blood_group:
        compatible_groups = get_compatible_blood_groups(donor_blood_group)
        queryset = queryset.filter(blood_group__in=compatible_groups)

    # Get results and filter by exact distance (haversine)
    results = []
    for req in queryset:
        if req.location_lat and req.location_lng:
            distance = haversine_distance(
                donor_lat, donor_lng,
                req.location_lat, req.location_lng
            )
            if distance <= radius_km:
                results.append((req, distance))

    # Sort by distance (nearest first)
    results.sort(key=lambda x: x[1])
    return results


def calculate_request_expiration_hours(urgency_level):
    """
    Calculate expiration time based on urgency level.

    Args:
        urgency_level: The urgency level of the request

    Returns:
        int: Hours until expiration

    Examples:
        >>> calculate_request_expiration_hours('critical')
        6
        >>> calculate_request_expiration_hours('normal')
        24
    """
    expiration_map = {
        'critical': 6,   # Critical requests expire in 6 hours
        'urgent': 12,    # Urgent requests expire in 12 hours
        'normal': 24,    # Normal requests expire in 24 hours
    }
    return expiration_map.get(urgency_level, 24)


def activate_backup_donor_locked(blood_request, cancelled_pledge):
    """
    Activate backup donor with row-level locking to prevent race conditions.

    PHASE 4: INTELLIGENT BACKUP SYSTEM

    CRITICAL: This function assumes blood_request row is already locked
    via select_for_update() in the calling transaction.

    PRIORITY RANKING:
    1. Reliability score (highest first) - 2x weight
    2. Distance (nearest first)
    3. Pledge time (earlier pledges get priority)
    4. Availability status

    Args:
        blood_request: The BloodRequest instance (already locked)
        cancelled_pledge: The DonorResponse that was cancelled

    Returns:
        DonorResponse: The activated backup pledge, or None
    """
    from .models import DonorResponse
    from notifications.models import Notification
    import logging

    logger = logging.getLogger(__name__)

    # Get all pending pledges for this request (already locked via blood_request)
    pending_pledges = DonorResponse.objects.filter(
        blood_request=blood_request,
        status='pledged'
    ).exclude(id=cancelled_pledge.id).select_related(
        'donor__profile'
    )

    # Calculate priority score for each pledge
    ranked_pledges = []
    for pledge in pending_pledges:
        profile = pledge.donor.profile if pledge.donor else None
        if not profile:
            continue

        # Skip if not available
        if not profile.is_available_for_donation:
            continue

        # Calculate distance if coordinates available
        distance_score = 0
        if blood_request.location_lat and blood_request.location_lng:
            if profile.location_lat and profile.location_lng:
                distance = haversine_distance(
                    profile.location_lat, profile.location_lng,
                    blood_request.location_lat, blood_request.location_lng
                )
                # Closer is better (invert: 100 - distance)
                distance_score = max(0, 100 - min(distance, 100))

        # Priority components
        reliability_score = profile.reliability_score or 50

        # Calculate time since pledge (newer pledges get slight priority)
        from django.utils import timezone
        hours_since_pledge = (timezone.now() - pledge.created_at).total_seconds() / 3600
        time_score = max(0, 50 - min(hours_since_pledge, 50))

        # Total priority score
        # Reliability is most important (2x weight)
        total_priority = (
            reliability_score * 2 +      # Reliability is most important
            distance_score +              # Closer donors preferred
            time_score                    # Earlier pledges preferred
        )

        ranked_pledges.append({
            'pledge': pledge,
            'priority': total_priority,
            'reliability': reliability_score,
            'distance': distance_score,
        })

    # Sort by priority (highest first)
    ranked_pledges.sort(key=lambda x: x['priority'], reverse=True)

    # Get best backup
    if ranked_pledges:
        backup_pledge = ranked_pledges[0]['pledge']

        # Update pledge status to confirmed
        backup_pledge.status = 'confirmed'
        backup_pledge.confirmed_at = timezone.now()
        backup_pledge.save()

        # Update blood_request active donor
        blood_request.active_donor_pledge_id = backup_pledge.id
        blood_request.save()

        logger.info(f"Activated backup donor {backup_pledge.donor.id} for request {blood_request.id}")

        # Create notification for backup donor
        if backup_pledge.donor:
            Notification.objects.create(
                user=backup_pledge.donor,
                title='You Are Now the Primary Donor!',
                message=f'{blood_request.patient_name}\'s previous donor cancelled. You are now the primary donor for {blood_request.blood_group} blood.',
                type='backup_activated',
                related_request_id=str(blood_request.id),
                related_pledge_id=str(backup_pledge.id)
            )

        # Notify patient
        if blood_request.requested_by:
            Notification.objects.create(
                user=blood_request.requested_by,
                title='Backup Donor Activated',
                message=f'{backup_pledge.donor.full_name or backup_pledge.donor.email} has been activated as your backup donor.',
                type='backup_activated',
                related_request_id=str(blood_request.id),
                related_pledge_id=str(backup_pledge.id)
            )

        return backup_pledge

    # No backup available
    logger.warning(f"No backup donors available for request {blood_request.id}")

    if blood_request.requested_by:
        Notification.objects.create(
            user=blood_request.requested_by,
            title='No Backup Donor Available',
            message=f'Your blood request for {blood_request.blood_group} blood has no backup donors. You may want to create a new request.',
            type='no_backup_available',
            related_request_id=str(blood_request.id)
        )

    return None
