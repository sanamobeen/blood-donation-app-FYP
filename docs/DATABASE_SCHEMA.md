# LifeDrop - Blood Donation Database Schema

Complete database schema documentation with API endpoint mappings for the Blood Donation application.

---

## 📊 Entity Relationship Diagram (Overview)

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  CustomUser │────────>│ DonorProfile │         │ BloodType   │
│  (account)  │         │              │         │             │
└─────────────┘         └──────────────┘         └─────────────┘
        │                                                    │
        │                                                    │
        ▼                                                    ▼
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│BloodRequest │────────>│   Donation    │<────────│  BloodType  │
│            │         │              │         │             │
└─────────────┘         └──────────────┘         └─────────────┘
        │                      ▲
        │                      │
        ▼                      │
┌─────────────┐                │
│ SOSRequest  │                │
│            │                │
└─────────────┘                │
                                │
┌─────────────┐         ┌──────────────┐
│Notification │         │  Message     │
│            │         │  Conversation│
└─────────────┘         └──────────────┘

┌─────────────┐         ┌──────────────┐
│ Achievement │<────────│UserAchievement│
│  (Badge)    │         │              │
└─────────────┘         └──────────────┘
```

---

## 🗄️ Database Tables with API Endpoint Mappings

### 1. CustomUser (account_customuser)
**API Base Path:** `/api/auth/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK | GET /profile/ | Primary key |
| email | VARCHAR(254) | UNIQUE, NOT NULL | POST /register/, POST /login/ | User's email (login identifier) |
| password | VARCHAR | HASHED | POST /register/, POST /change-password/ | Hashed password |
| full_name | VARCHAR(255) | NOT NULL | GET /profile/, PATCH /profile/update/ | User's full legal name |
| phone_num | VARCHAR(20) | NULLABLE | POST /send-otp/, PATCH /profile/update/ | Phone in international format |
| phone_verified | BOOLEAN | DEFAULT: False | GET /profile/, POST /verify-otp/ | Phone verification status |
| otp_code | VARCHAR(6) | NULLABLE | POST /send-otp/, POST /verify-otp/ | Current OTP code |
| otp_expires_at | DATETIME | NULLABLE | Internal use only | OTP expiration timestamp |
| otp_attempts | INTEGER | DEFAULT: 0 | Internal use only | Failed OTP attempt count |
| otp_last_sent_at | DATETIME | NULLABLE | Internal use only | Last OTP sent timestamp |
| is_active | BOOLEAN | DEFAULT: True | GET /profile/ | Account active status |
| is_staff | BOOLEAN | DEFAULT: False | Internal use only | Admin access flag |
| is_superuser | BOOLEAN | DEFAULT: False | Internal use only | Superuser flag |
| date_joined | DATETIME | AUTO | GET /profile/ | Account creation timestamp |
| last_login | DATETIME | NULLABLE | GET /profile/ | Last login timestamp |

**API Endpoints:**
- `POST /api/auth/register/` - Create user (id, email, password, full_name, phone_num)
- `POST /api/auth/login/` - Authenticate (email, password) → returns (id, email, full_name, phone_num, phone_verified, date_joined, last_login)
- `POST /api/auth/logout/` - Blacklist token
- `POST /api/auth/token/refresh/` - Refresh access token
- `GET /api/auth/profile/` - Get profile (all fields except password, otp fields)
- `PATCH /api/auth/profile/update/` - Update (full_name, phone_num)
- `POST /api/auth/change-password/` - Update password
- `POST /api/auth/send-otp/` - Generate OTP (phone_num → otp_code, otp_expires_at, otp_attempts, otp_last_sent_at)
- `POST /api/auth/verify-otp/` - Verify OTP (phone_num, otp_code → phone_verified)
- `POST /api/auth/resend-otp/` - Resend OTP

**Indexes:**
- `email` (unique index)
- `phone_num` (index)

---

