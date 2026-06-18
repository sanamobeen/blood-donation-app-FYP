# LifeDrop - API Endpoints Documentation

Complete RESTful API endpoints with database field mappings for the Blood Donation application.

**Base URL:** `http://your-domain.com/api`

**API Version:** v1

---

## 🔐 Authentication

All endpoints except public ones require JWT authentication:

```http
Authorization: Bearer <access_token>
```

---

## 📚 Response Format

### Success Response
```json
{
    "success": true,
    "message": "Operation successful",
    "data": { ... }
}
```

### Error Response
```json
{
    "success": false,
    "message": "Error description",
    "errors": { ... }
}
```

---

## 🌐 API Endpoints

---

## 1. Authentication Endpoints

**API Base Path:** `/api/auth/`
**Database Table:** `account_customuser`

### 1.1 Register User
```http
POST /api/auth/register/
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "email": "user@example.com",           // → CustomUser.email
    "password": "SecurePass123",            // → CustomUser.password (hashed)
    "password_confirm": "SecurePass123",    // Validation only, not stored
    "full_name": "John Doe",                // → CustomUser.full_name
    "phone_num": "+1234567890"             // → CustomUser.phone_num
}
```

**Response (201):**
```json
{
    "success": true,
    "message": "Registration successful",
    "data": {
        "user": {
            "id": "uuid",                  // ← CustomUser.id
            "email": "user@example.com",    // ← CustomUser.email
            "full_name": "John Doe",        // ← CustomUser.full_name
            "phone_num": "+1234567890",     // ← CustomUser.phone_num
            "phone_verified": false,        // ← CustomUser.phone_verified
            "date_joined": "2024-06-05T10:00:00Z" // ← CustomUser.date_joined
        },
        "tokens": {
            "access": "...",
            "refresh": "..."
        }
    }
}
```

**DB Fields Read:** None (new record)
**DB Fields Written:** email, password, full_name, phone_num, date_joined (auto)

---

### 1.2 Login
```http
POST /api/auth/login/
Content-Type: application/json
```

**Request Body (reads from DB):**
```json
{
    "email": "user@example.com",    // Checks CustomUser.email
    "password": "SecurePass123"     // Verifies against CustomUser.password
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Login successful",
    "data": {
        "user": {
            "id": "uuid",                      // ← CustomUser.id
            "email": "user@example.com",       // ← CustomUser.email
            "full_name": "John Doe",           // ← CustomUser.full_name
            "phone_num": "+1234567890",        // ← CustomUser.phone_num
            "phone_verified": false,           // ← CustomUser.phone_verified
            "date_joined": "2024-06-05T10:00:00Z" // ← CustomUser.date_joined
        },
        "tokens": { "access": "...", "refresh": "..." }
    }
}
```

**DB Fields Read:** email, password
**DB Fields Written:** last_login (auto-update)

---

### 1.3 Logout
```http
POST /api/auth/logout/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "refresh": "refresh_token"    // Blacklists refresh token
}
```

**DB Fields Read:** None
**DB Fields Written:** Token blacklist table

---

### 1.4 Refresh Token
```http
POST /api/auth/token/refresh/
Content-Type: application/json
```

**Request Body:**
```json
{
    "refresh": "refresh_token"    // Validates and issues new access token
}
```

**DB Fields Read:** Token blacklist table
**DB Fields Written:** Token blacklist table (if rotating)

---

### 1.5 Get Profile
```http
GET /api/auth/profile/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Profile retrieved successfully",
    "data": {
        "user": {
            "id": "uuid",                          // ← CustomUser.id
            "email": "user@example.com",           // ← CustomUser.email
            "full_name": "John Doe",               // ← CustomUser.full_name
            "phone_num": "+1234567890",           // ← CustomUser.phone_num
            "phone_verified": false,               // ← CustomUser.phone_verified
            "date_joined": "2024-06-05T10:00:00Z", // ← CustomUser.date_joined
            "last_login": "2024-06-05T11:00:00Z"  // ← CustomUser.last_login
        }
    }
}
```

**DB Fields Read:** id, email, full_name, phone_num, phone_verified, date_joined, last_login
**DB Fields Written:** None

---

### 1.6 Update Profile
```http
PATCH /api/auth/profile/update/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "full_name": "John Updated Doe",      // → CustomUser.full_name
    "phone_num": "+9876543210"            // → CustomUser.phone_num
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Profile updated successfully",
    "data": {
        "user": {
            "id": "uuid",
            "email": "user@example.com",
            "full_name": "John Updated Doe",
            "phone_num": "+9876543210",
            "phone_verified": false,
            "date_joined": "2024-06-05T10:00:00Z"
        }
    }
}
```

**DB Fields Read:** None
**DB Fields Written:** full_name, phone_num

---

### 1.7 Change Password
```http
POST /api/auth/change-password/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "old_password": "OldPass123",          // Verifies against CustomUser.password
    "new_password": "NewPass123",          // → CustomUser.password (hashed)
    "new_password_confirm": "NewPass123"   // Validation only
}
```

**DB Fields Read:** password
**DB Fields Written:** password

---

### 1.8 Send OTP
```http
POST /api/auth/send-otp/
Content-Type: application/json
```

**Request Body:**
```json
{
    "phone_num": "+1234567890"    // Finds user by CustomUser.phone_num
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "OTP sent successfully",
    "data": {
        "message": "OTP sent to +1234567890",
        "expires_in": 600,
        "phone_num": "+1234567890",
        "otp_code": "123456"    // ← CustomUser.otp_code (DEV ONLY - remove in prod)
    }
}
```

**DB Fields Read:** phone_num, otp_last_sent_at
**DB Fields Written:** otp_code, otp_expires_at, otp_attempts, otp_last_sent_at

---

### 1.9 Verify OTP
```http
POST /api/auth/verify-otp/
Content-Type: application/json
```

**Request Body:**
```json
{
    "phone_num": "+1234567890",    // Finds user by CustomUser.phone_num
    "otp_code": "123456"           // Verifies against CustomUser.otp_code
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Phone verified successfully",
    "data": {
        "user": {
            "id": "uuid",
            "phone_verified": true    // ← CustomUser.phone_verified
        }
    }
}
```

**DB Fields Read:** phone_num, otp_code, otp_expires_at, otp_attempts
**DB Fields Written:** phone_verified, otp_code, otp_expires_at, otp_attempts

---

### 1.10 Resend OTP
```http
POST /api/auth/resend-otp/
Content-Type: application/json
```

Same as 1.8 Send OTP

**DB Fields Read:** phone_num, otp_last_sent_at
**DB Fields Written:** otp_code, otp_expires_at, otp_attempts, otp_last_sent_at

---

## 2. Blood Type Endpoints

**API Base Path:** `/api/blood-types/`
**Database Table:** `bloodtype`

### 2.1 List All Blood Types
```http
GET /api/blood-types/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Blood types retrieved",
    "data": {
        "blood_types": [
            {
                "id": 1,                       // ← BloodType.id
                "code": "O+",                  // ← BloodType.code
                "name": "O Positive",           // ← BloodType.name
                "compatibility": ["O+", "A+", "B+", "AB+"] // ← BloodType.compatibility
            },
            ...
        ]
    }
}
```

**DB Fields Read:** id, code, name, compatibility
**DB Fields Written:** None

---

### 2.2 Get Blood Type Details
```http
GET /api/blood-types/{id}/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Blood type retrieved",
    "data": {
        "blood_type": {
            "id": 1,
            "code": "O+",
            "name": "O Positive",
            "compatibility": ["O+", "A+", "B+", "AB+"]
        }
    }
}
```

