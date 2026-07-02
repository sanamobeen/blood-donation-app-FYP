"""
Utility functions for Blood Requests app.

This module provides helper functions for:
- Blood compatibility checking
- GPS distance calculation using Haversine formula
- Optimized nearby request queries
- Donor availability time slot matching
"""
from math import radians, cos, sin, sqrt, asin
from datetime import datetime
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)


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


# ============================================================================
# Donor Availability Time Slot Matching
# ============================================================================

# Day name mapping for datetime weekday() to availability JSON keys
WEEKDAY_MAP = {
    0: 'monday',
    1: 'tuesday',
    2: 'wednesday',
    3: 'thursday',
    4: 'friday',
    5: 'saturday',
    6: 'sunday',
}

# Time slot parsing - convert "8am_10am" to (8, 10)
TIME_SLOT_PATTERNS = {
    'am': 'am',
    'pm': 'pm',
    '12am': 0, '12pm': 12,
}


def parse_time_slot(slot_str: str) -> tuple:
    """
    Parse a time slot string like '8am_10am' or '4pm_6pm' into start and end hours.

    Args:
        slot_str: Time slot string in format 'Xam_Yam' or 'Xpm_Ypm'

    Returns:
        tuple: (start_hour, end_hour) in 24-hour format

    Examples:
        >>> parse_time_slot('8am_10am')
        (8, 10)
        >>> parse_time_slot('4pm_6pm')
        (16, 18)
        >>> parse_time_slot('12pm_2pm')
        (12, 14)
    """
    if not slot_str or '_' not in slot_str:
        return None

    try:
        parts = slot_str.split('_')
        if len(parts) != 2:
            return None

        start_str, end_str = parts

        # Parse start time
        start_hour = parse_time_string(start_str)
        # Parse end time
        end_hour = parse_time_string(end_str)

        if start_hour is None or end_hour is None:
            return None

        return (start_hour, end_hour)

    except Exception as e:
        logger.warning(f"Failed to parse time slot '{slot_str}': {e}")
        return None


def parse_time_string(time_str: str) -> int:
    """
    Parse a time string like '8am', '12pm', '4pm' into hour in 24-hour format.

    Args:
        time_str: Time string like '8am', '12pm', '4pm'

    Returns:
        int: Hour in 24-hour format (0-23)

    Examples:
        >>> parse_time_string('8am')
        8
        >>> parse_time_string('8pm')
        20
        >>> parse_time_string('12am')
        0
        >>> parse_time_string('12pm')
        12
    """
    time_str = time_str.lower().strip()

    # Handle 12am and 12pm first (special cases)
    if time_str == '12am':
        return 0
    if time_str == '12pm':
        return 12

    # Parse hour and meridiem
    if 'am' in time_str:
        hour_str = time_str.replace('am', '').strip()
        hour = int(hour_str)
        return hour  # 1am-11am stay as 1-11
    elif 'pm' in time_str:
        hour_str = time_str.replace('pm', '').strip()
        hour = int(hour_str)
        if hour == 12:
            return 12  # 12pm stays as 12
        return hour + 12  # 1pm-11pm become 13-23

    return None


def is_time_in_slot(dt: datetime, slot: tuple) -> bool:
    """
    Check if a datetime falls within a time slot.

    Args:
        dt: DateTime to check
        slot: Tuple of (start_hour, end_hour) in 24-hour format

    Returns:
        bool: True if datetime is within the time slot

    Examples:
        >>> dt = datetime(2024, 1, 15, 9, 0)  # 9 AM on Monday
        >>> is_time_in_slot(dt, (8, 10))  # 8 AM - 10 AM slot
        True
        >>> is_time_in_slot(dt, (16, 18))  # 4 PM - 6 PM slot
        False
    """
    if not slot or len(slot) != 2:
        return False

    start_hour, end_hour = slot
    current_hour = dt.hour

    # Check if current hour is within the slot
    # We use >= start and < end to handle hour-based slots
    # For example, 5pm_6pm means hour 17 (5 PM) up to but not including hour 18 (6 PM)
    return start_hour <= current_hour < end_hour