### 2. BloodType (bloodtype)
**API Base Path:** `/api/blood-types/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | INTEGER | PK, AUTO | GET /, GET /{id}/ | Primary key |
| code | VARCHAR(5) | UNIQUE, NOT NULL | GET /, GET /{id}/ | Blood type code (A+, B-, O, AB+) |
| name | VARCHAR(50) | NOT NULL | GET /, GET /{id}/ | Full name (A Positive, B Negative) |
| compatibility | JSON | NULLABLE | GET /{id}/ | Compatible blood types for donation |

**Reference Data:**
```python
('O-', 'O Negative')     - Universal donor
('O+', 'O Positive')
('A-', 'A Negative')
('A+', 'A Positive')
('B-', 'B Negative')
('B+', 'B Positive')
('AB-', 'AB Negative')
('AB+', 'AB Positive')   - Universal recipient
```

**API Endpoints:**
- `GET /api/blood-types/` - List all (id, code, name, compatibility)
- `GET /api/blood-types/{id}/` - Get details (all fields)

---

### 3. DonorProfile (donorprofile)
**API Base Path:** `/api/donor/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | GET /profile/, GET /profile/{id}/ | Primary key |
| user | UUID | FK(CustomUser), UNIQUE | GET /profile/, PUT /profile/ | Link to user account |
| blood_type | INTEGER | FK(BloodType), NULLABLE | PUT /profile/, GET /nearby/ | Donor's blood type |
| date_of_birth | DATE | NULLABLE | PUT /profile/ | Date of birth |
| gender | VARCHAR(20) | NULLABLE | PUT /profile/ | Gender (Male, Female, Other) |
| weight | FLOAT | NULLABLE | PUT /profile/ | Weight in kg |
| location_lat | FLOAT | NULLABLE | PATCH /location/, GET /nearby/ | Latitude for location |
| location_lng | FLOAT | NULLABLE | PATCH /location/, GET /nearby/ | Longitude for location |
| address | TEXT | NULLABLE | PUT /profile/, PATCH /location/ | Full address |
| city | VARCHAR(100) | NULLABLE | PUT /profile/, GET /nearby/ | City name |
| state | VARCHAR(100) | NULLABLE | PUT /profile/ | State/Province |
| country | VARCHAR(100) | NULLABLE | PUT /profile/ | Country |
| postal_code | VARCHAR(20) | NULLABLE | PUT /profile/ | ZIP/Postal code |
| is_available | BOOLEAN | DEFAULT: True | POST /toggle-availability/, GET /nearby/ | Availability for donation |
| last_donation_date | DATE | NULLABLE | GET /profile/, GET /nearby/ | Most recent donation date |
| total_donations | INTEGER | DEFAULT: 0 | Auto-updated by Donation create | Lifetime donation count |
| eligibility_verified | BOOLEAN | DEFAULT: False | GET /profile/, POST /health/quiz/submit/ | Health quiz completed |
| eligibility_valid_until | DATE | NULLABLE | GET /profile/, POST /health/quiz/submit/ | Eligibility expiration |
| created_at | DATETIME | AUTO | GET /profile/ | Profile creation timestamp |
| updated_at | DATETIME | AUTO | GET /profile/ | Last update timestamp |

**Relationships:**
- `user` → `CustomUser.id` (One-to-One)
- `blood_type` → `BloodType.id` (Many-to-One)

**API Endpoints:**
- `GET /api/donor/profile/` - Get my profile (all fields)
- `PUT /api/donor/profile/` - Create/update profile (blood_type, date_of_birth, gender, weight, address, city, state, country, postal_code)
- `PATCH /api/donor/profile/location/` - Update location (location_lat, location_lng, address)
- `POST /api/donor/profile/toggle-availability/` - Toggle availability (is_available)
- `GET /api/donor/nearby/?lat=&lng=&radius=&blood_type=` - Find nearby donors (filtered by blood_type, location, is_available)
- `GET /api/donor/profile/{id}/` - Get donor by ID (all fields except sensitive info)

**Indexes:**
- `user` (unique)
- `blood_type`
- `location_lat`, `location_lng` (composite)
- `is_available`
- `city`

---