**DB Fields Read:** id, code, name, compatibility
**DB Fields Written:** None

---

## 3. Donor Profile Endpoints

**API Base Path:** `/api/donor/`
**Database Table:** `donorprofile`

### 3.1 Get Donor Profile
```http
GET /api/donor/profile/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Profile retrieved",
    "data": {
        "id": "uuid",                          // ← DonorProfile.id
        "user": "uuid",                        // ← DonorProfile.user
        "blood_type": {                        // ← BloodType (via FK)
            "id": 1,
            "code": "O+",
            "name": "O Positive"
        },
        "date_of_birth": "1990-01-01",        // ← DonorProfile.date_of_birth
        "gender": "Male",                      // ← DonorProfile.gender
        "weight": 75.5,                        // ← DonorProfile.weight
        "location_lat": 40.7128,               // ← DonorProfile.location_lat
        "location_lng": -74.0060,             // ← DonorProfile.location_lng
        "address": "123 Street, City",         // ← DonorProfile.address
        "city": "New York",                    // ← DonorProfile.city
        "country": "USA",                      // ← DonorProfile.country
        "is_available": true,                  // ← DonorProfile.is_available
        "total_donations": 5,                  // ← DonorProfile.total_donations
        "last_donation_date": "2024-05-15",    // ← DonorProfile.last_donation_date
        "eligibility_verified": true,          // ← DonorProfile.eligibility_verified
        "created_at": "2024-01-01T10:00:00Z"  // ← DonorProfile.created_at
    }
}
```

**DB Fields Read:** All DonorProfile fields + BloodType via FK
**DB Fields Written:** None

---

### 3.2 Create/Update Donor Profile
```http
PUT /api/donor/profile/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "blood_type": 1,               // → DonorProfile.blood_type (FK)
    "date_of_birth": "1990-01-01", // → DonorProfile.date_of_birth
    "gender": "Male",              // → DonorProfile.gender
    "weight": 75.5,                // → DonorProfile.weight
    "address": "123 Street, City", // → DonorProfile.address
    "city": "New York",            // → DonorProfile.city
    "country": "USA",              // → DonorProfile.country
    "postal_code": "10001"         // → DonorProfile.postal_code
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Profile updated successfully",
    "data": {
        "profile": { ... }    // Returns all DonorProfile fields
    }
}
```

**DB Fields Read:** user (from auth token)
**DB Fields Written:** blood_type, date_of_birth, gender, weight, address, city, state, country, postal_code, updated_at

---

### 3.3 Update Location
```http
PATCH /api/donor/profile/location/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "location_lat": 40.7128,       // → DonorProfile.location_lat
    "location_lng": -74.0060,      // → DonorProfile.location_lng
    "address": "123 Street, City"  // → DonorProfile.address
}
```

**DB Fields Read:** None
**DB Fields Written:** location_lat, location_lng, address, city (geocoded), updated_at

---

### 3.4 Toggle Availability
```http
POST /api/donor/profile/toggle-availability/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Availability updated",
    "data": {
        "is_available": false    // ← DonorProfile.is_available (toggled)
    }
}
```

**DB Fields Read:** is_available (current value)
**DB Fields Written:** is_available

---

### 3.5 Get Nearby Donors
```http
GET /api/donor/nearby/?blood_type=1&lat=40.7128&lng=-74.0060&radius=50
Authorization: Bearer <token>
```

**Query Parameters:**
- `blood_type` (optional) - Filter by blood type ID
- `lat` (required) - Latitude
- `lng` (required) - Longitude
- `radius` (optional) - Radius in km (default: 50)

**Response (200):**
```json
{
    "success": true,
    "message": "Nearby donors found",
    "data": {
        "donors": [
            {
                "id": "uuid",                    // ← CustomUser.id
                "full_name": "John Doe",          // ← CustomUser.full_name
                "blood_type": "O+",               // ← BloodType.code
                "distance_km": 5.2,              // Calculated from location_lat/lng
                "last_donation_date": "2024-05-15", // ← DonorProfile.last_donation_date
                "is_available": true              // ← DonorProfile.is_available
            },
            ...
        ],
        "count": 15,
        "total_pages": 2
    }
}
```

**DB Fields Read:** CustomUser (id, full_name), DonorProfile (blood_type, location_lat, location_lng, last_donation_date, is_available), BloodType (code)
**DB Fields Written:** None

---

### 3.6 Get Donor Profile by ID
```http
GET /api/donor/profile/{id}/
Authorization: Bearer <token>
```

Same response as 3.1, but for another user's profile

**DB Fields Read:** All DonorProfile fields + BloodType via FK
**DB Fields Written:** None

---

## 4. Blood Request Endpoints

**API Base Path:** `/api/requests/`
**Database Table:** `bloodrequest`

### 4.1 Create Blood Request
```http
POST /api/requests/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "blood_type": 1,                   // → BloodRequest.blood_type (FK)
    "urgency": "critical",             // → BloodRequest.urgency
    "units_needed": 2,                 // → BloodRequest.units_needed
    "hospital_name": "City Hospital",  // → BloodRequest.hospital_name
    "hospital_address": "123 Medical Center", // → BloodRequest.hospital_address
    "hospital_lat": 40.7128,           // → BloodRequest.hospital_lat
    "hospital_lng": -74.0060,          // → BloodRequest.hospital_lng
    "contact_person": "Dr. Smith",     // → BloodRequest.contact_person
    "contact_phone": "+1234567890",     // → BloodRequest.contact_phone
    "diagnosis": "Surgery",            // → BloodRequest.diagnosis
    "required_date": "2024-06-10",     // → BloodRequest.required_date
    "is_anonymous": true               // → BloodRequest.is_anonymous
}
```

**Response (201):**
```json
{
    "success": true,
    "message": "Blood request created",
    "data": {
        "id": "uuid",                       // ← BloodRequest.id
        "patient": "uuid",                  // ← BloodRequest.patient (from auth token)
        "blood_type": {                     // ← BloodType (via FK)
            "id": 1,
            "code": "O+",
            "name": "O Positive"
        },
        "urgency": "critical",              // ← BloodRequest.urgency
        "status": "active",                 // ← BloodRequest.status
        "created_at": "2024-06-05T10:00:00Z" // ← BloodRequest.created_at
    }
}
```

**DB Fields Read:** patient (from auth token), blood_type (FK lookup)
**DB Fields Written:** patient, blood_type, urgency, units_needed, hospital_name, hospital_address, hospital_lat, hospital_lng, contact_person, contact_phone, diagnosis, required_date, is_anonymous, status, created_at

---

### 4.2 List Blood Requests
```http
GET /api/requests/?page=1&blood_type=1&urgency=critical&status=active
Authorization: Bearer <token>
```

**Query Parameters:**
- `page` (optional) - Page number (default: 1)
- `blood_type` (optional) - Filter by blood type ID
- `urgency` (optional) - Filter by urgency (critical, high, normal)
- `status` (optional) - Filter by status (active, fulfilled, cancelled, expired)
- `lat` (optional) - Latitude for nearby requests
- `lng` (optional) - Longitude for nearby requests
- `radius` (optional) - Radius in km (default: 100)

