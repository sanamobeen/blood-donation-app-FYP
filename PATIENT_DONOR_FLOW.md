# Blood Donation App - Patient & Donor Flow Documentation

## Table of Contents
1. [Overview](#overview)
2. [User Roles & Authentication](#user-roles--authentication)
3. [Patient Flow](#patient-flow)
4. [Donor Flow](#donor-flow)
5. [Data Models](#data-models)
6. [API Endpoints](#api-endpoints)
7. [Status Flow Diagrams](#status-flow-diagrams)

---

## Overview

The Blood Donation App connects patients needing blood with willing donors in their vicinity. The system uses GPS-based matching, real-time notifications, and a comprehensive pledge tracking system.

### Key Features
- **GPS-based matching** between patients and donors
- **Real-time notifications** for pledge updates
- **Multi-status donation tracking** (pledged → confirmed → on_the_way → arrived → ready → completed)
- **Reliability scoring system** for donors
- **Auto-expiring blood requests** based on urgency
- **Chat system** between confirmed donors and patients
- **Role switching** capability (donor ↔ patient)
- **One donor per request** policy - once a donor pledges, other donors cannot pledge to the same request

---

## User Roles & Authentication

### User Model (`CustomUser`)
```python
class CustomUser(AbstractUser):
    id: UUID (primary key)
    email: EmailField (unique, username field)
    full_name: CharField
    phone_num: CharField (optional, with validation)
    phone_verified: BooleanField (default: False)
    role: CharField (choices: donor, patient, admin)
    is_active: BooleanField (default: True)
```

### Authentication Flow
1. **Registration** (`POST /api/auth/register/`)
   - Email, password, full name required
   - Phone number optional
   - Role can be set during registration or later

2. **Login** (`POST /api/auth/login/`)
   - Email + password authentication
   - Returns JWT access + refresh tokens
   - Returns user profile if exists

3. **Profile Creation** (`POST /api/auth/profile/create/`)
   - Required for donors
   - Includes blood group, location, medical info

4. **Role Selection**
   - Users can switch between donor and patient roles
   - Role switch updates `user.role` field
   - Different UI/features based on active role

---

## Patient Flow

### 1. Registration & Onboarding

```
Patient Registration
├── Sign Up (email, password, name)
├── Phone Verification (OTP)
├── Role Selection (Patient)
└── Profile Setup (optional for patients)
```

**Frontend Screens:**
- `SignUpScreen` - Registration form
- `LoginScreen` - Login form
- `RoleSelectionScreen` - Choose donor/patient
- `ProfileSetupScreen` - Optional profile completion

### 2. Creating Blood Request

**Backend:** `POST /api/blood-requests/create/`

**Request Data:**
```json
{
  "patient_name": "John Doe",
  "blood_group": "A+",
  "units_needed": 2,
  "urgency_level": "urgent|critical|normal",
  "contact_number": "+923001234567",
  "hospital_name": "City Hospital (optional)",
  "location": "Lahore, Pakistan (optional)",
  "location_lat": 24.8607,
  "location_lng": 67.0011,
  "additional_notes": "Patient needs blood urgently"
}
```

**Auto-Expiration:**
- Critical: 4 hours
- Urgent: 12 hours
- Normal: 48 hours

**Frontend:** `BloodRequestFormScreen`
- Interactive map for location selection
- Blood type dropdown
- Units counter (1-50)
- Urgency selector (Critical/Urgent/Normal)

### 3. Viewing Blood Requests

**Endpoints:**
- `GET /api/blood-requests/my-requests/` - Patient's own requests
- `GET /api/blood-requests/{id}/` - Request details
- `GET /api/blood-requests/{id}/progress/` - Progress tracking

**Response Structure:**
```json
{
  "id": "uuid",
  "patient_name": "John Doe",
  "blood_group": "A+",
  "units_needed": 2,
  "units_pledged": 1,
  "units_received": 0,
  "responders_count": 1,
  "urgency_level": "urgent",
  "status": "pending|partial|fulfilled|cancelled",
  "is_active": true,
  "created_at": "2024-01-15T10:30:00Z",
  "expires_at": "2024-01-15T22:30:00Z"
}
```

### 4. Viewing Pledged Donors

**Endpoint:** `GET /api/blood-requests/{request_id}/pledges/patient/`

**Donor Information Available:**
- Name, email (masked), phone (masked)
- Blood group, city, age
- Last donation date
- Pledge note
- Status (pledged, confirmed, etc.)

**Frontend:** Pledge cards in request detail screen

### 5. Managing Pledges

#### Accept Pledge (Confirm as Primary Donor)
**Endpoint:** `POST /api/blood-requests/{request_id}/pledges/{pledge_id}/accept/`

**Effects:**
1. Pledge status: `pledged` → `confirmed`
2. Sets `active_donor_pledge_id` on blood request
3. Creates chat conversation between patient and donor
4. Sends notification to donor
5. Returns `conversation_id`

#### Reject Pledge
**Endpoint:** `POST /api/blood-requests/{request_id}/pledges/{pledge_id}/reject/`

**Effects:**
1. Pledge status: `pledged` → `rejected`
2. Decreases `units_pledged` count
3. Sends generic notification to donor

#### Report No-Show
**Endpoint:** `POST /api/blood-requests/{request_id}/pledges/{pledge_id}/no-show/`

**Effects:**
1. Pledge status: → `no_show`
2. Decreases donor's reliability score (-20 points)
3. Clears `active_donor_pledge_id`
4. Activates next backup donor (if available)
5. Sends notification to donor

#### Confirm Donation Received
**Endpoint:** `POST /api/blood-requests/{request_id}/pledges/{pledge_id}/confirm-donation/`

**Request:**
```json
{
  "units_received": 1,
  "patient_note": "Thank you so much!"
}
```

**Effects:**
1. Pledge status: → `completed` (conceptually)
2. Increases `units_received` count
3. Updates blood request status (`partial` or `fulfilled`)
4. Sends thank you notification to donor
5. Creates donation record

### 6. Patient Home Screen

**Components:**
- **Header** - User profile, notification bell
- **Request Blood CTA** - Quick action to create request
- **Active Requests** - Horizontal scrolling cards
- **Recommended Donors** - Available donors nearby
- **Floating Map Button** - View nearby donors on map

---

## Donor Flow

### 1. Registration & Onboarding

```
Donor Registration
├── Sign Up (email, password, name)
├── Phone Verification (OTP)
├── Role Selection (Donor)
├── Profile Setup (REQUIRED)
│   ├── Blood Group
│   ├── Date of Birth (18-65 years)
│   ├── Gender
│   ├── Weight (min 50kg)
│   ├── Location (GPS coordinates)
│   ├── Address, City, Country
│   └── Medical Info (optional)
└── Health Eligibility Quiz (optional)
```

**Profile Validation:**
- Age: 18-65 years
- Weight: minimum 50kg
- Blood group: must be selected
- Location: required for nearby matching

### 2. Profile Management

**Endpoints:**
- `GET /api/auth/profile/detail/` - Get full profile
- `PUT /api/auth/profile/update/` - Update profile
- `PATCH /api/profile/update-medical/` - Update medical info

**Profile Fields:**
```python
class UserProfile:
    blood_group: A+, A-, B+, B-, AB+, AB-, O+, O-
    date_of_birth: DateField (18-65)
    gender: male, female, other, prefer_not_to_say
    weight: DecimalField (min 50kg)
    location_lat: DecimalField (required for matching)
    location_lng: DecimalField (required for matching)
    city, state, country: CharField
    is_available_for_donation: Boolean (default True)
    last_donation_date: DateField
    total_donations: Integer (default 0)
    
    # Reliability Score (0-100)
    reliability_score: 100 (base)
    is_verified_donor: Boolean
    is_top_donor: Boolean (score >= 90)
    is_reliable: Boolean (score >= 75)
    
    # Medical
    medications: JSONField (list)
    allergies: JSONField (list)
    health_conditions: JSONField (list)
    is_eligible: Boolean (computed from last_donation_date)
    eligibility_reason: TextField
```

### 3. Viewing Blood Requests

**Endpoint:** `GET /api/blood-requests/nearby/`

**Query Parameters:**
- `lat` - Donor's latitude (uses profile if not provided)
- `lng` - Donor's longitude (uses profile if not provided)
- `radius` - Search radius in km (default: 50)
- `blood_type` - Optional blood type filter

**Blood Compatibility:**
- If donor's blood group is known, shows compatible requests
- O- can donate to all
- O+ can donate to A+, B+, AB+, O+
- A- can donate to A+, A-, AB+, AB-
- etc.

**Response:**
```json
{
  "requests": [
    {
      "id": "uuid",
      "patient_name": "John Doe",
      "blood_group": "A+",
      "units_needed": 2,
      "units_pledged": 0,
      "urgency_level": "urgent",
      "hospital_name": "City Hospital",
      "location": "Lahore, Pakistan",
      "distance_km": 5.2,
      "created_at": "2024-01-15T10:30:00Z",
      "expires_at": "2024-01-15T22:30:00Z",
      "expires_soon": false
    }
  ],
  "count": 7
}
```

**Note:** Requests that already have a pledged donor are automatically filtered out from the nearby requests list (one donor per request policy).

### 4. Pledging to Donate

**Endpoint:** `POST /api/blood-requests/{request_id}/pledge/`

**Request:**
```json
{
  "units_pledged": 1,
  "preferred_date": "2024-06-08",
  "note": "I can donate in the morning"
}
```

**Eligibility Check:**
- Must not have donated in last 56 days (8 weeks)
- Cooldown period enforced at backend
- Request must not already have a pledged donor (one donor per request policy)

**Effects:**
1. Creates `DonorResponse` with status `pledged`
2. Increases `units_pledged` on blood request
3. Increases `responders_count`
4. Sends notification to patient
5. Returns pledge details
6. Request is hidden from other donors' nearby requests list

### 5. Managing Pledges

**Endpoint:** `GET /api/blood-requests/my-pledges/`

**Summary Stats:**
```json
{
  "pledges": [...],
  "summary": {
    "total": 5,
    "pending": 2,
    "accepted": 1,
    "rejected": 1,
    "donated": 1,
    "cancelled": 0
  }
}
```

#### Pledge Status Flow for Donor

```
pledged (initial)
    ↓ (patient accepts)
confirmed (chat opens)
    ↓ (donor updates)
on_the_way → arrived → ready
    ↓ (patient confirms)
completed (donation recorded)
```

**Cancel Pledge:**
- Only allowed if status is `pledged` or `shortlisted`
- Cannot cancel after `confirmed`

### 6. Donation Status Tracking

**Endpoint:** `POST /api/blood-requests/pledges/{pledge_id}/status/`

**Status Progression:**
```json
{
  "status": "on_the_way|arrived|ready"
}
```

**Valid Transitions:**
- `confirmed` → `on_the_way`
- `on_the_way` → `arrived`
- `arrived` → `ready`
- `ready` → (patient confirms donation)

**Effects:**
1. Updates pledge status
2. Sets timestamp for the status
3. Sends notification to patient
4. Updates patient's real-time view

### 7. My Donations (History)

**Endpoint:** `GET /api/donations/my-donations/`

**Response:**
```json
{
  "donations": [
    {
      "id": "uuid",
      "blood_type": "A+",
      "units": 1,
      "donation_date": "2024-01-15",
      "donation_center": "City Hospital",
      "certificate_number": "DN-2024-ABC123",
      "certificate_issued": true
    }
  ]
}
```

### 8. Donation Certificate

**Frontend:** `DonationCertificateScreen`

**Features:**
- Shows donation details
- Certificate number
- QR code (if available)
- Download/share options

---

## Data Models

### BloodRequest Model
```python
class BloodRequest:
    id: UUID (primary key)
    patient_name: CharField
    blood_group: CharField (A+, A-, B+, B-, AB+, AB-, O+, O-)
    units_needed: PositiveIntegerField
    units_pledged: PositiveIntegerField (default 0)
    units_received: PositiveIntegerField (default 0)
    responders_count: PositiveIntegerField (default 0)
    
    urgency_level: CharField (critical, urgent, normal)
    contact_number: CharField
    hospital_name: CharField (optional)
    location: CharField (optional)
    location_lat: DecimalField (optional)
    location_lng: DecimalField (optional)
    additional_notes: TextField (optional)
    
    expires_at: DateTimeField (auto-calculated)
    status: CharField (pending, partial, fulfilled, cancelled, expired)
    is_active: BooleanField (default True)
    
    active_donor_pledge_id: UUID (currently confirmed donor)
    requested_by: ForeignKey (CustomUser)
    
    created_at: DateTimeField
    updated_at: DateTimeField
```

### DonorResponse (Pledge) Model
```python
class DonorResponse:
    id: UUID (primary key)
    blood_request: ForeignKey (BloodRequest)
    donor: ForeignKey (CustomUser)
    
    units_pledged: PositiveIntegerField (default 1)
    units_received: PositiveIntegerField (default 0)
    preferred_date: DateField (optional)
    note: TextField (optional)
    
    # Status Flow
    status: CharField (
        pledged,          # Initial
        shortlisted,      # Patient reviewing
        confirmed,        # Patient selected (PRIMARY)
        on_the_way,      # Donor traveling
        arrived,          # Donor at location
        ready,            # Donor ready
        completed,        # Donation successful
        cancelled,        # Donor cancelled
        rejected,         # Patient rejected
        no_show          # Donor didn't arrive
    )
    
    # Patient decision fields
    accepted_at: DateTimeField
    rejected_at: DateTimeField
    rejection_reason: TextField
    patient_note: TextField
    
    # Verification fields
    verified_at: DateTimeField
    is_verified: Boolean
    verified_availability: Boolean
    verified_eligibility: Boolean
    verified_last_donation: Boolean
    verified_health_questionnaire: Boolean
    
    # Status timestamps
    confirmed_at: DateTimeField
    on_the_way_at: DateTimeField
    arrived_at: DateTimeField
    ready_at: DateTimeField
    completed_at: DateTimeField
    no_show_reported_at: DateTimeField
    
    created_at: DateTimeField
    updated_at: DateTimeField
```

### Donation Model
```python
class Donation:
    id: UUID (primary key)
    donor: ForeignKey (CustomUser)
    blood_request: ForeignKey (BloodRequest)
    blood_type: ForeignKey (BloodType)
    
    units: PositiveIntegerField (default 1)
    donation_date: DateField
    donation_center: CharField
    donation_center_address: TextField
    
    # Health Data
    hemoglobin_level: FloatField
    blood_pressure: CharField
    health_status: CharField
    notes: TextField
    
    # Certificate
    certificate_number: CharField (unique)
    certificate_issued: Boolean
    
    # Acknowledgment
    acknowledged_by_patient: Boolean
    acknowledged_at: DateTimeField
    
    created_at: DateTimeField
    updated_at: DateTimeField
```

### Notification Model
```python
class Notification:
    id: UUID (primary key)
    user: ForeignKey (CustomUser)
    title: CharField
    message: TextField
    type: CharField (
        pledge,                # New pledge
        pledge_confirmed,      # Patient confirmed pledge
        pledge_rejected,       # Patient rejected pledge
        donation_status_update,# Status update
        donation_confirmed,    # Donation received
        no_show_reported       # No-show reported
    )
    
    related_request_id: UUID
    related_pledge_id: UUID
    related_conversation_id: UUID
    
    is_read: Boolean (default False)
    created_at: DateTimeField
```

---

## API Endpoints

### Authentication Endpoints
```
POST   /api/auth/register/                 # Register new user
POST   /api/auth/login/                    # Login
POST   /api/auth/logout/                   # Logout
GET    /api/auth/profile/                  # Get user profile
PATCH  /api/auth/profile/update/           # Update profile
POST   /api/auth/profile/create/           # Create profile
DELETE /api/auth/profile/delete/           # Delete profile
PATCH  /api/auth/profile/update-role/      # Switch role (donor/patient)
GET    /api/auth/profile/role/             # Get current role
POST   /api/auth/change-password/          # Change password
POST   /api/auth/forgot-password/          # Request reset
POST   /api/auth/reset-password/           # Reset with token
```

### Blood Request Endpoints
```
GET    /api/blood-requests/                    # List all active requests
POST   /api/blood-requests/create/             # Create request
GET    /api/blood-requests/{id}/               # Get request details
PATCH  /api/blood-requests/{id}/update/        # Update request
DELETE /api/blood-requests/{id}/delete/        # Delete request
GET    /api/blood-requests/my-requests/        # Get current user's requests
POST   /api/blood-requests/{id}/cancel/       # Cancel request
GET    /api/blood-requests/nearby/             # Get nearby requests
GET    /api/blood-requests/{id}/progress/      # Get progress/pledges
```

### Pledge Endpoints
```
POST   /api/blood-requests/{request_id}/pledge/                    # Create pledge
GET    /api/blood-requests/{request_id}/pledges/                   # Get pledges
POST   /api/blood-requests/pledges/{pledge_id}/cancel/             # Cancel pledge
GET    /api/blood-requests/my-pledges/                             # Get my pledges
GET    /api/blood-requests/donor-eligibility/                     # Check eligibility
```

### Patient Pledge Management
```
GET    /api/blood-requests/{request_id}/pledges/patient/           # Get pledged donors
POST   /api/blood-requests/{request_id}/pledges/{pledge_id}/accept/      # Accept pledge
POST   /api/blood-requests/{request_id}/pledges/{pledge_id}/reject/      # Reject pledge
POST   /api/blood-requests/{request_id}/pledges/{pledge_id}/no-show/     # Report no-show
POST   /api/blood-requests/{request_id}/pledges/{pledge_id}/confirm-donation/  # Confirm donation
```

### Donation Status Tracking
```
POST   /api/blood-requests/pledges/{pledge_id}/status/            # Update status
POST   /api/blood-requests/pledges/{pledge_id}/verify/            # Verify eligibility
```

### Donor Endpoints
```
GET    /api/donor/profile/toggle-availability/     # Toggle available status
PATCH  /api/donor/profile/location/                # Update location
GET    /api/donor/nearby/                          # Get nearby donors
GET    /api/donor/profile/{id}/                     # Get donor profile
```

### Donation Endpoints
```
GET    /api/donations/my-donations/                 # Get donation history
POST   /api/donations/record/                       # Record donation
GET    /api/donations/certificate/{id}/            # Get certificate
```

---

## Status Flow Diagrams

### Blood Request Status Flow
```
[Patient creates request]
           ↓
       pending (initial)
           ↓
    [Donors pledge]
           ↓
    partial (some received)
           ↓
    fulfilled (all received)
           ↓
    [Auto-expire if not complete]
           ↓
       expired
```

### Pledge Status Flow
```
[Donor pledges]
     ↓
  pledged
     ↓
[Patient reviews]
     ↓           ↓
confirmed   rejected/cancelled
     ↓
on_the_way
     ↓
  arrived
     ↓
   ready
     ↓
[Patient confirms]
     ↓
completed
```

### No-Show Flow
```
confirmed → [Donor doesn't show] → no_show
                                        ↓
                            [Decrease reliability score]
                                        ↓
                            [Activate backup donor]
```

---

## Frontend Screens Mapping

### Patient Screens
| Screen | File | Purpose |
|--------|------|---------|
| Patient Home | `patient_home_screen.dart` | Main dashboard |
| Blood Request Form | `blood_request_form_screen.dart` | Create request |
| My Requests | `my_requests_screen.dart` | View requests |
| Request Detail | `blood_request_detail_screen.dart` | View request & pledges |
| Nearby Donors Map | `nearby_donors_map_screen.dart` | Map view |

### Donor Screens
| Screen | File | Purpose |
|--------|------|---------|
| Donor Home | `home_screen.dart` | Main dashboard |
| Nearby Requests | `nearby_requests_screen.dart` | View requests |
| My Pledges | `my_pledges_screen.dart` | Track pledges |
| Donations | `my_donations_screen.dart` | Donation history |
| Certificate | `donation_certificate_screen.dart` | View certificate |

### Shared Screens
| Screen | File | Purpose |
|--------|------|---------|
| Profile | `profile_screen.dart` | View/edit profile |
| Settings | `settings_screen.dart` | App settings |
| Messages | `messages_screen.dart` | Chat list |
| Notifications | `notifications_screen.dart` | View notifications |
| Role Switch | `role_switch_screen.dart` | Switch donor/patient |

---

## Notifications System

### Notification Types
1. **pledge** - New pledge received
2. **pledge_confirmed** - Pledge confirmed by patient
3. **pledge_rejected** - Pledge rejected by patient
4. **donation_status_update** - Donor status updated
5. **donation_confirmed** - Donation received
6. **no_show_reported** - No-show reported

### Notification Structure
```json
{
  "id": "uuid",
  "title": "New Blood Pledge!",
  "message": "John Doe has pledged to donate...",
  "type": "pledge",
  "related_request_id": "uuid",
  "related_pledge_id": "uuid",
  "related_conversation_id": "uuid",
  "is_read": false,
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

## GPS & Distance Calculation

### Haversine Formula
The system uses the Haversine formula to calculate distances between donor and patient locations:

```python
def haversine_distance(lat1, lng1, lat2, lng2):
    # Returns distance in kilometers
    # Earth radius = 6371 km
```

### Location Requirements
- **Patient**: Required for creating request (map picker)
- **Donor**: Required for nearby matching (profile setting)

### Search Radius
- Default: 50 km
- Configurable via API parameter
- Maximum: 500 km (backend limit)

---

## Reliability Scoring System

### Score Calculation
```python
base_score = 100
score += on_time_arrivals * 10
score += late_arrivals * 3
score -= cancelled_pledges * 10
score -= no_shows * 20

final_score = max(0, min(100, score))
```

### Badges
- **Top Donor**: score >= 90
- **Reliable**: score >= 75
- **Verified**: Identity verified

### Penalties
- No-show: -20 points
- Cancellation: -10 points
- Late arrival: No penalty (still +3 points)

---

## Security & Privacy

### Phone Number Privacy
- Full number shown only to matched donors/patients
- Masked in public listings
- OTP verification required

### Location Privacy
- GPS coordinates stored securely
- Used only for distance calculation
- Can be updated by user

### Medical Information
- Only visible to confirmed donor
- Health questionnaire data encrypted
- Used for eligibility checks only

---

## Error Handling

### Common Error Codes
- **400**: Invalid input, validation failed
- **401**: Authentication required
- **403**: Not authorized (wrong user, etc.)
- **404**: Resource not found
- **409**: Conflict (already pledged, etc.)
- **429**: Too many requests (OTP cooldown)

### Standard Error Response
```json
{
  "success": false,
  "message": "Error message",
  "errors": {
    "field_name": ["Error details"]
  }
}
```

---

## Future Enhancements

1. **Blood Bank Integration**
   - Connect with registered blood banks
   - Show blood availability in banks

2. **Emergency SOS**
   - One-tap emergency requests
   - Broadcast to all nearby donors

3. **Donation Camps**
   - Organize community donation drives
   - Track camp donations

4. **AI Matching**
   - Smart donor-patient matching
   - Consider availability, reliability score

5. **Multi-language Support**
   - Urdu language option
   - Regional language support

---

*Document generated on: 2026-06-12*
*For: Blood Donation App - Django Backend + Flutter Frontend*