### 4. BloodRequest (bloodrequest)
**API Base Path:** `/api/requests/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | All endpoints | Primary key |
| patient | UUID | FK(CustomUser) | POST /, GET /my/ | User who created request |
| blood_type | INTEGER | FK(BloodType) | POST /, GET /, PATCH /{id}/ | Required blood type |
| urgency | VARCHAR(20) | NOT NULL | POST /, GET /, PATCH /{id}/ | Urgency level (critical, high, normal) |
| units_needed | INTEGER | DEFAULT: 1 | POST /, PATCH /{id}/ | Number of units needed |
| hospital_name | VARCHAR(255) | NULLABLE | POST /, GET /{id}/ | Hospital name |
| hospital_address | TEXT | NULLABLE | POST /, GET /{id}/ | Hospital full address |
| hospital_lat | FLOAT | NULLABLE | POST /, GET /nearby/ | Hospital location latitude |
| hospital_lng | FLOAT | NULLABLE | POST /, GET /nearby/ | Hospital location longitude |
| contact_person | VARCHAR(255) | NULLABLE | POST /, GET /{id}/ | Contact person name |
| contact_phone | VARCHAR(20) | NULLABLE | POST /, GET /{id}/ | Contact phone number |
| diagnosis | VARCHAR(255) | NULLABLE | POST /, GET /{id}/ | Medical condition/reason |
| required_date | DATE | NULLABLE | POST /, GET / | Date blood needed by |
| status | VARCHAR(20) | DEFAULT: 'active' | GET /, POST /{id}/cancel/ | Status (active, fulfilled, cancelled, expired) |
| is_anonymous | BOOLEAN | DEFAULT: True | POST /, GET /{id}/ | Hide patient identity |
| views_count | INTEGER | DEFAULT: 0 | Auto-increment on GET /{id}/ | How many times viewed |
| created_at | DATETIME | AUTO | GET /, GET /{id}/ | Request creation timestamp |
| updated_at | DATETIME | AUTO | GET /{id}/ | Last update timestamp |
| fulfilled_at | DATETIME | NULLABLE | Auto-set when status=fulfilled | When request was fulfilled |

**Relationships:**
- `patient` → `CustomUser.id` (Many-to-One)
- `blood_type` → `BloodType.id` (Many-to-One)

**API Endpoints:**
- `POST /api/requests/` - Create request (all writable fields)
- `GET /api/requests/?page=&blood_type=&urgency=&status=&lat=&lng=&radius=` - List all with filters
- `GET /api/requests/my/?status=` - Get my requests
- `GET /api/requests/{id}/` - Get details (all fields, increment views_count)
- `PATCH /api/requests/{id}/` - Update (urgency, units_needed, required_date, hospital_name, hospital_address, contact_person, contact_phone)
- `POST /api/requests/{id}/cancel/` - Cancel request (status=cancelled)
- `GET /api/requests/nearby/?lat=&lng=&radius=&blood_type=` - Find nearby requests

**Indexes:**
- `patient`
- `blood_type`
- `status`
- `urgency`
- `required_date`
- `hospital_lat`, `hospital_lng` (composite)

---

### 5. Donation (donation)
**API Base Path:** `/api/donations/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | GET /{id}/, GET /{id}/certificate/ | Primary key |
| donor | UUID | FK(CustomUser) | POST /, GET /my/ | Donor user ID |
| blood_request | UUID | FK(BloodRequest), NULLABLE | POST /, GET /{id}/ | Link to request (if applicable) |
| blood_type | INTEGER | FK(BloodType) | POST /, GET /my/ | Donated blood type |
| units | INTEGER | DEFAULT: 1 | POST /, GET /my/ | Number of units donated |
| donation_date | DATE | NOT NULL | POST /, GET /my/ | Date of donation |
| donation_center | VARCHAR(255) | NULLABLE | POST /, GET /my/ | Center/hospital name |
| donation_center_address | TEXT | NULLABLE | POST /, GET /my/ | Center address |
| hemoglobin_level | FLOAT | NULLABLE | POST /, GET /{id}/ | Hemoglobin level (g/dL) |
| blood_pressure | VARCHAR(20) | NULLABLE | POST /, GET /{id}/ | Blood pressure reading |
| health_status | VARCHAR(50) | DEFAULT: 'good' | POST /, GET /{id}/ | Health status after donation |
| notes | TEXT | NULLABLE | POST /, GET /{id}/ | Additional notes |
| certificate_issued | BOOLEAN | DEFAULT: False | GET /{id}/, GET /{id}/certificate/ | Certificate sent to donor |
| created_at | DATETIME | AUTO | GET /{id}/ | Record creation timestamp |