**Response (200):**
```json
{
    "success": true,
    "message": "Blood requests retrieved",
    "data": {
        "results": [
            {
                "id": "uuid",
                "patient": {
                    "id": "uuid",
                    "full_name": "Jane Doe"    // ← CustomUser.full_name (or hidden if is_anonymous)
                },
                "blood_type": { "id": 1, "code": "O+", "name": "O Positive" },
                "urgency": "critical",
                "units_needed": 2,
                "hospital_name": "City Hospital",
                "hospital_lat": 40.7128,
                "hospital_lng": -74.0060,
                "required_date": "2024-06-10",
                "status": "active",
                "created_at": "2024-06-05T10:00:00Z"
            },
            ...
        ],
        "count": 150,
        "next": "...",
        "previous": null,
        "total_pages": 8
    }
}
```

**DB Fields Read:** All BloodRequest fields + CustomUser + BloodType
**DB Fields Written:** None

---

### 4.3 Get My Blood Requests
```http
GET /api/requests/my/?status=active
Authorization: Bearer <token>
```

Same response as 4.2, filtered by current user

**DB Fields Read:** All BloodRequest fields where patient = current user
**DB Fields Written:** None

---

### 4.4 Get Blood Request Details
```http
GET /api/requests/{id}/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Blood request retrieved",
    "data": {
        "request": {
            "id": "uuid",
            "patient": { "id": "uuid", "full_name": "Jane Doe" },
            "blood_type": { "id": 1, "code": "O+", "name": "O Positive" },
            "urgency": "critical",
            "units_needed": 2,
            "hospital_name": "City Hospital",
            "hospital_address": "123 Medical Center",
            "hospital_lat": 40.7128,
            "hospital_lng": -74.0060,
            "contact_person": "Dr. Smith",
            "contact_phone": "+1234567890",
            "diagnosis": "Surgery",
            "required_date": "2024-06-10",
            "status": "active",
            "is_anonymous": true,
            "views_count": 15,              // ← BloodRequest.views_count (incremented)
            "created_at": "2024-06-05T10:00:00Z",
            "updated_at": "2024-06-05T10:00:00Z"
        }
    }
}
```

**DB Fields Read:** All BloodRequest fields + CustomUser + BloodType
**DB Fields Written:** views_count (auto-increment)

---

### 4.5 Update Blood Request
```http
PATCH /api/requests/{id}/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "urgency": "high",          // → BloodRequest.urgency
    "units_needed": 3,          // → BloodRequest.units_needed
    "required_date": "2024-06-15" // → BloodRequest.required_date
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Blood request updated",
    "data": {
        "request": { ... }    // Returns updated BloodRequest
    }
}
```

**DB Fields Read:** patient (authorization check)
**DB Fields Written:** urgency, units_needed, required_date, updated_at

---

### 4.6 Cancel Blood Request
```http
POST /api/requests/{id}/cancel/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Blood request cancelled",
    "data": {
        "id": "uuid",
        "status": "cancelled"    // ← BloodRequest.status
    }
}
```

**DB Fields Read:** patient (authorization check)
**DB Fields Written:** status, updated_at

---

### 4.7 Get Nearby Blood Requests
```http
GET /api/requests/nearby/?lat=40.7128&lng=-74.0060&radius=50&blood_type=1
Authorization: Bearer <token>
```

**Query Parameters:**
- `lat` (required) - Latitude
- `lng` (required) - Longitude
- `radius` (optional) - Radius in km (default: 50)
- `blood_type` (optional) - Filter by blood type ID

**Response (200):**
```json
{
    "success": true,
    "message": "Nearby requests found",
    "data": {
        "requests": [
            {
                "id": "uuid",
                "blood_type": "O+",               // ← BloodType.code
                "urgency": "critical",            // ← BloodRequest.urgency
                "distance_km": 8.5,               // Calculated from hospital_lat/lng
                "hospital_name": "City Hospital",  // ← BloodRequest.hospital_name
                "created_at": "2024-06-05T09:00:00Z" // ← BloodRequest.created_at
            },
            ...
        ],
        "count": 7
    }
}
```

**DB Fields Read:** BloodRequest (hospital_lat, hospital_lng, urgency, hospital_name, created_at), BloodType (code)
**DB Fields Written:** None

---

## 5. Donation Endpoints

**API Base Path:** `/api/donations/`
**Database Table:** `donation`

### 5.1 Record Donation
```http
POST /api/donations/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "blood_request": "uuid",             // → Donation.blood_request (FK, optional)
    "blood_type": 1,                     // → Donation.blood_type (FK)
    "units": 1,                          // → Donation.units
    "donation_date": "2024-06-05",       // → Donation.donation_date
    "donation_center": "Red Cross Center", // → Donation.donation_center
    "donation_center_address": "123 Donation Street", // → Donation.donation_center_address
    "hemoglobin_level": 14.5,            // → Donation.hemoglobin_level
    "blood_pressure": "120/80",          // → Donation.blood_pressure
    "health_status": "good"              // → Donation.health_status
}
```

**Response (201):**
```json
{
    "success": true,
    "message": "Donation recorded successfully",
    "data": {
        "id": "uuid",                        // ← Donation.id
        "donor": "uuid",                     // ← Donation.donor (from auth token)
        "donation_date": "2024-06-05",       // ← Donation.donation_date
        "units": 1,                          // ← Donation.units
        "certificate_issued": false           // ← Donation.certificate_issued
    }
}
```

**DB Fields Read:** donor (from auth token), blood_request (FK lookup if provided), blood_type (FK lookup)
**DB Fields Written:** donor, blood_request, blood_type, units, donation_date, donation_center, donation_center_address, hemoglobin_level, blood_pressure, health_status, created_at
**Side Effects:** Updates DonorProfile.total_donations (+1), DonorProfile.last_donation_date

---

### 5.2 Get My Donations
```http
GET /api/donations/my/?page=1
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Donations retrieved",
    "data": {
        "donations": [
            {
                "id": "uuid",                        // ← Donation.id
                "donation_date": "2024-06-05",       // ← Donation.donation_date
                "blood_type": "O+",                  // ← BloodType.code
                "units": 1,                          // ← Donation.units
                "donation_center": "Red Cross Center", // ← Donation.donation_center
                "hospital_recipient": "City Hospital" // ← BloodRequest.hospital_name (via FK)
            },
            ...
        ],
        "count": 5,
        "total_donations": 5            // ← DonorProfile.total_donations
    }
}
```

**DB Fields Read:** Donation (all fields), BloodType (code), BloodRequest (hospital_name), DonorProfile (total_donations)
**DB Fields Written:** None

---

### 5.3 Get Donation Details
```http
GET /api/donations/{id}/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Donation retrieved",
    "data": {
        "donation": {
            "id": "uuid",
            "donor": "uuid",
            "blood_request": {
                "id": "uuid",
                "hospital_name": "City Hospital"
            },
            "blood_type": { "id": 1, "code": "O+", "name": "O Positive" },
            "units": 1,
            "donation_date": "2024-06-05",
            "donation_center": "Red Cross Center",
            "donation_center_address": "123 Donation Street",
            "hemoglobin_level": 14.5,
            "blood_pressure": "120/80",
            "health_status": "good",
            "notes": null,
            "certificate_issued": false,
            "created_at": "2024-06-05T10:00:00Z"
        }
    }
}
```

**DB Fields Read:** All Donation fields + BloodRequest + BloodType
**DB Fields Written:** None

---

### 5.4 Get Donation Certificate
```http
GET /api/donations/{id}/certificate/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Certificate generated",
    "data": {
        "certificate_url": "https://cdn.example.com/certificates/uuid.pdf",
        "donation_number": "DN-2024-0001",    // Generated from Donation.id
        "donation_date": "2024-06-05",          // ← Donation.donation_date
        "recipient": "On behalf of City Hospital" // ← BloodRequest.hospital_name
    }
}
```

