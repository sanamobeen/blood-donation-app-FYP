# Blood Donation Flow - Implementation Plan

## Overview
Change the blood donation flow from **auto-fulfillment** to **patient-controlled donor selection**.

### Current Flow
1. Patient creates blood request
2. Donors pledge to donate
3. System auto-fulfills when enough pledges received
4. Donors proceed to donation

### New Flow
1. Patient creates blood request
2. Donors pledge to donate (pledge status: `pending`)
3. Patient sees list of pledged donors with details
4. Patient reviews and **accepts/rejects** specific donors
5. Accepted donors (`accepted` status) proceed to donation
6. Patient can mark donation as `completed` when received

---

## Database Changes

### 1. DonorResponse Model Updates
**File**: `blood_requests/models.py`

Add new pledge statuses:
```python
STATUS_CHOICES = [
    ('pending', 'Pending'),       # Initial pledge status
    ('accepted', 'Accepted'),      # Accepted by patient
    ('rejected', 'Rejected'),       # Rejected by patient
    ('donated', 'Donated'),        # Successfully donated
    ('cancelled', 'Cancelled'),    # Cancelled by donor
]
```

Add new fields:
```python
# Existing pledges keep these, add new:
accepted_at = models.DateTimeField(null=True, blank=True)
rejected_at = models.DateTimeField(null=True, blank=True)
rejection_reason = models.TextField(null=True, blank=True)
```

### 2. Migration Required
Create migration: `0010_update_pledge_statuses.py`

---

## Backend API Changes

### 1. Patient Endpoints (New/Modified)

**File**: `blood_requests/views.py`

#### a) Get Pledged Donors List (NEW)
```
GET /api/blood-requests/{request_id}/pledges/
```
Response includes:
- Donor details (name, blood group, location, last donation date)
- Pledge info (units, preferred date, note)
- Match score (how well they match requirements)

```python
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_request_pledges_for_patient(request, request_id):
    """Get pledged donors with full details for patient review"""
    # Verify user is the request creator
    # Return enhanced donor information
```

#### b) Accept/Reject Pledge (NEW)
```
POST /api/blood-requests/{request_id}/pledges/{pledge_id}/accept/
POST /api/blood-requests/{request_id}/pledges/{pledge_id}/reject/
```

Request body for reject:
```json
{
  "reason": "Optional rejection reason"
}
```

#### c) Accept Multiple Pledges (NEW)
```
POST /api/blood-requests/{request_id}/pledges/accept-batch/
```

Request body:
```json
{
  "pledge_ids": ["uuid1", "uuid2", "uuid3"]
}
```

#### d) Mark Donation Complete (NEW)
```
POST /api/blood-requests/{request_id}/pledges/{pledge_id}/confirm-donation/
```

Request body:
```json
{
  "units_received": 1
}
```

### 2. Donor Endpoints (Modified)

#### a) Get My Pledges (Enhanced)
```
GET /api/blood-requests/my-pledges/
```
Add new response fields:
- `status`: pending, accepted, rejected, donated, cancelled
- `accepted_at`: timestamp when accepted
- `patient_note`: note from patient

#### b) Cancel Pledge (Enhanced)
```
POST /api/blood-requests/pledges/{pledge_id}/cancel/
```
Restrictions:
- Can only cancel if status is `pending`
- Cannot cancel if `accepted`

### 3. URL Updates
**File**: `blood_requests/urls.py`

Add new routes:
```python
path('<uuid:request_id>/pledges/patient/', views.get_request_pledges_for_patient),
path('<uuid:request_id>/pledges/<uuid:pledge_id>/accept/', views.accept_pledge),
path('<uuid:request_id>/pledges/<uuid:pledge_id>/reject/', views.reject_pledge),
path('<uuid:request_id>/pledges/accept-batch/', views.accept_pledges_batch),
path('<uuid:request_id>/pledges/<uuid:pledge_id>/confirm-donation/', views.confirm_donation),
```

---

## Frontend Changes

### 1. Patient Views

#### a) Blood Request Detail Screen
**File**: `lib/src/screens/requests/blood_request_detail_screen.dart`

Add new section:
```dart
// Pledged Donors Management Section (for patients)
if (_isRequestCreator() && _pledges.isNotEmpty) ...[
  _buildPledgedDonorsManagementSection(),
],
```

Features:
- List of all pledged donors with expandable cards
- Donor match score/badge
- Accept/Reject buttons for each donor
- Batch accept option
- Filter by status (pending, accepted, rejected)

#### b) Pledged Donors Management Screen (NEW)
**File**: `lib/src/screens/patient/patient_donors_management_screen.dart`

