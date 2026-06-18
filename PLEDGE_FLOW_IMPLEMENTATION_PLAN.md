# Blood Donation Pledge Flow - Implementation Plan

## Problem Statement
Current implementation restricts blood requests to ONE donor only, which is incorrect. Multiple donors should be able to pledge to the same request, and the patient should be able to:
1. See list of all donors who pledged
2. Accept/reject pledges
3. Mark donations as complete when received
4. Have proper donation records created

## Current (Incorrect) Flow
```
1. Patient creates blood request
2. ONLY ONE donor can pledge ❌
3. Other donors see "already has donor pledged" error ❌
```

## Desired (Correct) Flow
```
1. Patient creates blood request
2. MULTIPLE donors can pledge ✓
3. Patient sees list of all pledges
4. For each pledge:
   - Patient can click "Complete/Confirm Donation" button
   - This creates a donation record
   - Updates pledge status to 'donated'
5. Blood request marked as fulfilled when all units received
```

---

## Implementation Plan

### Phase 1: Backend Fixes (Django)

#### 1.1 Remove One-Donor Restriction from Nearby Requests
**File:** `django-backend/blood_requests/views.py`
**Function:** `nearby_blood_requests()`

**Current Code (Lines 537-547):**
```python
# Get all active pending requests that don't have any pledges yet
# (one donor per request policy) ❌ REMOVE THIS
pledged_request_ids = DonorResponse.objects.filter(
    status='pledged'
).values_list('blood_request_id', flat=True)

queryset = BloodRequest.objects.filter(
    is_active=True,
    status='pending',
    expires_at__gt=timezone.now()
).exclude(id__in=pledged_request_ids)  # ❌ REMOVE THIS EXCLUDE
```

**Fix:**
```python
# Get all active pending requests (multiple donors can pledge)
queryset = BloodRequest.objects.filter(
    is_active=True,
    status='pending',
    expires_at__gt=timezone.now()
)
# Remove the pledged_request_ids exclude logic
```

#### 1.2 Remove One-Donor Restriction from Create Pledge
**File:** `django-backend/blood_requests/views.py`
**Function:** `create_pledge()`

**Current Code (Lines 670-680):**
```python
# Check if ANY donor has already pledged to this request (one donor per request) ❌
existing_pledge = DonorResponse.objects.filter(
    blood_request=blood_request,
    status='pledged'
).first()

if existing_pledge:
    return error_response(
        message='This blood request already has a donor pledged...',
        status_code=status.HTTP_400_BAD_REQUEST
    )
```

**Fix:**
```python
# Only check if THIS user has already pledged (keep this)
user_existing_pledge = DonorResponse.objects.filter(
    blood_request=blood_request,
    donor=request.user,
    status='pledged'
).first()

if user_existing_pledge:
    return error_response(
        message='You have already pledged to this request.',
        status_code=status.HTTP_400_BAD_REQUEST
    )
# Remove the existing_pledge check for ANY donor
```

#### 1.3 Update Confirm Donation to Create Donation Record
**File:** `django-backend/blood_requests/views.py`
**Function:** `confirm_donation()`

**Current Issue:**
- Only updates pledge status to 'donated'
- Does NOT create a Donation record

**Fix:**
Add donation record creation after line 1704:
```python
# Update pledge
pledge.status = 'donated'
pledge.donated_at = timezone.now()
pledge.units_received = units_received
if patient_note:
    pledge.patient_note = patient_note
pledge.save()

# ✅ NEW: Create donation record
from donations.models import Donation
from blood_types.models import BloodType

# Get or find blood type
try:
    blood_type = BloodType.objects.filter(
        blood_group=blood_request.blood_group
    ).first()
except:
    blood_type = None

# Create donation record
donation = Donation.objects.create(
    donor=pledge.donor,
    blood_request=blood_request,
    blood_type=blood_type,
    units=units_received,
    donation_date=timezone.now().date(),
    donation_center=blood_request.hospital_name or 'Hospital',
    donation_center_address=blood_request.location or '',
    acknowledged_by_patient=True,
    acknowledged_at=timezone.now(),
)

logger.info(f"Donation record created: {donation.id} for pledge {pledge.id}")

# Generate certificate number
try:
    donation.generate_certificate_number()
    donation.certificate_issued = True
    donation.save()
except:
    pass
```