**DB Fields Read:** Donation (donation_date, blood_request), BloodRequest (hospital_name)
**DB Fields Written:** certificate_issued

---

### 5.5 Get Donation Statistics
```http
GET /api/donations/stats/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Statistics retrieved",
    "data": {
        "total_donations": 5,                   // COUNT(Donation.id) WHERE donor = current user
        "total_units": 5,                       // SUM(Donation.units) WHERE donor = current user
        "last_donation_date": "2024-06-05",     // ← DonorProfile.last_donation_date
        "next_eligible_date": "2024-07-20",     // Calculated from last_donation_date + 56 days
        "lives_saved": 15,                      // total_units * 3
        "donations_by_year": {                   // GROUP BY YEAR(donation_date)
            "2023": 2,
            "2024": 3
        }
    }
}
```

**DB Fields Read:** Donation (donation_date, units), DonorProfile (last_donation_date)
**DB Fields Written:** None

---

## 6. SOS (Emergency) Endpoints

**API Base Path:** `/api/sos/`
**Database Table:** `sosrequest`

### 6.1 Create SOS Request
```http
POST /api/sos/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "blood_type": 1,                       // → SOSRequest.blood_type (FK)
    "hospital_name": "Emergency Center",   // → SOSRequest.hospital_name
    "hospital_address": "456 Emergency Ave", // → SOSRequest.hospital_address
    "hospital_lat": 40.7128,              // → SOSRequest.hospital_lat
    "hospital_lng": -74.0060,             // → SOSRequest.hospital_lng
    "contact_phone": "+1234567890",       // → SOSRequest.contact_phone
    "patient_name": "Jane Doe",            // → SOSRequest.patient_name
    "age": 35,                            // → SOSRequest.age
    "gender": "Female",                   // → SOSRequest.gender
    "units_needed": 2                     // → SOSRequest.units_needed
}
```

**Response (201):**
```json
{
    "success": true,
    "message": "SOS request created",
    "data": {
        "id": "uuid",                         // ← SOSRequest.id
        "requester": "uuid",                  // ← SOSRequest.requester (from auth token)
        "blood_type": { "id": 1, "code": "O+", "name": "O Positive" },
        "status": "active",                   // ← SOSRequest.status
        "created_at": "2024-06-05T10:30:00Z"  // ← SOSRequest.created_at
    }
}
```

**DB Fields Read:** requester (from auth token), blood_type (FK lookup)
**DB Fields Written:** requester, blood_type, hospital_name, hospital_address, hospital_lat, hospital_lng, contact_phone, patient_name, age, gender, units_needed, status, created_at

---

### 6.2 List Active SOS Requests
```http
GET /api/sos/active/?lat=40.7128&lng=-74.0060&radius=100&blood_type=1
Authorization: Bearer <token>
```

**Query Parameters:**
- `lat` (required) - Latitude
- `lng` (required) - Longitude
- `radius` (optional) - Radius in km (default: 100)
- `blood_type` (optional) - Filter by blood type ID

**Response (200):**
```json
{
    "success": true,
    "message": "Active SOS requests found",
    "data": {
        "requests": [
            {
                "id": "uuid",                         // ← SOSRequest.id
                "blood_type": "O+",                    // ← BloodType.code
                "hospital_name": "Emergency Center",   // ← SOSRequest.hospital_name
                "distance_km": 12.5,                   // Calculated from hospital_lat/lng
                "time_remaining_minutes": 90,           // Calculated from created_at
                "responders_count": 3,                 // ← SOSRequest.responders_count
                "created_at": "2024-06-05T10:00:00Z"   // ← SOSRequest.created_at
            },
            ...
        ],
        "count": 2
    }
}
```

**DB Fields Read:** SOSRequest (hospital_lat, hospital_lng, created_at, responders_count, hospital_name), BloodType (code)
**DB Fields Written:** None

---

### 6.3 Respond to SOS
```http
POST /api/sos/{id}/respond/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Response recorded",
    "data": {
        "responders_count": 4    // ← SOSRequest.responders_count (incremented)
    }
}
```

**DB Fields Read:** responders_count (current value)
**DB Fields Written:** responders_count

---

### 6.4 Get SOS Details
```http
GET /api/sos/{id}/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "SOS retrieved",
    "data": {
        "sos": {
            "id": "uuid",
            "requester": { "id": "uuid", "full_name": "John Doe" },
            "blood_type": { "id": 1, "code": "O+", "name": "O Positive" },
            "patient_name": "Jane Doe",
            "hospital_name": "Emergency Center",
            "hospital_address": "456 Emergency Ave",
            "hospital_lat": 40.7128,
            "hospital_lng": -74.0060,
            "contact_phone": "+1234567890",
            "age": 35,
            "gender": "Female",
            "units_needed": 2,
            "status": "active",
            "responders_count": 4,
            "created_at": "2024-06-05T10:30:00Z",
            "resolved_at": null
        }
    }
}
```

**DB Fields Read:** All SOSRequest fields + CustomUser + BloodType
**DB Fields Written:** None

---

### 6.5 Resolve SOS
```http
POST /api/sos/{id}/resolve/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "resolution_note": "Blood successfully delivered"
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "SOS resolved",
    "data": {
        "id": "uuid",
        "status": "resolved",        // ← SOSRequest.status
        "resolved_at": "2024-06-05T12:00:00Z" // ← SOSRequest.resolved_at
    }
}
```

**DB Fields Read:** requester (authorization check)
**DB Fields Written:** status, resolved_at

---

### 6.6 Cancel SOS
```http
POST /api/sos/{id}/cancel/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "SOS cancelled",
    "data": {
        "id": "uuid",
        "status": "cancelled"     // ← SOSRequest.status
    }
}
```

**DB Fields Read:** requester (authorization check)
**DB Fields Written:** status

---

## 7. Messaging Endpoints

**API Base Path:** `/api/messages/`
**Database Tables:** `conversation`, `message`

### 7.1 List Conversations
```http
GET /api/messages/conversations/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Conversations retrieved",
    "data": {
        "conversations": [
            {
                "id": "uuid",                         // ← Conversation.id
                "other_participant": {
                    "id": "uuid",                     // ← CustomUser.id
                    "full_name": "Jane Doe",          // ← CustomUser.full_name
                    "avatar_url": "https://cdn.example.com/avatar.jpg"
                },
                "last_message": "I can help...",     // ← Latest Message.content
                "last_message_at": "2024-06-05T10:00:00Z", // ← Conversation.last_message_at
                "unread_count": 2,                    // COUNT(Message) WHERE is_read=false
                "related_request": {
                    "id": "uuid",                     // ← Conversation.related_blood_request
                    "blood_type": "O+"                // ← BloodRequest.blood_type
                }
            },
            ...
        ]
    }
}
```

**DB Fields Read:** Conversation (all), CustomUser (other participant), Message (latest, unread count), BloodRequest (related), BloodType
**DB Fields Written:** None

---

### 7.2 Get Conversation Messages
```http
GET /api/messages/conversations/{id}/?page=1
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Messages retrieved",
    "data": {
        "messages": [
            {
                "id": "uuid",                         // ← Message.id
                "sender": {
                    "id": "uuid",                     // ← CustomUser.id
                    "full_name": "John Doe"           // ← CustomUser.full_name
                },
                "content": "Hello, I saw your blood request", // ← Message.content
                "is_read": true,                      // ← Message.is_read
                "created_at": "2024-06-05T09:00:00Z"  // ← Message.created_at
            },
            ...
        ],
        "other_participant": {
            "id": "uuid",
            "full_name": "Jane Doe"
        }
    }
}
```