**Relationships:**
- `donor` → `CustomUser.id` (Many-to-One)
- `blood_request` → `BloodRequest.id` (Many-to-One, Optional)
- `blood_type` → `BloodType.id` (Many-to-One)

**API Endpoints:**
- `POST /api/donations/` - Record donation (blood_request, blood_type, units, donation_date, donation_center, donation_center_address, hemoglobin_level, blood_pressure, health_status, notes)
- `GET /api/donations/my/?page=` - Get my donations (all fields)
- `GET /api/donations/{id}/` - Get details (all fields)
- `GET /api/donations/{id}/certificate/` - Generate certificate (returns certificate_url, donation_number)
- `GET /api/donations/stats/` - Get statistics (aggregated data)

**Indexes:**
- `donor`
- `blood_request`
- `blood_type`
- `donation_date`

---

### 6. SOSRequest (sosrequest)
**API Base Path:** `/api/sos/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | All endpoints | Primary key |
| requester | UUID | FK(CustomUser) | POST /, GET /{id}/ | User who created SOS |
| blood_type | INTEGER | FK(BloodType) | POST /, GET /active/ | Required blood type |
| patient_name | VARCHAR(255) | NULLABLE | POST /, GET /{id}/ | Patient name (if not anonymous) |
| hospital_name | VARCHAR(255) | NOT NULL | POST /, GET /active/, GET /{id}/ | Hospital name |
| hospital_address | TEXT | NOT NULL | POST /, GET /{id}/ | Hospital full address |
| hospital_lat | FLOAT | NOT NULL | POST /, GET /active/ | Hospital location latitude |
| hospital_lng | FLOAT | NOT NULL | POST /, GET /active/ | Hospital location longitude |
| contact_phone | VARCHAR(20) | NOT NULL | POST /, GET /{id}/ | Emergency contact |
| age | INTEGER | NULLABLE | POST /, GET /{id}/ | Patient age |
| gender | VARCHAR(20) | NULLABLE | POST /, GET /{id}/ | Patient gender |
| units_needed | INTEGER | DEFAULT: 1 | POST /, GET /{id}/ | Units required |
| status | VARCHAR(20) | DEFAULT: 'active' | GET /active/, POST /{id}/resolve/, POST /{id}/cancel/ | Status (active, responded, resolved, cancelled) |
| responders_count | INTEGER | DEFAULT: 0 | Auto-increment on POST /{id}/respond/ | Number of donor responses |
| created_at | DATETIME | AUTO | GET /active/, GET /{id}/ | SOS creation timestamp |
| resolved_at | DATETIME | NULLABLE | POST /{id}/resolve/ | When SOS was resolved |

**Relationships:**
- `requester` → `CustomUser.id` (Many-to-One)
- `blood_type` → `BloodType.id` (Many-to-One)

**API Endpoints:**
- `POST /api/sos/` - Create SOS (all writable fields except id, status, responders_count, created_at, resolved_at)
- `GET /api/sos/active/?lat=&lng=&radius=&blood_type=` - List active SOS (filtered by location, blood_type, status)
- `POST /api/sos/{id}/respond/` - Respond to SOS (increments responders_count)
- `GET /api/sos/{id}/` - Get details (all fields)
- `POST /api/sos/{id}/resolve/` - Resolve SOS (status=resolved, sets resolved_at)
- `POST /api/sos/{id}/cancel/` - Cancel SOS (status=cancelled)

**Indexes:**
- `requester`
- `blood_type`
- `status`
- `created_at`

---

### 7. Conversation (conversation)
**API Base Path:** `/api/messages/conversations/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | All endpoints | Primary key |
| participant1 | UUID | FK(CustomUser) | Auto-set on POST /send/ | First participant |
| participant2 | UUID | FK(CustomUser) | Auto-set on POST /send/ | Second participant |
| related_blood_request | UUID | FK(BloodRequest), NULLABLE | POST /send/, GET /{id}/ | Link to blood request |
| last_message_at | DATETIME | NULLABLE | Auto-updated on message send | Last activity timestamp |
| is_active | BOOLEAN | DEFAULT: True | GET /, DELETE /{id}/ | Conversation active status |
| created_at | DATETIME | AUTO | GET /{id}/ | Conversation start timestamp |