#### 1.4 Remove Status Requirement for Confirm Donation
**File:** `django-backend/blood_requests/views.py`
**Function:** `confirm_donation()`

**Current Issue (Line 1674):**
```python
# Check if pledge can be marked as donated
if pledge.status != 'accepted':  # ❌ This blocks direct donation confirmation
    return error_response(...)
```

**Fix:**
```python
# Check if pledge can be marked as donated
# Allow 'pledged' or 'accepted' status
if pledge.status not in ['pledged', 'accepted']:
    return error_response(
        message=f'Cannot confirm donation for pledge with status "{pledge.status}".',
        status_code=status.HTTP_400_BAD_REQUEST
    )
```

#### 1.5 Add New API Endpoint: Confirm Direct Donation
**File:** `django-backend/blood_requests/views.py`

Add a new simplified endpoint for confirming donations:
```python
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def complete_pledge_donation(request, request_id, pledge_id):
    """
    Complete donation from a pledge (patient only).

    POST /api/blood-requests/{request_id}/pledges/{pledge_id}/complete/

    This is a simplified endpoint that:
    1. Marks pledge as 'donated'
    2. Creates donation record
    3. Updates blood request progress
    4. Generates certificate

    Request Body:
    {
        "units_donated": 1
    }
    """
    # Implementation similar to confirm_donation but without 'accepted' requirement
```

**File:** `django-backend/blood_requests/urls.py`

Add the URL:
```python
path('<uuid:request_id>/pledges/<uuid:pledge_id>/complete/',
     views.complete_pledge_donation,
     name='complete-pledge-donation'),
```

---

### Phase 2: Flutter UI Updates

#### 2.1 Update Patient Pledge List Screen
**File:** `flutter-project/flutter_app/lib/src/screens/patient_home/patient_home_screen.dart`

**Current Issue:**
- May not properly show all pledges
- May not have "Complete" button for each pledge

**Required Changes:**
1. Add "Complete Donation" button for each pledged donor
2. Show pledge status clearly (pledged, donated)
3. Add confirmation dialog before completing

```dart
Widget _buildPledgedDonorsCard() {
  return Card(
    child: Column(
      children: [
        Text('Donors who pledged'),
        ...pledges.map((pledge) => ListTile(
          title: Text(pledge.donorName),
          subtitle: Text('Pledged: ${pledge.unitsPledged} units'),
          trailing: pledge.status == 'pledged'
            ? ElevatedButton(
                onPressed: () => _showCompleteDonationDialog(pledge),
                child: Text('Complete'),
              )
            : Icon(Icons.check_circle, color: Colors.green),
        )),
      ],
    ),
  );
}

void _showCompleteDonationDialog(Pledge pledge) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Confirm Donation'),
      content: Text('Has ${pledge.donorName} donated ${pledge.unitsPledged} unit(s)?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            _completeDonation(pledge);
            Navigator.pop(context);
          },
          child: Text('Confirm'),
        ),
      ],
    ),
  );
}

Future<void> _completeDonation(Pledge pledge) async {
  final result = await ApiService.completePledgeDonation(
    requestId: widget.requestId,
    pledgeId: pledge.id,
    unitsDonated: pledge.unitsPledged,
  );

  if (result['success'] == true) {
    setState(() {
      // Reload pledges
      _loadPledges();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Donation completed successfully!')),
    );
  }
}
```

#### 2.2 Add API Service Method
**File:** `flutter-project/flutter_app/lib/src/services/api_service.dart`

```dart
/// Complete donation from a pledge (patient only)
static Future<Map<String, dynamic>> completePledgeDonation({
  required String requestId,
  required String pledgeId,
  required int unitsDonated,
}) async {
  try {
    print('✅ Completing donation for pledge: $pledgeId');

    final headers = await getAuthHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.bloodRequestsEndpoint}/$requestId/pledges/$pledgeId/complete/'),
      headers: headers,
      body: jsonEncode({'units_donated': unitsDonated}),
    );

    final data = jsonDecode(response.body);
    print('📊 Complete donation response: ${response.statusCode}');

    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Failed to complete donation'};
    }
  } catch (e) {
    print('❌ Error completing donation: $e');
    return {'success': false, 'message': 'Network error: $e'};
  }
}
```