**DB Fields Read:** Message (all), CustomUser (sender), Conversation (other participant)
**DB Fields Written:** None

---

### 7.3 Send Message
```http
POST /api/messages/send/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "conversation_id": "uuid",        // Uses existing Conversation
    "content": "I can help with the donation" // → Message.content
}
```

**Or start new conversation:**
```json
{
    "recipient_id": "uuid",           // Creates Conversation with current user
    "content": "I saw your blood request",
    "related_request_id": "uuid"      // → Conversation.related_blood_request
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Message sent",
    "data": {
        "message": {
            "id": "uuid",                 // ← Message.id
            "conversation": "uuid",        // ← Message.conversation
            "sender": "uuid",             // ← Message.sender
            "content": "...",             // ← Message.content
            "is_read": false,             // ← Message.is_read
            "created_at": "2024-06-05T10:00:00Z" // ← Message.created_at
        }
    }
}
```

**DB Fields Read:** Conversation (if existing), CustomUser (recipient), BloodRequest (related)
**DB Fields Written:** Conversation (if new), Message (all fields), Conversation.last_message_at

---

### 7.4 Mark Messages as Read
```http
POST /api/messages/conversations/{id}/mark-read/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Messages marked as read",
    "data": {
        "marked_count": 5    // Number of messages updated
    }
}
```

**DB Fields Read:** Conversation (authorization check)
**DB Fields Written:** Message.is_read, Message.read_at (all unread messages in conversation)

---

### 7.5 Delete Conversation
```http
DELETE /api/messages/conversations/{id}/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Conversation deleted"
}
```

**DB Fields Read:** Conversation (authorization check)
**DB Fields Written:** Conversation.is_active

---

## 8. Notification Endpoints

**API Base Path:** `/api/notifications/`
**Database Table:** `notification`

### 8.1 List Notifications
```http
GET /api/notifications/?page=1&is_read=false&type=blood_request_match
Authorization: Bearer <token>
```

**Query Parameters:**
- `page` (optional) - Page number
- `is_read` (optional) - Filter by read status
- `type` (optional) - Filter by notification type

**Response (200):**
```json
{
    "success": true,
    "message": "Notifications retrieved",
    "data": {
        "notifications": [
            {
                "id": "uuid",                         // ← Notification.id
                "type": "blood_request_match",        // ← Notification.type
                "title": "New blood request near you", // ← Notification.title
                "message": "Someone needs O+ blood...", // ← Notification.message
                "data": {                             // ← Notification.data
                    "request_id": "uuid",
                    "distance_km": 5.2
                },
                "is_read": false,                     // ← Notification.is_read
                "created_at": "2024-06-05T10:00:00Z" // ← Notification.created_at
            },
            ...
        ],
        "unread_count": 5    // COUNT WHERE recipient=user AND is_read=false
    }
}
```

**DB Fields Read:** All Notification fields where recipient = current user
**DB Fields Written:** None

---

### 8.2 Mark Notification as Read
```http
POST /api/notifications/{id}/mark-read/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Notification marked as read"
}
```

**DB Fields Read:** recipient (authorization check)
**DB Fields Written:** is_read, read_at

---

### 8.3 Mark All as Read
```http
POST /api/notifications/mark-all-read/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "All notifications marked as read",
    "data": {
        "marked_count": 10
    }
}
```

**DB Fields Read:** recipient (from auth token)
**DB Fields Written:** is_read, read_at (all unread notifications)

---

### 8.4 Delete Notification
```http
DELETE /api/notifications/{id}/
Authorization: Bearer <token>
```

**DB Fields Read:** recipient (authorization check)
**DB Fields Written:** Record deleted

---

### 8.5 Get Notification Preferences
```http
GET /api/notifications/preferences/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Preferences retrieved",
    "data": {
        "blood_request_match": true,
        "sos_alert": true,
        "donation_reminder": true,
        "message_received": true,
        "achievement_earned": true,
        "email_notifications": true,
        "push_notifications": true
    }
}
```

**DB Fields Read:** Stored in separate user preferences table/field
**DB Fields Written:** None

---

### 8.6 Update Notification Preferences
```http
PATCH /api/notifications/preferences/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "sos_alert": false,
    "email_notifications": false
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Preferences updated",
    "data": {
        "preferences": { ... }
    }
}
```

**DB Fields Read:** None
**DB Fields Written:** User preferences fields

---

## 9. Achievement Endpoints

**API Base Path:** `/api/achievements/`
**Database Tables:** `achievement`, `userachievement`

### 9.1 List Achievements
```http
GET /api/achievements/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Achievements retrieved",
    "data": {
        "achievements": [
            {
                "id": 1,                             // ← Achievement.id
                "code": "first_donation",            // ← Achievement.code
                "name": "First Drop",                // ← Achievement.name
                "description": "Made your first blood donation", // ← Achievement.description
                "icon_url": "https://cdn.example.com/badges/first.png", // ← Achievement.icon_url
                "category": "donation",              // ← Achievement.category
                "points": 10,                        // ← Achievement.points
                "requirement_type": "donation_count", // ← Achievement.requirement_type
                "requirement_value": 1,               // ← Achievement.requirement_value
                "earned": true,                      // ← UserAchievement.earned_at (not null)
                "earned_at": "2024-05-15T10:00:00Z"  // ← UserAchievement.earned_at
            },
            {
                "id": 2,
                "code": "five_donations",
                "name": "Regular Donor",
                "description": "Completed 5 donations",
                "icon_url": "https://cdn.example.com/badges/five.png",
                "category": "donation",
                "points": 50,
                "requirement_type": "donation_count",
                "requirement_value": 5,
                "earned": false,                     // ← UserAchievement.earned_at (null)
                "progress": 3,                       // ← UserAchievement.progress
                "progress_percentage": 60             // Calculated
            },
            ...
        ]
    }
}
```

**DB Fields Read:** Achievement (all), UserAchievement (earned_at, progress) for current user
**DB Fields Written:** None

---

### 9.2 Get My Achievements
```http
GET /api/achievements/my/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "My achievements retrieved",
    "data": {
        "earned_achievements": [
            {
                "id": 1,                             // ← Achievement.id
                "code": "first_donation",            // ← Achievement.code
                "name": "First Drop",                // ← Achievement.name
                "earned_at": "2024-05-15T10:00:00Z" // ← UserAchievement.earned_at
            },
            ...
        ],
        "total_points": 150,                // SUM(Achievement.points) for earned
        "total_badges": 3,                  // COUNT(UserAchievement) for user
        "next_achievement": {
            "id": 2,
            "code": "five_donations",
            "progress": 3,                  // ← UserAchievement.progress
            "required": 5                   // ← Achievement.requirement_value
        }
    }
}
```

**DB Fields Read:** Achievement (all earned), UserAchievement (all), Achievement (next to unlock)
**DB Fields Written:** None

---

### 9.3 Get Achievement Details
```http
GET /api/achievements/{id}/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Achievement retrieved",
    "data": {
        "achievement": {
            "id": 1,
            "code": "first_donation",
            "name": "First Drop",
            "description": "Made your first blood donation",
            "icon_url": "https://cdn.example.com/badges/first.png",
            "category": "donation",
            "points": 10,
            "requirement_type": "donation_count",
            "requirement_value": 1,
            "earned": true,
            "earned_at": "2024-05-15T10:00:00Z"
        }
    }
}
```