**Relationships:**
- `participant1` → `CustomUser.id` (Many-to-One)
- `participant2` → `CustomUser.id` (Many-to-One)
- `related_blood_request` → `BloodRequest.id` (Many-to-One, Optional)

**API Endpoints:**
- `GET /api/messages/conversations/` - List my conversations (id, other_participant, last_message, last_message_at, unread_count, related_request)
- `GET /api/messages/conversations/{id}/?page=` - Get messages in conversation
- `POST /api/messages/send/` - Send message (creates conversation if needed)
- `POST /api/messages/conversations/{id}/mark-read/` - Mark messages as read
- `DELETE /api/messages/conversations/{id}/` - Delete conversation (is_active=false)

**Indexes:**
- `participant1`
- `participant2`
- `related_blood_request`
- `last_message_at`

**Unique Constraint:**
- `(participant1, participant2)` - Prevent duplicate conversations

---

### 8. Message (message)
**API Base Path:** `/api/messages/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | GET /conversations/{id}/ | Primary key |
| conversation | UUID | FK(Conversation) | POST /send/, GET /conversations/{id}/ | Parent conversation |
| sender | UUID | FK(CustomUser) | POST /send/, GET /conversations/{id}/ | Message sender |
| content | TEXT | NOT NULL | POST /send/, GET /conversations/{id}/ | Message text content |
| is_read | BOOLEAN | DEFAULT: False | GET /conversations/{id}/, POST /conversations/{id}/mark-read/ | Read status |
| read_at | DATETIME | NULLABLE | POST /conversations/{id}/mark-read/ | When message was read |
| created_at | DATETIME | AUTO | GET /conversations/{id}/ | Message timestamp |

**Relationships:**
- `conversation` → `Conversation.id` (Many-to-One)
- `sender` → `CustomUser.id` (Many-to-One)

**API Endpoints:**
- `POST /api/messages/send/` - Create message (conversation_id or recipient_id + related_request_id + content)
- `GET /api/messages/conversations/{id}/?page=` - List messages (id, sender, content, is_read, created_at)
- `POST /api/messages/conversations/{id}/mark-read/` - Mark all as read (is_read=true, read_at=now)

**Indexes:**
- `conversation`
- `sender`
- `created_at`
- `is_read`

---

### 9. Notification (notification)
**API Base Path:** `/api/notifications/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | All endpoints | Primary key |
| recipient | UUID | FK(CustomUser) | Auto-set on create | Notification recipient |
| type | VARCHAR(50) | NOT NULL | GET /?type= | Notification type |
| title | VARCHAR(255) | NOT NULL | GET / | Notification title |
| message | TEXT | NOT NULL | GET / | Notification message |
| data | JSON | NULLABLE | GET / | Additional data payload |
| related_blood_request | UUID | FK(BloodRequest), NULLABLE | Auto-set on create | Link to related request |
| is_read | BOOLEAN | DEFAULT: False | GET /?is_read=, POST /{id}/mark-read/, POST /mark-all-read/ | Read status |
| read_at | DATETIME | NULLABLE | POST /{id}/mark-read/, POST /mark-all-read/ | When notification was read |
| created_at | DATETIME | AUTO | GET / | Notification timestamp |

**Relationships:**
- `recipient` → `CustomUser.id` (Many-to-One)
- `related_blood_request` → `BloodRequest.id` (Many-to-One, Optional)

**API Endpoints:**
- `GET /api/notifications/?page=&is_read=&type=` - List notifications (filtered by is_read, type)
- `POST /api/notifications/{id}/mark-read/` - Mark as read (is_read=true, read_at=now)
- `POST /api/notifications/mark-all-read/` - Mark all as read
- `DELETE /api/notifications/{id}/` - Delete notification
- `GET /api/notifications/preferences/` - Get preferences (separate model/table)
- `PATCH /api/notifications/preferences/` - Update preferences (separate model/table)