#### 2.3 Update Donor Pledge Flow
**File:** `flutter-project/flutter_app/lib/src/screens/requests/nearby_requests_screen.dart`

**No changes needed** - donors should still be able to pledge even if other donors have pledged.

---

### Phase 3: Testing Strategy

#### 3.1 Backend Testing
```bash
# Test 1: Create blood request
curl -X POST http://localhost:8000/api/blood-requests/create/ \
  -H "Authorization: Bearer $PATIENT_TOKEN" \
  -d '{
    "patient_name": "Test Patient",
    "blood_group": "A+",
    "units_needed": 5,
    "urgency_level": "urgent",
    "contact_number": "+1234567890"
  }'

# Test 2: Multiple donors pledge
curl -X POST http://localhost:8000/api/blood-requests/{REQUEST_ID}/pledge/ \
  -H "Authorization: Bearer $DONOR1_TOKEN" \
  -d '{"units_pledged": 2}'

curl -X POST http://localhost:8000/api/blood-requests/{REQUEST_ID}/pledge/ \
  -H "Authorization: Bearer $DONOR2_TOKEN" \
  -d '{"units_pledged": 3}'

# Test 3: Patient sees all pledges
curl -X GET http://localhost:8000/api/blood-requests/{REQUEST_ID}/pledges/patient/ \
  -H "Authorization: Bearer $PATIENT_TOKEN"

# Test 4: Patient completes donation
curl -X POST http://localhost:8000/api/blood-requests/{REQUEST_ID}/pledges/{PLEDGE_ID}/complete/ \
  -H "Authorization: Bearer $PATIENT_TOKEN" \
  -d '{"units_donated": 2}'

# Test 5: Verify donation record created
curl -X GET http://localhost:8000/api/donations/my/ \
  -H "Authorization: Bearer $DONOR1_TOKEN"
```

#### 3.2 Flutter Testing
1. **Patient Flow:**
   - Create blood request for 3 units
   - Wait for multiple pledges
   - Verify all pledges shown
   - Complete each donation one by one
   - Verify donation records created

2. **Donor Flow:**
   - Browse nearby requests
   - Pledge to request even if others pledged
   - Verify no "already has donor" error
   - Check pledges in "My Pledges"

3. **Edge Cases:**
   - Same donor tries to pledge twice (should fail)
   - Patient tries to complete same donation twice
   - Request status updates correctly

---

### Phase 4: Database Migration (If Needed)

No migration needed - we're only changing logic, not schema.

---

### Phase 5: Deployment Checklist

- [ ] Backup production database
- [ ] Deploy backend changes
- [ ] Run tests on staging
- [ ] Deploy Flutter app update
- [ ] Monitor logs for errors
- [ ] Verify donation records being created
- [ ] Check certificate generation

---

## Summary of Changes

| File | Change | Reason |
|------|--------|--------|
| `blood_requests/views.py` | Remove one-donor restriction in `nearby_blood_requests` | Allow multiple donors to see requests |
| `blood_requests/views.py` | Remove one-donor restriction in `create_pledge` | Allow multiple donors to pledge |
| `blood_requests/views.py` | Add donation creation in `confirm_donation` | Create proper donation records |
| `blood_requests/views.py` | Add new `complete_pledge_donation` endpoint | Simplified completion flow |
| `blood_requests/urls.py` | Add URL for new endpoint | Expose new API |
| `api_service.dart` | Add `completePledgeDonation` method | Flutter API call |
| Patient UI screens | Add "Complete" button per pledge | Allow patient to confirm donations |

---

## Success Criteria

✅ Multiple donors can pledge to the same blood request
✅ Patient sees list of all pledges
✅ Each pledge has "Complete" button
✅ Clicking complete creates donation record
✅ Donation record has certificate number
✅ Blood request status updates correctly
✅ Donor sees their donation history

---

## Estimated Time

- Backend changes: 2 hours
- Flutter UI changes: 3 hours
- Testing: 2 hours
- **Total: ~7 hours**