Dedicated screen for managing pledged donors with:
- Full donor list with filters
- Sort by match score, distance, availability
- Bulk accept/reject
- Communication (chat) integration
- Donation tracking

#### c) Donor Accept/Reject Dialog
**File**: `lib/src/widgets/donor_response_dialog.dart`

Dialog for patient to:
- View donor full details
- Write acceptance note
- Write rejection reason (optional)

### 2. Donor Views

#### a) My Pledges Screen
**File**: `lib/src/screens/donor/my_pledges_screen.dart`

Enhanced to show:
- Pledge status with badges
- Pending pledges (waiting for patient acceptance)
- Accepted pledges (proceed to donate)
- Rejected pledges with reason
- Donation history

#### b) Pledge Status Indicator
Update pledge cards to show status:
- 🔵 Pending: Waiting for patient approval
- 🟢 Accepted: Proceed to donate
- 🔴 Rejected: Not selected
- ✅ Donated: Successfully donated

### 3. API Service Updates

**File**: `lib/src/services/api_service.dart`

Add new methods:
```dart
// Patient methods
static Future<dynamic> getPledgedDonorsForPatient(String requestId)
static Future<dynamic> acceptPledge(String requestId, String pledgeId)
static Future<dynamic> rejectPledge(String requestId, String pledgeId, {String? reason})
static Future<dynamic> acceptPledgesBatch(String requestId, List<String> pledgeIds)
static Future<dynamic> confirmDonation(String requestId, String pledgeId, int unitsReceived)

// Donor methods
static Future<dynamic> getMyPledges()
```

---

## Notification System

### 1. Notifications to Send

#### When Donor Pledges:
- **Patient**: "New pledge from [Donor Name] for [Blood Group] blood"

#### When Patient Accepts:
- **Donor**: "Your pledge has been accepted! Please contact the patient to arrange donation"

#### When Patient Rejects:
- **Donor**: "Your pledge was not selected. Thank you for your willingness to help"

#### When Donation Confirmed:
- **Donor**: "Thank you for donating! Your contribution has saved lives"

### 2. Notification Types
```python
'pledge_received'     # Patient receives new pledge
'pledge_accepted'    # Donor's pledge accepted
'pledge_rejected'     # Donor's pledge rejected
'donation_confirmed'  # Donation completed
```

---

## Blood Request Status Updates

### Request Status Flow

The blood request status should update based on accepted donations:

```
pending → partial → fulfilled → completed
```

**Rules**:
- `pending`: No donations received yet
- `partial`: Some units received, but still need more
- `fulfilled`: All required units received
- `completed`: Patient confirms completion

### Auto-update Logic

When patient confirms donation:
```python
blood_request.units_received += units_received

if blood_request.units_received >= blood_request.units_needed:
    blood_request.status = 'fulfilled'
elif blood_request.units_received > 0:
    blood_request.status = 'partial'
```

---

## Use Cases Covered

### UC1: Patient Creates Request
1. Patient fills blood request form
2. Request created with status `pending`
3. Notifications sent to matching donors

### UC2: Donor Views Request
1. Donor sees request in feed
2. Views details
3. Can pledge if eligible (no existing pledge, within cooldown)

### UC3: Donor Submits Pledge
1. Donor opens pledge dialog
2. Enters units, preferred date, note
3. Pledge created with status `pending`
4. Patient notified

### UC4: Patient Reviews Pledges
1. Patient opens their blood request
2. Sees list of pledged donors
3. Views donor details (blood group, location, availability)
4. Sees match score for each donor

### UC5: Patient Accepts Donor
1. Patient selects donor(s) to accept
2. Optionally adds note
3. Pledge status changes to `accepted`
4. Donor notified
5. Request may update to `partial` if enough units

### UC6: Patient Rejects Donor
1. Patient selects donor to reject
2. Optionally provides reason
3. Pledge status changes to `rejected`
4. Donor notified (reason not shared)

### UC7: Patient Batch Accept
1. Patient selects multiple donors
2. Accepts all at once
3. All pledges updated to `accepted`
4. All donors notified

### UC8: Donor Checks Status
1. Donor opens "My Pledges"
2. Sees status of each pledge
3. Proceeds to contact patient if accepted

### UC9: Donor & Patient Coordinate
1. Donor messages patient via chat
2. They arrange donation time/location
3. Patient updates pledge with details

### UC10: Donation Completed
1. Donor completes donation
2. Patient confirms donation received
3. Pledge status → `donated`
4. Units received updated
5. Request status updates
6. Donor receives thank you notification