**Notification Types:**
- `blood_request_match` - New matching blood request
- `sos_alert` - Emergency blood request nearby
- `donation_reminder` - Eligible to donate again
- `message_received` - New chat message
- `request_fulfilled` - Blood request completed
- `achievement_earned` - Badge earned

**Indexes:**
- `recipient`
- `type`
- `is_read`
- `created_at`

---

### 10. Achievement (achievement)
**API Base Path:** `/api/achievements/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | INTEGER | PK, AUTO | GET /, GET /{id}/ | Primary key |
| code | VARCHAR(50) | UNIQUE, NOT NULL | GET /, GET /{id}/ | Achievement code |
| name | VARCHAR(100) | NOT NULL | GET /, GET /{id}/ | Achievement display name |
| description | TEXT | NULLABLE | GET /{id}/ | Achievement description |
| icon_url | VARCHAR(500) | NULLABLE | GET /, GET /{id}/ | Badge icon/image URL |
| category | VARCHAR(50) | NOT NULL | GET / | Category (donation, social, impact) |
| requirement_type | VARCHAR(50) | NOT NULL | Internal use only | Type of requirement |
| requirement_value | INTEGER | NOT NULL | Internal use only | Required value to unlock |
| points | INTEGER | DEFAULT: 0 | GET /, GET /my/ | Points awarded |
| sort_order | INTEGER | DEFAULT: 0 | GET / | Display order |
| is_active | BOOLEAN | DEFAULT: True | GET / | Achievement available |

**Achievement Examples:**
```python
('first_donation', 'First Drop', 'Made your first blood donation')
('five_donations', 'Regular Donor', 'Completed 5 donations')
('ten_donations', 'Hero', 'Completed 10 donations')
('savior', 'Savior', 'Helped save 3 lives')
('emergency_responder', 'Emergency Responder', 'Responded to 5 SOS requests')
```

**API Endpoints:**
- `GET /api/achievements/` - List all achievements (with user's earned status, progress)
- `GET /api/achievements/my/` - Get my achievements (earned_achievements, total_points, next_achievement)
- `GET /api/achievements/{id}/` - Get details (all fields)

---

### 11. UserAchievement (userachievement)
**API Base Path:** `/api/achievements/` (included in my achievements response)

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | GET /my/ | Primary key |
| user | UUID | FK(CustomUser) | Auto-set on achievement unlock | User who earned achievement |
| achievement | INTEGER | FK(Achievement) | Auto-set on achievement unlock | Achievement earned |
| earned_at | DATETIME | AUTO | GET /my/ | When achievement was earned |
| progress | INTEGER | DEFAULT: 0 | Auto-updated, GET / | Progress toward achievement |

**Relationships:**
- `user` → `CustomUser.id` (Many-to-One)
- `achievement` → `Achievement.id` (Many-to-One)

**API Endpoints:**
- Achievements are auto-created when:
  - Donation is recorded → checks donation_count achievements
  - SOS is responded → checks sos_response_count achievements
  - Request is fulfilled → checks lives_saved achievements
- `GET /api/achievements/` - Includes progress field from this table
- `GET /api/achievements/my/` - Returns earned achievements from this table

**Indexes:**
- `user`
- `achievement`
- `earned_at`

**Unique Constraint:**
- `(user, achievement)` - One entry per achievement per user

---

### 12. HealthEligibilityResponse (healtheligibilityresponse)
**API Base Path:** `/api/health/`

| Column | Type | Constraints | API Endpoints | Description |
|--------|------|-------------|---------------|-------------|
| id | UUID | PK, AUTO | Internal use | Primary key |
| user | UUID | FK(CustomUser) | Auto-set on submit | User who took quiz |
| responses | JSON | NOT NULL | POST /quiz/submit/ | Quiz answers |
| is_eligible | BOOLEAN | NOT NULL | POST /quiz/submit/, GET /eligibility/ | Eligibility result |
| ineligibility_reasons | JSON | NULLABLE | POST /quiz/submit/ | Reasons for ineligibility |
| quiz_version | VARCHAR(20) | NULLABLE | GET /quiz/ | Quiz version identifier |
| created_at | DATETIME | AUTO | GET /eligibility/ | Quiz completion timestamp |

**Relationships:**
- `user` → `CustomUser.id` (Many-to-One)

**API Endpoints:**
- `GET /api/health/quiz/` - Get quiz questions (returns quiz_version, questions)
- `POST /api/health/quiz/submit/` - Submit quiz (creates record, updates DonorProfile.eligibility_verified, eligibility_valid_until)
- `GET /api/health/eligibility/` - Check status (returns is_eligible, valid_until, days_until_expiry, last_quiz_date from latest record)

**Indexes:**
- `user`
- `created_at`
- `is_eligible`

---

## 📐 Database Constraints

### Foreign Key Relationships

```
CustomUser (1) ──────< (0..1) DonorProfile
                    └──────< (0..n) BloodRequest
                    └──────< (0..n) Donation (as donor)
                    └──────< (0..n) SOSRequest
                    └──────< (0..n) Conversation (as participant1)
                    └──────< (0..n) Conversation (as participant2)
                    └──────< (0..n) Message (as sender)
                    └──────< (0..n) Notification (as recipient)
                    └──────< (0..n) UserAchievement
                    └──────< (0..n) HealthEligibilityResponse