**DB Fields Read:** Achievement (all), UserAchievement (earned_at) for current user
**DB Fields Written:** None

---

## 10. Health Eligibility Endpoints

**API Base Path:** `/api/health/`
**Database Tables:** `healtheligibilityresponse`, `donorprofile`

### 10.1 Get Health Quiz
```http
GET /api/health/quiz/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Health quiz retrieved",
    "data": {
        "quiz_version": "v1.0",          // Used in HealthEligibilityResponse.quiz_version
        "questions": [
            {
                "id": 1,
                "question": "Have you had any tattoos or piercings in the last 6 months?",
                "type": "boolean",
                "options": ["Yes", "No"]
            },
            {
                "id": 2,
                "question": "What is your current weight?",
                "type": "number",
                "unit": "kg"
            },
            ...
        ]
    }
}
```

**DB Fields Read:** None
**DB Fields Written:** None

---

### 10.2 Submit Health Quiz
```http
POST /api/health/quiz/submit/
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body (writes to DB):**
```json
{
    "responses": {                     // → HealthEligibilityResponse.responses
        "1": false,
        "2": 75,
        ...
    }
}
```

**Response (200):**
```json
{
    "success": true,
    "message": "Quiz completed",
    "data": {
        "is_eligible": true,            // ← HealthEligibilityResponse.is_eligible
        "eligibility_valid_until": "2024-09-05", // → DonorProfile.eligibility_valid_until
        "ineligibility_reasons": []     // ← HealthEligibilityResponse.ineligibility_reasons
    }
}
```

**Or if ineligible:**
```json
{
    "success": false,
    "message": "Not eligible to donate",
    "data": {
        "is_eligible": false,
        "ineligibility_reasons": [      // ← HealthEligibilityResponse.ineligibility_reasons
            "Recent tattoo - wait 6 months from tattoo date",
            "Weight below minimum requirement (50kg)"
        ],
        "can_retry_after": "2024-12-01"
    }
}
```

**DB Fields Read:** user (from auth token)
**DB Fields Written:** HealthEligibilityResponse (user, responses, is_eligible, ineligibility_reasons, quiz_version, created_at), DonorProfile (eligibility_verified, eligibility_valid_until)

---

### 10.3 Check Eligibility Status
```http
GET /api/health/eligibility/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "Eligibility status retrieved",
    "data": {
        "is_eligible": true,                    // ← DonorProfile.eligibility_verified + valid_until check
        "valid_until": "2024-09-05",            // ← DonorProfile.eligibility_valid_until
        "days_until_expiry": 90,                // Calculated from valid_until
        "last_quiz_date": "2024-06-05"          // ← HealthEligibilityResponse.created_at (latest)
    }
}
```

**DB Fields Read:** DonorProfile (eligibility_verified, eligibility_valid_until), HealthEligibilityResponse (created_at - latest)
**DB Fields Written:** None

---

## 11. Search Endpoints

### 11.1 Search Donors
```http
GET /api/search/donors/?q=John&blood_type=1&city=New+York
Authorization: Bearer <token>
```

**Query Parameters:**
- `q` (optional) - Search query (name)
- `blood_type` (optional) - Filter by blood type
- `city` (optional) - Filter by city
- `lat`, `lng`, `radius` (optional) - Location-based search

**Response:** Same as 3.5 Get Nearby Donors

**DB Fields Read:** CustomUser, DonorProfile, BloodType (filtered by search criteria)
**DB Fields Written:** None

---

### 11.2 Search Blood Requests
```http
GET /api/search/requests/?blood_type=1&urgency=critical&city=New+York
Authorization: Bearer <token>
```

**Response:** Same as 4.2 List Blood Requests

**DB Fields Read:** BloodRequest, CustomUser, BloodType (filtered by search criteria)
**DB Fields Written:** None

---

## 12. Statistics Endpoints

### 12.1 Get Public Statistics
```http
GET /api/stats/public/
```

**Response (200):**
```json
{
    "success": true,
    "message": "Public statistics retrieved",
    "data": {
        "total_donors": 15234,          // COUNT(DISTINCT DonorProfile.user)
        "total_donations": 45678,        // COUNT(Donation.id)
        "active_requests": 234,          // COUNT(BloodRequest.id) WHERE status='active'
        "lives_saved": 137034,           // SUM(Donation.units) * 3
        "blood_type_distribution": {     // COUNT(DonorProfile.user) GROUP BY blood_type
            "O+": 35,
            "A+": 28,
            "B+": 15,
            "AB+": 7,
            "O-": 8,
            "A-": 4,
            "B-": 2,
            "AB-": 1
        }
    }
}
```

**DB Fields Read:** Aggregated from DonorProfile, Donation, BloodRequest
**DB Fields Written:** None

---

### 12.2 Get User Statistics
```http
GET /api/stats/user/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "success": true,
    "message": "User statistics retrieved",
    "data": {
        "total_donations": 5,            // COUNT(Donation.id) WHERE donor=current_user
        "total_units_donated": 5,        // SUM(Donation.units) WHERE donor=current_user
        "lives_saved": 15,               // total_units * 3
        "requests_created": 2,          // COUNT(BloodRequest.id) WHERE patient=current_user
        "sos_responded": 3,             // COUNT(SOSResponse.id) WHERE user=current_user
        "achievements_count": 3,        // COUNT(UserAchievement.id) WHERE user=current_user
        "points": 150                    // SUM(Achievement.points) via UserAchievement
    }
}
```

**DB Fields Read:** Donation, BloodRequest, SOSResponse, UserAchievement, Achievement (filtered by current user)
**DB Fields Written:** None

---

## 13. Admin Endpoints

### 13.1 Verify Blood Request
```http
POST /api/admin/requests/{id}/verify/
Authorization: Bearer <token> (Admin only)
```

**DB Fields Read:** BloodRequest (authorization check)
**DB Fields Written:** BloodRequest (verified flag - if added)

---

### 13.2 Get Dashboard Stats
```http
GET /api/admin/dashboard/
Authorization: Bearer <token> (Admin only)
```

**Response (200):**
```json
{
    "success": true,
    "message": "Dashboard data retrieved",
    "data": {
        "total_users": 15234,            // COUNT(CustomUser.id)
        "active_users": 8934,            // COUNT(CustomUser.id) WHERE last_login > 30 days ago
        "new_users_today": 45,           // COUNT(CustomUser.id) WHERE date_joined = today
        "total_requests": 1234,          // COUNT(BloodRequest.id)
        "active_requests": 234,          // COUNT(BloodRequest.id) WHERE status='active'
        "fulfilled_requests": 890,       // COUNT(BloodRequest.id) WHERE status='fulfilled'
        "total_donations": 4567,         // COUNT(Donation.id)
        "donations_today": 23            // COUNT(Donation.id) WHERE donation_date = today
    }
}
```

**DB Fields Read:** Aggregated from all tables
**DB Fields Written:** None

---

## 📊 Database Field to API Endpoint Mapping

### CustomUser (account_customuser)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ /profile/ | ❌ | ❌ | ❌ |
| email | ✅ /profile/ | ✅ /register/, /login/ | ❌ | ❌ |
| password | ❌ | ✅ /register/, /login/, /change-password/ | ✅ /change-password/ | ❌ |
| full_name | ✅ /profile/ | ✅ /register/ | ✅ /profile/update/ | ❌ |
| phone_num | ✅ /profile/ | ✅ /register/ | ✅ /profile/update/ | ❌ |
| phone_verified | ✅ /profile/ | ❌ | ✅ /verify-otp/ | ❌ |
| otp_code | ❌ | ❌ | ✅ /send-otp/ | ❌ |
| otp_expires_at | ❌ | ❌ | ✅ /send-otp/ | ❌ |
| otp_attempts | ❌ | ❌ | ✅ /send-otp/, /verify-otp/ | ❌ |
| otp_last_sent_at | ❌ | ❌ | ✅ /send-otp/ | ❌ |
| is_active | ✅ /profile/ | ❌ | ❌ | ❌ |
| date_joined | ✅ /profile/ | ❌ | ❌ | ❌ |
| last_login | ✅ /profile/ | ❌ | ✅ /login/ | ❌ |

### BloodType (bloodtype)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ /blood-types/ | ❌ | ❌ | ❌ |
| code | ✅ /blood-types/ | ❌ | ❌ | ❌ |
| name | ✅ /blood-types/ | ❌ | ❌ | ❌ |
| compatibility | ✅ /blood-types/{id}/ | ❌ | ❌ | ❌ |

### DonorProfile (donorprofile)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ /donor/profile/ | ❌ | ❌ | ❌ |
| user | ✅ /donor/profile/ | ✅ /donor/profile/ (from token) | ❌ | ❌ |
| blood_type | ✅ /donor/profile/ | ✅ /donor/profile/ | ✅ /donor/profile/ | ❌ |
| date_of_birth | ✅ /donor/profile/ | ✅ /donor/profile/ | ❌ | ❌ |
| gender | ✅ /donor/profile/ | ✅ /donor/profile/ | ❌ | ❌ |
| weight | ✅ /donor/profile/ | ✅ /donor/profile/ | ❌ | ❌ |
| location_lat | ✅ /donor/profile/ | ✅ /donor/profile/ | ✅ /donor/profile/location/ | ❌ |
| location_lng | ✅ /donor/profile/ | ✅ /donor/profile/ | ✅ /donor/profile/location/ | ❌ |
| address | ✅ /donor/profile/ | ✅ /donor/profile/ | ✅ /donor/profile/location/ | ❌ |
| city | ✅ /donor/profile/ | ✅ /donor/profile/ | ✅ /donor/profile/location/ | ❌ |
| state | ✅ /donor/profile/ | ✅ /donor/profile/ | ❌ | ❌ |
| country | ✅ /donor/profile/ | ✅ /donor/profile/ | ❌ | ❌ |
| postal_code | ✅ /donor/profile/ | ✅ /donor/profile/ | ❌ | ❌ |
| is_available | ✅ /donor/profile/, /donor/nearby/ | ✅ /donor/profile/ | ✅ /donor/profile/toggle-availability/ | ❌ |
| last_donation_date | ✅ /donor/profile/, /donor/nearby/ | ❌ | ✅ /donations/ (auto) | ❌ |
| total_donations | ✅ /donor/profile/, /donations/my/ | ❌ | ✅ /donations/ (auto) | ❌ |
| eligibility_verified | ✅ /donor/profile/, /health/eligibility/ | ❌ | ✅ /health/quiz/submit/ | ❌ |
| eligibility_valid_until | ✅ /donor/profile/, /health/eligibility/ | ❌ | ✅ /health/quiz/submit/ | ❌ |
| created_at | ✅ /donor/profile/ | ❌ | ❌ | ❌ |
| updated_at | ✅ /donor/profile/ | ❌ | ✅ All PATCH/PUT | ❌ |

### BloodRequest (bloodrequest)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ All | ❌ | ❌ | ❌ |
| patient | ✅ /requests/{id}/ | ✅ /requests/ (from token) | ❌ | ❌ |
| blood_type | ✅ All | ✅ /requests/ | ✅ /requests/{id}/ | ❌ |
| urgency | ✅ All | ✅ /requests/ | ✅ /requests/{id}/ | ❌ |
| units_needed | ✅ All | ✅ /requests/ | ✅ /requests/{id}/ | ❌ |
| hospital_name | ✅ /requests/{id}/, /requests/nearby/ | ✅ /requests/ | ❌ | ❌ |
| hospital_address | ✅ /requests/{id}/ | ✅ /requests/ | ❌ | ❌ |
| hospital_lat | ✅ /requests/nearby/ | ✅ /requests/ | ❌ | ❌ |
| hospital_lng | ✅ /requests/nearby/ | ✅ /requests/ | ❌ | ❌ |
| contact_person | ✅ /requests/{id}/ | ✅ /requests/ | ✅ /requests/{id}/ | ❌ |
| contact_phone | ✅ /requests/{id}/ | ✅ /requests/ | ✅ /requests/{id}/ | ❌ |
| diagnosis | ✅ /requests/{id}/ | ✅ /requests/ | ❌ | ❌ |
| required_date | ✅ All | ✅ /requests/ | ✅ /requests/{id}/ | ❌ |
| status | ✅ All | ✅ /requests/ (default) | ✅ /requests/{id}/cancel/ | ❌ |
| is_anonymous | ✅ /requests/{id}/ | ✅ /requests/ | ❌ | ❌ |
| views_count | ✅ /requests/{id}/ | ✅ /requests/ (default 0) | ✅ /requests/{id}/ (auto) | ❌ |
| created_at | ✅ All | ✅ /requests/ (auto) | ❌ | ❌ |
| updated_at | ✅ /requests/{id}/ | ✅ /requests/ (auto) | ✅ All updates | ❌ |
| fulfilled_at | ✅ /requests/{id}/ | ❌ | ✅ /requests/{id}/ (when status=fulfilled) | ❌ |

### Donation (donation)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ All | ❌ | ❌ | ❌ |
| donor | ✅ /donations/my/ | ✅ /donations/ (from token) | ❌ | ❌ |
| blood_request | ✅ /donations/{id}/ | ✅ /donations/ | ❌ | ❌ |
| blood_type | ✅ All | ✅ /donations/ | ❌ | ❌ |
| units | ✅ All | ✅ /donations/ | ❌ | ❌ |
| donation_date | ✅ All | ✅ /donations/ | ❌ | ❌ |
| donation_center | ✅ All | ✅ /donations/ | ❌ | ❌ |
| donation_center_address | ✅ /donations/{id}/ | ✅ /donations/ | ❌ | ❌ |
| hemoglobin_level | ✅ /donations/{id}/ | ✅ /donations/ | ❌ | ❌ |
| blood_pressure | ✅ /donations/{id}/ | ✅ /donations/ | ❌ | ❌ |
| health_status | ✅ /donations/{id}/ | ✅ /donations/ | ❌ | ❌ |
| notes | ✅ /donations/{id}/ | ✅ /donations/ | ❌ | ❌ |
| certificate_issued | ✅ All | ✅ /donations/ (default false) | ✅ /donations/{id}/certificate/ | ❌ |
| created_at | ✅ All | ✅ /donations/ (auto) | ❌ | ❌ |

### SOSRequest (sosrequest)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ All | ❌ | ❌ | ❌ |
| requester | ✅ /sos/{id}/ | ✅ /sos/ (from token) | ❌ | ❌ |
| blood_type | ✅ All | ✅ /sos/ | ❌ | ❌ |
| patient_name | ✅ /sos/{id}/ | ✅ /sos/ | ❌ | ❌ |
| hospital_name | ✅ All | ✅ /sos/ | ❌ | ❌ |
| hospital_address | ✅ /sos/{id}/ | ✅ /sos/ | ❌ | ❌ |
| hospital_lat | ✅ /sos/active/ | ✅ /sos/ | ❌ | ❌ |
| hospital_lng | ✅ /sos/active/ | ✅ /sos/ | ❌ | ❌ |
| contact_phone | ✅ /sos/{id}/ | ✅ /sos/ | ❌ | ❌ |
| age | ✅ /sos/{id}/ | ✅ /sos/ | ❌ | ❌ |
| gender | ✅ /sos/{id}/ | ✅ /sos/ | ❌ | ❌ |
| units_needed | ✅ /sos/{id}/ | ✅ /sos/ | ❌ | ❌ |
| status | ✅ All | ✅ /sos/ (default) | ✅ /sos/{id}/resolve/, /cancel/ | ❌ |
| responders_count | ✅ /sos/active/ | ✅ /sos/ (default 0) | ✅ /sos/{id}/respond/ (auto) | ❌ |
| created_at | ✅ All | ✅ /sos/ (auto) | ❌ | ❌ |
| resolved_at | ✅ /sos/{id}/ | ❌ | ✅ /sos/{id}/resolve/ | ❌ |

### Conversation (conversation)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ /messages/conversations/ | ❌ | ❌ | ❌ |
| participant1 | ✅ /messages/conversations/ | ✅ /messages/send/ (from token) | ❌ | ❌ |
| participant2 | ✅ /messages/conversations/ | ✅ /messages/send/ | ❌ | ❌ |
| related_blood_request | ✅ /messages/conversations/ | ✅ /messages/send/ | ❌ | ❌ |
| last_message_at | ✅ /messages/conversations/ | ❌ | ✅ /messages/send/ (auto) | ❌ |
| is_active | ✅ /messages/conversations/ | ✅ /messages/send/ (default) | ✅ /messages/conversations/{id}/ DELETE | ❌ |
| created_at | ✅ /messages/conversations/{id}/ | ✅ /messages/send/ (auto) | ❌ | ❌ |

### Message (message)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ /messages/conversations/{id}/ | ❌ | ❌ | ❌ |
| conversation | ✅ /messages/conversations/{id}/ | ✅ /messages/send/ | ❌ | ❌ |
| sender | ✅ /messages/conversations/{id}/ | ✅ /messages/send/ (from token) | ❌ | ❌ |
| content | ✅ /messages/conversations/{id}/ | ✅ /messages/send/ | ❌ | ❌ |
| is_read | ✅ /messages/conversations/{id}/ | ✅ /messages/send/ (default false) | ✅ /messages/conversations/{id}/mark-read/ | ❌ |
| read_at | ✅ /messages/conversations/{id}/ | ❌ | ✅ /messages/conversations/{id}/mark-read/ | ❌ |
| created_at | ✅ /messages/conversations/{id}/ | ✅ /messages/send/ (auto) | ❌ | ❌ |

### Notification (notification)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ All | ❌ | ❌ | ✅ /notifications/{id}/ |
| recipient | ✅ All | ✅ Auto-create | ❌ | ❌ |
| type | ✅ All | ✅ Auto-create | ❌ | ❌ |
| title | ✅ All | ✅ Auto-create | ❌ | ❌ |
| message | ✅ All | ✅ Auto-create | ❌ | ❌ |
| data | ✅ All | ✅ Auto-create | ❌ | ❌ |
| related_blood_request | ✅ All | ✅ Auto-create | ❌ | ❌ |
| is_read | ✅ All | ✅ Auto-create (default false) | ✅ /notifications/{id}/mark-read/, /mark-all-read/ | ❌ |
| read_at | ✅ All | ❌ | ✅ /notifications/{id}/mark-read/, /mark-all-read/ | ❌ |
| created_at | ✅ All | ✅ Auto-create | ❌ | ❌ |

### Achievement (achievement)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ All | ❌ | ❌ | ❌ |
| code | ✅ All | ❌ | ❌ | ❌ |
| name | ✅ All | ❌ | ❌ | ❌ |
| description | ✅ /achievements/{id}/ | ❌ | ❌ | ❌ |
| icon_url | ✅ All | ❌ | ❌ | ❌ |
| category | ✅ /achievements/ | ❌ | ❌ | ❌ |
| requirement_type | ❌ | ❌ | ❌ | ❌ |
| requirement_value | ❌ | ❌ | ❌ | ❌ |
| points | ✅ All | ❌ | ❌ | ❌ |
| sort_order | ✅ /achievements/ | ❌ | ❌ | ❌ |
| is_active | ✅ /achievements/ | ❌ | ❌ | ❌ |

### UserAchievement (userachievement)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ✅ /achievements/my/ | ❌ | ❌ | ❌ |
| user | ✅ /achievements/my/ | ✅ Auto-create | ❌ | ❌ |
| achievement | ✅ /achievements/my/ | ✅ Auto-create | ❌ | ❌ |
| earned_at | ✅ /achievements/, /achievements/my/ | ✅ Auto-create | ❌ | ❌ |
| progress | ✅ /achievements/ | ✅ Auto-create (default 0) | ✅ Auto-update | ❌ |

### HealthEligibilityResponse (healtheligibilityresponse)
| Field | GET | POST | PATCH | DELETE |
|-------|-----|------|-------|--------|
| id | ❌ | ❌ | ❌ | ❌ |
| user | ✅ /health/eligibility/ (via DonorProfile) | ✅ /health/quiz/submit/ (from token) | ❌ | ❌ |
| responses | ❌ | ✅ /health/quiz/submit/ | ❌ | ❌ |
| is_eligible | ✅ /health/eligibility/ | ✅ /health/quiz/submit/ | ❌ | ❌ |
| ineligibility_reasons | ✅ /health/quiz/submit/ | ✅ /health/quiz/submit/ | ❌ | ❌ |
| quiz_version | ✅ /health/quiz/ | ✅ /health/quiz/submit/ | ❌ | ❌ |
| created_at | ✅ /health/eligibility/ | ✅ /health/quiz/submit/ (auto) | ❌ | ❌ |

---

## 📊 Pagination

All list endpoints support pagination:

```
?page=1&page_size=20
```

Default page size is 20, maximum is 100.

**Response Format:**
```json
{
    "success": true,
    "message": "Data retrieved",
    "data": {
        "results": [...],
        "count": 150,
        "next": "http://api.com/endpoint/?page=2",
        "previous": null,
        "total_pages": 8
    }
}
```

---

## 🚨 Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request - Invalid input |
| 401 | Unauthorized - Invalid/missing token |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource doesn't exist |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Server Error - Internal error |

---

## 🔄 Webhooks (Future)

### Donation Completed
```http
POST {webhook_url}
{
    "event": "donation.completed",
    "data": {
        "donation_id": "uuid",              // ← Donation.id
        "donor_id": "uuid",                 // ← Donation.donor
        "timestamp": "2024-06-05T10:00:00Z" // ← Donation.created_at
    }
}
```

### Blood Request Fulfilled
```http
POST {webhook_url}
{
    "event": "request.fulfilled",
    "data": {
        "request_id": "uuid",               // ← BloodRequest.id
        "fulfilled_at": "2024-06-05T10:00:00Z" // ← BloodRequest.fulfilled_at
    }
}
```

---

**Last Updated:** 2026-06-05
**API Version:** v1.0
**Base URL:** `http://your-domain.com/api`