### UC11: Donor Cancels Pledge
1. Donor cancels before acceptance
2. Pledge status → `cancelled`
3. Patient notified
4. Request progress updated

### UC12: Patient Cancels Request
1. Patient cancels entire request
2. All `pending` pledges → `cancelled`
3. All donors notified

### UC13: Auto-Rematch
1. If donor cancels after acceptance
2. Patient sees updated list
3. Can accept additional donors

### UC14: Partial Fulfillment
1. Patient accepts some donors
2. Some donors donate
3. Still need more units
4. Request remains `partial`
5. Patient can accept more donors

### UC15: Over-Pledging Handling
1. More donors pledge than needed
2. Patient only accepts needed amount
3. Extra pledges remain `pending`
4. Patient can reject or keep as backup

---

## UI/UX Considerations

### 1. Patient Dashboard
- Clear indication of pledges waiting for review
- Quick accept/reject actions
- Visual progress indicator

### 2. Donor Dashboard
- Clear status indicators for pledges
- Easy access to contact patient
- Notification when accepted

### 3. Chat Integration
- Auto-create chat when pledge accepted
- Pre-filled context (request details)
- Easy to arrange donation

### 4. Mobile Responsiveness
- Swipe actions for accept/reject
- Bottom sheets for donor details
- Quick actions menu

---

## Testing Checklist

### Backend Testing
- [ ] Pledge creation works
- [ ] Patient can fetch pledged donors
- [ ] Patient can accept/reject pledges
- [ ] Batch accept works
- [ ] Donation confirmation updates request
- [ ] Status transitions work correctly
- [ ] Notifications are sent
- [ ] Permissions are enforced

### Frontend Testing
- [ ] Patient sees pledged donors list
- [ ] Patient can accept/reject donors
- [ ] Donor sees pledge status updates
- [ ] My Pledges screen shows correct info
- [ ] Chat opens after acceptance
- [ ] Progress indicators update
- [ ] Notifications display correctly

### Edge Cases
- [ ] Donor cancels after acceptance
- [ ] Patient rejects all pledges
- [ ] Multiple patients, multiple donors
- [ ] Request fulfilled, new donor pledges
- [ ] Network errors during accept/reject

---

## Implementation Priority

### Phase 1: Core Flow (Must Have)
1. ✅ Database migration (pledge statuses)
2. ✅ Backend API (accept/reject endpoints)
3. ✅ Patient UI (pledged donors list)
4. ✅ Donor UI (pledge status display)
5. ✅ Basic notifications

### Phase 2: Enhanced Features (Should Have)
1. Batch accept functionality
2. Donation confirmation flow
3. Enhanced donor profiles
4. Chat integration
5. Detailed notifications

### Phase 3: Advanced Features (Nice to Have)
1. Match scoring algorithm
2. Auto-rematch system
3. Analytics dashboard
4. Reminder system
5. Feedback system

---

## API Endpoints Summary

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/blood-requests/{id}/pledges/` | Get pledged donors for patient | Patient only |
| POST | `/api/blood-requests/{id}/pledges/{pid}/accept/` | Accept donor pledge | Patient only |
| POST | `/api/blood-requests/{id}/pledges/{pid}/reject/` | Reject donor pledge | Patient only |
| POST | `/api/blood-requests/{id}/pledges/accept-batch/` | Accept multiple pledges | Patient only |
| POST | `/api/blood-requests/{id}/pledges/{pid}/confirm-donation/` | Confirm donation | Patient only |
| GET | `/api/blood-requests/my-pledges/` | Get donor's pledges | Donor only |
| POST | `/api/blood-requests/pledges/{pid}/cancel/` | Cancel pledge | Donor only |

---

## Database Schema Changes

### DonorResponse Model
```python
class DonorResponse(models.Model):
    # ... existing fields ...
    
    # New fields
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
        ('donated', 'Donated'),
        ('cancelled', 'Cancelled'),
    ]
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )
    
    accepted_at = models.DateTimeField(null=True, blank=True)
    rejected_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(null=True, blank=True)
```

---

## Security Considerations

1. **Authorization**: Only request creator can accept/reject pledges
2. **Privacy**: Donor info only shared after acceptance
3. **Rate Limiting**: Prevent spam pledging
4. **Data Validation**: Ensure status transitions are valid

---

## Performance Considerations

1. **Caching**: Cache pledged donors list for patient
2. **Pagination**: Paginate donor lists for large requests
3. **Background Tasks**: Send notifications asynchronously
4. **Database Indexing**: Index status, blood_request, donor fields

---

This plan provides a comprehensive roadmap for implementing the patient-controlled donor selection flow while maintaining backward compatibility and covering all edge cases.