BloodType (1) ────────< (0..n) DonorProfile
                    └──────< (0..n) BloodRequest
                    └──────< (0..n) Donation
                    └──────< (0..n) SOSRequest

BloodRequest (1) ─────< (0..n) Donation
                    └──────< (0..1) Conversation

Conversation (1) ─────< (0..n) Message

Achievement (1) ─────< (0..n) UserAchievement
```

---

## 🔍 Database Indexes Summary

| Table | Indexed Columns | Purpose | API Endpoints Used |
|-------|------------------|---------|-------------------|
| account_customuser | email, phone_num | Auth lookups | /auth/register/, /auth/login/, /auth/send-otp/ |
| donorprofile | user, blood_type, location, city | Donor search | /donor/profile/, /donor/nearby/ |
| bloodrequest | patient, blood_type, status, urgency | Request filtering | /requests/, /requests/my/, /requests/nearby/ |
| donation | donor, blood_request, donation_date | Donation history | /donations/my/, /donations/stats/ |
| sosrequest | requester, blood_type, status, created_at | Emergency filtering | /sos/active/, /sos/{id}/ |
| conversation | participants, last_message_at | Chat lookups | /messages/conversations/ |
| message | conversation, sender, created_at | Message retrieval | /messages/conversations/{id}/ |
| notification | recipient, type, is_read | Notification queries | /notifications/ |
| userachievement | user, achievement | User badges | /achievements/my/ |

---

## 📊 Database Size Estimates (Approximate)

**Per User Storage:**
- User record: ~500 bytes
- Donor profile: ~800 bytes
- Donations: ~400 bytes each
- Messages: ~300 bytes each

**Scaling Estimates:**
- 1,000 users: ~2 MB
- 10,000 users: ~20 MB
- 100,000 users: ~200 MB
- With messages/donations: ~1-5 GB per 100K users

---

## 🛠️ Migration Order

1. `account` migrations (existing)
2. `BloodType` model
3. `DonorProfile` model (depends on User, BloodType)
4. `BloodRequest` model (depends on User, BloodType)
5. `Donation` model (depends on User, BloodRequest, BloodType)
6. `SOSRequest` model (depends on User, BloodType)
7. `Conversation` model (depends on User, BloodRequest)
8. `Message` model (depends on Conversation, User)
9. `Notification` model (depends on User, BloodRequest)
10. `Achievement` model
11. `UserAchievement` model (depends on User, Achievement)
12. `HealthEligibilityResponse` model (depends on User)

---

## 📝 Notes

- All UUID primary keys use Django's default UUID field
- Timestamps use Django's `auto_now_add` and `auto_now`
- Soft deletes can be added by using `is_active` flags
- For PostgreSQL, consider adding `pg_trgm` extension for text search
- For MySQL, use `InnoDB` engine for foreign key support
- Location-based queries should use PostGIS (PostgreSQL) or calculate distances in application

---

**Last Updated:** 2026-06-05
**Django Version:** 5.2.3
**Database Engine:** SQLite (dev) / MySQL or PostgreSQL (production)