def is_donor_available_at_time(needed_datetime: datetime, availability: dict = None,
                                available_all_day: bool = False) -> bool:
    """
    Check if a donor is available at a specific datetime based on their availability schedule.

    Args:
        needed_datetime: The datetime when blood is needed
        availability: Donor's availability dict like {'monday': ['8am_10am', '4pm_6pm'], ...}
        available_all_day: If True, donor is available all day every day

    Returns:
        bool: True if donor is available at the given datetime

    Examples:
        >>> dt = datetime(2024, 1, 15, 9, 0)  # Monday 9 AM
        >>> availability = {'monday': ['8am_10am', '4pm_6pm']}
        >>> is_donor_available_at_time(dt, availability)
        True
        >>> dt2 = datetime(2024, 1, 15, 14, 0)  # Monday 2 PM
        >>> is_donor_available_at_time(dt2, availability)
        False
        >>> is_donor_available_at_time(dt2, available_all_day=True)
        True
    """
    # If available all day, always return True
    if available_all_day:
        return True

    # If no availability set, assume available (backward compatibility)
    if not availability:
        return True

    # Convert to local timezone for day checking
    # Use UTC but get the weekday
    try:
        # Get the day of week (0 = Monday, 6 = Sunday)
        weekday = needed_datetime.weekday()
        day_key = WEEKDAY_MAP.get(weekday)

        if not day_key:
            logger.warning(f"Invalid weekday: {weekday}")
            return True

        # Get available slots for this day
        day_slots = availability.get(day_key, [])

        # If no slots defined for this day, donor is not available
        if not day_slots:
            return False

        # Check each time slot
        for slot_str in day_slots:
            slot = parse_time_slot(slot_str)
            if slot and is_time_in_slot(needed_datetime, slot):
                return True

        # No matching slot found
        return False

    except Exception as e:
        logger.error(f"Error checking donor availability: {e}")
        # Fail open - if we can't check, assume available
        return True


def filter_requests_by_availability(requests, donor_profile, current_time=None) -> list:
    """
    Filter blood requests based on donor's availability schedule.

    This function filters a list of blood requests to only include those whose
    needed_by time falls within the donor's availability slots.

    Args:
        requests: QuerySet or list of BloodRequest objects
        donor_profile: UserProfile object of the donor
        current_time: Current datetime (optional, uses timezone.now() if not provided)

    Returns:
        list: Filtered list of BloodRequest objects

    Examples:
        >>> requests = BloodRequest.objects.filter(status='pending')
        >>> donor = request.user.profile
        >>> filtered = filter_requests_by_availability(requests, donor)
    """
    if not current_time:
        current_time = timezone.now()

    # Get donor availability settings
    available_all_day = donor_profile.available_all_day if donor_profile else False
    availability = donor_profile.availability if donor_profile else None

    filtered_requests = []
    skipped_count = 0

    for req in requests:
        # Check if request has needed_by datetime
        if not req.needed_by:
            # If no needed_by time, include it (backward compatibility)
            filtered_requests.append(req)
            continue

        # Check if donor is available at the needed time
        if is_donor_available_at_time(req.needed_by, availability, available_all_day):
            filtered_requests.append(req)
        else:
            skipped_count += 1
            logger.debug(f"Filtered out request {req.id} - needed time {req.needed_by} not in donor availability")

    if skipped_count > 0:
        logger.info(f"Filtered {skipped_count} requests outside donor availability")

    return filtered_requests


def get_donor_availability_summary(donor_profile) -> dict:
    """
    Get a summary of donor's availability for display.

    Args:
        donor_profile: UserProfile object

    Returns:
        dict: Summary with available_days, time_slots, and available_all_day

    Examples:
        >>> summary = get_donor_availability_summary(user.profile)
        >>> print(summary['available_days'])  # ['Monday', 'Tuesday', ...]
        >>> print(summary['time_slots'])  # {'Monday': ['8am-10am'], ...}
    """
    if not donor_profile:
        return {}

    availability = donor_profile.availability or {}

    # Count available days
    available_days = []
    time_slots = {}

    day_names = {
        'monday': 'Monday',
        'tuesday': 'Tuesday',
        'wednesday': 'Wednesday',
        'thursday': 'Thursday',
        'friday': 'Friday',
        'saturday': 'Saturday',
        'sunday': 'Sunday',
    }

    for day_key, slots in availability.items():
        if slots:
            day_name = day_names.get(day_key.capitalize(), day_key.capitalize())
            available_days.append(day_name)
            # Format slots for display
            formatted_slots = []
            for slot in slots:
                parsed = parse_time_slot(slot)
                if parsed:
                    start, end = parsed
                    # Convert to readable format
                    formatted_slots.append(f"{start}:00-{end}:00")
            time_slots[day_name] = formatted_slots

    return {
        'available_all_day': donor_profile.available_all_day,
        'available_days': available_days,
        'time_slots': time_slots,
    }
