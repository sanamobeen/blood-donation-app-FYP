# LifeDrop - Blood Donation Platform
## Complete Project Documentation

---

## Executive Summary

**LifeDrop** is a full-stack blood donation platform built with Django REST Framework backend and Flutter mobile frontend, designed to bridge the critical gap between blood donors and patients in need. The platform enables real-time connection between donors and patients based on blood type compatibility and geographic proximity, with emergency SOS capabilities for urgent blood requirements. Key features include secure JWT-based authentication with OTP phone verification, comprehensive health eligibility screening through an interactive quiz, blood request management with donor pledging system, donation tracking with digital certificates, and Firebase-powered real-time chat between donors and patients. The application leverages location services for nearby donor discovery and SOS alert broadcasting, while maintaining robust security through token rotation, rate limiting, and encrypted password storage. With support for both donors and patients, the platform tracks donation history, manages 56-day eligibility waiting periods, and provides statistical dashboards for impact visualization. The backend is deployable on any cloud infrastructure with MySQL/PostgreSQL databases, while the Flutter app supports both Android and iOS platforms with Firebase integration for chat functionality.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Django Backend](#django-backend)
6. [Flutter Mobile App](#flutter-mobile-app)
7. [Database Schema](#database-schema)
8. [API Endpoints](#api-endpoints)
9. [Firebase Integration](#firebase-integration)
10. [Key Features](#key-features)
11. [Authentication & Security](#authentication--security)
12. [Development Setup](#development-setup)
13. [Production Deployment](#production-deployment)
14. [Testing](#testing)

---

## Project Overview

**LifeDrop** is a comprehensive blood donation platform designed to connect blood donors with patients in need. The platform consists of a Django REST API backend and a Flutter mobile application.

### Core Purpose
- **Connect donors and patients** in real-time based on blood type and location
- **Emergency SOS requests** for critical blood needs
- **Health eligibility screening** through an interactive quiz
- **Donation tracking** with certificates and acknowledgments
- **Real-time chat** between donors and patients via Firebase
- **Location-based search** for nearby donors and requests

### Target Users
1. **Donors** - Individuals willing to donate blood
2. **Patients** - Individuals or representatives seeking blood donations

---

## Architecture

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         LifeDrop Platform                        │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│  Flutter Mobile  │◄────────►│  Django REST API │◄────────►│   MySQL/SQLite    │
│      App         │         │     Backend      │         │    Database       │
└──────────────────┘         └──────────────────┘         └──────────────────┘
         │                           │
         │                           │
         ▼                           ▼
┌──────────────────┐         ┌──────────────────┐
│   Firebase Cloud │         │    Twilio SMS    │
│    Firestore     │         │     Service      │
│    (Chat)        │         │    (Optional)    │
└──────────────────┘         └──────────────────┘
```

### Communication Flow

1. **Authentication**: Flutter → Django (JWT tokens)
2. **API Requests**: Flutter → Django → Database
3. **Real-time Chat**: Flutter ↔ Firebase Firestore (bidirectional)
4. **SMS OTP**: Django → Twilio → User Phone
5. **Email**: Django SMTP → User Email

---

## Technology Stack

### Backend (Django)

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Django | 5.2.3 |
| API | Django REST Framework | 3.15.2 |
| Authentication | JWT (Simple JWT) | 5.5.0 |
| CORS | django-cors-headers | 4.6.0 |
| Database | MySQL / SQLite | mysqlclient 2.2.4 |
| SMS | Twilio / Firebase | 9.0.0 / 6.5.0 |
| Rate Limiting | django-ratelimit | 4.1.0 |
| Filtering | django-filter | 24.3 |
| Environment | python-dotenv | 1.0.1 |

### Frontend (Flutter)

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Flutter SDK | ^3.12.0 |
| Language | Dart | ^3.12.0 |
| HTTP | http package | ^1.2.0 |
| Storage | shared_preferences | ^2.2.2 |
| Images | image_picker | ^1.0.7 |
| Location | geolocator | ^12.0.0 |
| Deep Links | app_links | ^7.1.1 |
| Firebase | firebase_core, cloud_firestore, firebase_auth | ^5.0.0 |
| State | provider | ^6.1.0 |
| Dates | intl | ^0.19.0 |

---

## Project Structure

### Root Directory

```
/Blood-Donation/
├── django-backend/          # Django REST API backend
├── flutter-project/          # Flutter mobile application
├── API_ENDPOINTS.md          # API documentation
├── DATABASE_SCHEMA.md        # Database schema documentation
└── PROJECT_OVERVIEW.md      # Project overview
```

### Django Backend Structure

```
django-backend/
├── backend/                  # Main Django project
│   ├── settings.py          # Configuration
│   ├── urls.py              # Root URL routing
│   ├── wsgi.py              # WSGI configuration
│   └── asgi.py              # ASGI configuration
│
├── account/                 # User authentication & profiles
│   ├── models.py            # CustomUser, UserProfile, PasswordReset
│   ├── views.py             # Auth endpoints
│   ├── serializers.py       # Data serialization
│   └── urls.py              # Account routes
│
├── blood_requests/          # Blood request management
│   ├── models.py            # BloodRequest, DonorResponse
│   ├── views.py             # Request endpoints
│   ├── serializers.py       # Request serialization
│   └── urls.py              # Request routes
│
├── blood_types/             # Blood type reference data
│   ├── models.py            # BloodType model
│   ├── views.py             # Blood type endpoints
│   └── urls.py              # Blood type routes
│
├── donations/               # Donation records & certificates
│   ├── models.py            # Donation, Certificate models
│   ├── views.py             # Donation endpoints
│   └── urls.py              # Donation routes
│
├── sos/                     # Emergency SOS requests
│   ├── models.py            # SOSRequest, SOSResponse
│   ├── views.py             # SOS endpoints
│   └── urls.py              # SOS routes
│
├── stats/                   # Statistics & analytics
│   ├── models.py            # Statistics models
│   ├── views.py             # Stats endpoints
│   └── urls.py              # Stats routes
│
├── health/                  # Health eligibility quiz
│   ├── models.py            # Health quiz models
│   ├── views.py             # Quiz endpoints
│   └── urls.py              # Quiz routes
│
├── requirements.txt          # Python dependencies
├── manage.py                # Django management
├── .env                     # Environment variables
├── .env.example             # Environment template
└── db.sqlite3               # SQLite database (development)
```

### Flutter App Structure

```
flutter-project/flutter_app/
├── lib/
│   ├── main.dart            # App entry point
│   ├── app.dart             # Root widget with deep linking
│   ├── app_routes.dart      # Route definitions
│   │
│   ├── config/              # Configuration
│   │   └── api_config.dart  # API endpoints
│   │
│   ├── models/              # Data models
│   │   ├── blood_request.dart
│   │   ├── chat_conversation.dart
│   │   ├── chat_message.dart
│   │   ├── donation_response.dart
│   │   ├── donor_pledge.dart
│   │   ├── notification.dart
│   │   ├── profile.dart
│   │   ├── sos_request.dart
│   │   └── statistics.dart
│   │
│   ├── services/            # Business logic
│   │   ├── api_service.dart         # API client
│   │   └── firebase_chat_service.dart # Chat service
│   │
│   ├── screens/             # UI Screens
│   │   ├── auth/            # Authentication
│   │   │   ├── login_screen.dart
│   │   │   ├── sign_up_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   ├── reset_password_screen.dart
│   │   │   └── profile_setup_screen.dart
│   │   │
│   │   ├── onboarding/      # Onboarding screens
│   │   │   ├── onboarding_screen.dart
│   │   │   ├── onboarding_screen_2.dart
│   │   │   └── onboarding_screen3.dart
│   │   │
│   │   ├── blood_request/   # Blood request screens
│   │   │   └── blood_request_form_screen.dart
│   │   │
│   │   ├── chat/            # Firebase Chat
│   │   │   ├── chat_list_screen.dart
│   │   │   └── chat_conversation_screen.dart
│   │   │
│   │   ├── donations/       # Donation management
│   │   │   ├── my_donations_screen.dart
│   │   │   └── donation_certificate_screen.dart
│   │   │
│   │   ├── donors/          # Donor search
│   │   │   ├── donor_profile_screen.dart
│   │   │   ├── find_donors_screen.dart
│   │   │   └── nearby_donors_map_screen.dart
│   │   │
│   │   ├── notifications/   # Notifications
│   │   │   └── notifications_screen.dart
│   │   │
│   │   ├── quiz/            # Health eligibility
│   │   │   └── health_eligibility_quiz_screen.dart
│   │   │
│   │   ├── requests/        # Blood request management
│   │   │   ├── blood_request_detail_screen.dart
│   │   │   ├── my_requests_screen.dart
│   │   │   └── nearby_requests_screen.dart
│   │   │
│   │   ├── sos/             # Emergency SOS
│   │   │   ├── sos_screen.dart
│   │   │   └── sos_active_screen.dart
│   │   │
│   │   ├── home/            # Home screens
│   │   │   └── home_screen.dart
│   │   │
│   │   ├── profile/         # User profile
│   │   │   └── profile_screen.dart
│   │   │
│   │   ├── settings/        # App settings
│   │   │   └── settings_screen.dart
│   │   │
│   │   ├── splash/          # Splash screen
│   │   │   └── splash_screen.dart
│   │   │
│   │   └── role_selection/  # Role selection
│   │       └── role_selection_screen.dart
│   │
│   └── theme/               # App theming
│       └── app_theme.dart
│
├── android/                 # Android-specific code
├── ios/                     # iOS-specific code
├── pubspec.yaml             # Dart dependencies
└── FIREBASE_SETUP.md        # Firebase configuration guide
```

---

## Django Backend

### Custom User Model

The application uses a custom user model (`CustomUser`) that extends Django's `AbstractUser`:

#### CustomUser Model

```python
class CustomUser(AbstractUser):
    id = UUIDField (primary_key)
    email = EmailField (unique, indexed)
    full_name = CharField
    phone_num = CharField (validated with regex)
    phone_verified = BooleanField (default=False)
    otp_code = CharField (6-digit, nullable)
    otp_expires_at = DateTimeField
    otp_attempts = IntegerField (default=0)
    otp_last_sent_at = DateTimeField
    role = CharField (choices: 'donor', 'patient')
    is_active = BooleanField (default=True)
```

**Key Methods:**
- `generate_otp()` - Generates 6-digit OTP with 10-minute expiry
- `verify_otp(code)` - Validates OTP with attempt limiting (max 3)
- `can_request_otp()` - Enforces 60-second resend cooldown
- `clear_otp()` - Clears OTP data after successful verification

#### UserProfile Model

```python
class UserProfile(models.Model):
    user = OneToOneField(CustomUser)
    profile_picture = ImageField (upload_to='profile_pictures/')
    blood_group = CharField (choices: A+, A-, B+, B-, AB+, AB-, O+, O-)
    date_of_birth = DateField
    gender = CharField (choices: male, female, other, prefer_not_to_say)
    weight = DecimalField (kg, 5 digits, 2 decimal places)
    
    # Location
    location_lat = DecimalField (9 digits, 6 decimal places)
    location_lng = DecimalField (9 digits, 6 decimal places)
    address = TextField
    city = CharField
    state = CharField
    country = CharField (default: 'Pakistan')
    postal_code = CharField
    
    # Donation info
    is_available_for_donation = BooleanField (default: True)
    last_donation_date = DateField
    total_donations = IntegerField (default: 0)
    eligibility_verified = BooleanField (default: False)
    eligibility_valid_until = DateField
```

**Computed Properties:**
- `is_eligible` - Returns True if user can donate (56-day waiting period)
- `next_eligible_date` - Date when next donation is allowed
- `profile_completion_percentage` - Calculated completion status
- `profile_completed` - Boolean if profile is 100% complete

### JWT Authentication Configuration

```python
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'ALGORITHM': 'HS256',
    'AUTH_HEADER_TYPES': ('Bearer',),
}
```

---

## Flutter Mobile App

### App Routes

```dart
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const roleSelection = '/role-selection';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
  static const sos = '/sos';
  static const sosActive = '/sos-active';
  static const findDonors = '/find-donors';
  static const myRequests = '/my-requests';
  static const chatList = '/chat-list';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const patientHome = '/patient-home';
  static const bloodRequestForm = '/blood-request-form';
  static const healthEligibilityQuiz = '/health-eligibility-quiz';
  static const settings = '/settings';
}
```

### Deep Linking

The app supports deep linking for password reset:
- **Scheme**: `blooddonation://`
- **Route**: `/reset-password?email={email}&token={token}`

Deep links are handled in `app.dart` using the `app_links` package.

### API Service

The `ApiService` class (`lib/src/services/api_service.dart`) provides:

**Token Management:**
- `getAccessToken()` / `getRefreshToken()`
- `saveTokens()` / `clearTokens()`
- `_refreshAccessToken()` - Automatic token refresh

**Authentication:**
- `login(email, password)`
- `register(email, password, fullName, phoneNum, role)`
- `logout()`
- `sendOtp(phoneNum)` / `verifyOtp(phoneNum, otpCode)`

**Password Reset:**
- `forgotPassword(email)`
- `resetPassword(token, email, newPassword, confirm)`

**Profile:**
- `createProfile(bloodGroup, dateOfBirth, ...)`
- `getProfile()`
- `updateProfile()`

**Blood Requests:**
- `getBloodRequests(filters)`
- `createBloodRequest(...)`
- `getBloodRequestDetail(requestId)`
- `getMyBloodRequests(status)`
- `cancelBloodRequest(requestId)`

**Pledges:**
- `createPledge(requestId, unitsPledged, ...)`
- `getRequestPledges(requestId)`
- `getRequestProgress(requestId)`

**SOS:**
- `createSosRequest(...)`
- `getActiveSosRequests(lat, lng, radius)`
- `respondToSos(sosId, canHelp, ...)`
- `resolveSos(sosId, resolutionNote)`

**Donations:**
- `createDonationForRequest(...)`
- `acknowledgeDonation(donationId)`
- `getDonationCertificate(donationId)`

---

## Database Schema

### Core Models

#### CustomUser
```sql
CREATE TABLE account_customuser (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone_num VARCHAR(20),
    phone_verified BOOLEAN DEFAULT FALSE,
    otp_code VARCHAR(6),
    otp_expires_at DATETIME,
    otp_attempts INT DEFAULT 0,
    otp_last_sent_at DATETIME,
    role VARCHAR(20), -- 'donor' or 'patient'
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customuser_email ON account_customuser(email);
CREATE INDEX idx_customuser_phone ON account_customuser(phone_num);
```

#### UserProfile
```sql
CREATE TABLE account_userprofile (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES account_customuser(id),
    profile_picture VARCHAR(255),
    blood_group VARCHAR(5), -- A+, A-, B+, B-, AB+, AB-, O+, O-
    date_of_birth DATE,
    gender VARCHAR(20), -- male, female, other, prefer_not_to_say
    weight DECIMAL(5,2), -- kg
    location_lat DECIMAL(9,6),
    location_lng DECIMAL(9,6),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Pakistan',
    postal_code VARCHAR(20),
    is_available_for_donation BOOLEAN DEFAULT TRUE,
    last_donation_date DATE,
    total_donations INT DEFAULT 0,
    eligibility_verified BOOLEAN DEFAULT FALSE,
    eligibility_valid_until DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

CREATE INDEX idx_userprofile_blood_group ON account_userprofile(blood_group);
CREATE INDEX idx_userprofile_city ON account_userprofile(city);
CREATE INDEX idx_userprofile_location ON account_userprofile(location_lat, location_lng);
```

#### BloodRequest
```sql
CREATE TABLE blood_requests_bloodrequest (
    id UUID PRIMARY KEY,
    patient_name VARCHAR(255) NOT NULL,
    blood_group VARCHAR(5) NOT NULL, -- A+, A-, B+, B-, AB+, AB-, O+, O-
    units_needed INT NOT NULL,
    urgency_level VARCHAR(20) DEFAULT 'normal', -- critical, urgent, normal
    contact_number VARCHAR(20) NOT NULL,
    additional_notes TEXT,
    hospital_name VARCHAR(255),
    location VARCHAR(255),
    requested_by_id UUID REFERENCES account_customuser(id),
    status VARCHAR(20) DEFAULT 'pending', -- pending, fulfilled, cancelled
    is_active BOOLEAN DEFAULT TRUE,
    units_pledged INT DEFAULT 0,
    units_received INT DEFAULT 0,
    responders_count INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bloodrequest_blood_group ON blood_requests_bloodrequest(blood_group);
CREATE INDEX idx_bloodrequest_urgency ON blood_requests_bloodrequest(urgency_level);
CREATE INDEX idx_bloodrequest_status ON blood_requests_bloodrequest(status);
CREATE INDEX idx_bloodrequest_created ON blood_requests_bloodrequest(created_at DESC);
```

#### DonorResponse (Pledge)
```sql
CREATE TABLE blood_requests_donorresponse (
    id UUID PRIMARY KEY,
    blood_request_id UUID REFERENCES blood_requests_bloodrequest(id),
    donor_id UUID REFERENCES account_customuser(id),
    units_pledged INT DEFAULT 1,
    preferred_date DATE,
    note TEXT,
    status VARCHAR(20) DEFAULT 'pledged', -- pledged, donated, cancelled
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    donated_at DATETIME
);

CREATE INDEX idx_donorresponse_request ON blood_requests_donorresponse(blood_request_id, status);
CREATE INDEX idx_donorresponse_donor ON blood_requests_donorresponse(donor_id, status);
```

#### SOSRequest
```sql
CREATE TABLE sos_sosrequest (
    id UUID PRIMARY KEY,
    requester_id UUID REFERENCES account_customuser(id),
    blood_type VARCHAR(5) NOT NULL,
    patient_name VARCHAR(255) NOT NULL,
    age INT NOT NULL,
    gender VARCHAR(20) NOT NULL, -- male, female, other
    hospital_name VARCHAR(255) NOT NULL,
    hospital_address TEXT NOT NULL,
    hospital_lat DECIMAL(9,6),
    hospital_lng DECIMAL(9,6),
    contact_phone VARCHAR(20) NOT NULL,
    units_needed INT DEFAULT 1,
    status VARCHAR(20) DEFAULT 'active', -- active, resolved, cancelled
    responders_count INT DEFAULT 0,
    resolution_note TEXT,
    resolved_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sos_blood_type ON sos_sosrequest(blood_type);
CREATE INDEX idx_sos_status ON sos_sosrequest(status);
CREATE INDEX idx_sos_location ON sos_sosrequest(hospital_lat, hospital_lng);
```

#### Donation
```sql
CREATE TABLE donations_donation (
    id UUID PRIMARY KEY,
    donor_id UUID REFERENCES account_customuser(id),
    blood_request_id UUID REFERENCES blood_requests_bloodrequest(id),
    blood_type_id INT,
    units INT DEFAULT 1,
    donation_date DATE NOT NULL,
    donation_center VARCHAR(255),
    donation_center_address TEXT,
    hemoglobin_level FLOAT,
    blood_pressure VARCHAR(20),
    health_status VARCHAR(50),
    notes TEXT,
    certificate_number VARCHAR(50) UNIQUE,
    certificate_issued BOOLEAN DEFAULT FALSE,
    acknowledged_by_patient BOOLEAN DEFAULT FALSE,
    acknowledged_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_donation_donor_date ON donations_donation(donor_id, donation_date DESC);
CREATE INDEX idx_donation_request ON donations_donation(blood_request_id);
```

#### PasswordReset
```sql
CREATE TABLE account_passwordreset (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id UUID REFERENCES account_customuser(id),
    token UUID UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_used BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_passwordreset_token ON account_passwordreset(token);
CREATE INDEX idx_passwordreset_user_used ON account_passwordreset(user_id, is_used);
```

### Firebase Collections (Chat)

The chat system uses Firebase Cloud Firestore with the following structure:

#### conversations
```javascript
{
  id: "conv_{requestId}_{patientId}_{donorId}",
  request_id: "uuid",
  participant1_id: "uuid",
  participant1_name: "string",
  participant1_role: "patient",
  participant2_id: "uuid",
  participant2_name: "string",
  participant2_role: "donor",
  unread_count: 0,
  is_active: true,
  updated_at: timestamp,
  created_at: timestamp,
  last_message: { ... } // ChatMessage object
}
```

#### messages (subcollection of conversations)
```javascript
{
  id: "auto-generated",
  conversation_id: "uuid",
  sender_id: "uuid",
  sender_name: "string",
  sender_avatar: "url?",
  text: "message content",
  type: "text | system",
  timestamp: timestamp,
  is_read: boolean,
  receiver_id: "uuid?"
}
```

---

## API Endpoints

### Authentication (`/api/auth/`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/register/` | Register new user | No |
| POST | `/login/` | Login with email/password | No |
| POST | `/logout/` | Logout user | Yes |
| POST | `/send-otp/` | Send OTP to phone | No |
| POST | `/verify-otp/` | Verify OTP code | No |
| POST | `/forgot-password/` | Request password reset | No |
| POST | `/reset-password/` | Reset password with token | No |
| GET | `/profile/detail/` | Get user profile | Yes |
| POST | `/profile/create/` | Create user profile | Yes |
| PATCH | `/profile/update/full/` | Update full profile | Yes |
| DELETE | `/profile/delete/` | Delete user profile | Yes |
| POST | `/donor/toggle-availability/` | Toggle donation availability | Yes |
| PATCH | `/donor/update-location/` | Update donor location | Yes |
| GET | `/donors/` | Get all donors (filtered) | No |
| GET | `/donors/nearby/` | Get nearby donors | No |

### Blood Requests (`/api/blood-requests/`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/` | List all blood requests | No |
| POST | `/create/` | Create new blood request | Yes |
| GET | `/{id}/` | Get request details | No |
| PATCH | `/{id}/update/` | Update request | Yes |
| POST | `/{id}/cancel/` | Cancel request | Yes |
| DELETE | `/{id}/delete/` | Soft delete request | Yes |
| GET | `/my-requests/` | Get user's requests | Yes |
| GET | `/nearby/` | Get nearby requests | No |
| POST | `/{id}/pledge/` | Pledge to donate | Yes |
| GET | `/{id}/pledges/` | Get request pledges | No |
| GET | `/{id}/progress/` | Get request progress | No |
| POST | `/pledges/{id}/cancel/` | Cancel pledge | Yes |
| GET | `/donor-eligibility/` | Check donor eligibility | Yes |

### SOS Emergency (`/api/sos/`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/` | Create SOS request | Yes |
| GET | `/{id}/` | Get SOS details | Yes |
| GET | `/active/` | Get active SOS nearby | No |
| POST | `/{id}/respond/` | Respond to SOS | Yes |
| POST | `/{id}/resolve/` | Mark SOS as resolved | Yes |
| POST | `/{id}/cancel/` | Cancel SOS | Yes |

### Donations (`/api/donations/`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/` | Record donation | Yes |
| GET | `/my/` | Get my donations | Yes |
| GET | `/{id}/certificate/` | Get donation certificate | Yes |
| POST | `/{id}/acknowledge` | Acknowledge donation | Yes |
| GET | `/request-responses/{requestId}/` | Get request donors | Yes |

### Blood Types (`/api/blood-types/`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/` | Get all blood types | No |

### Statistics (`/api/stats/`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/public/` | Get public statistics | No |
| GET | `/user/` | Get user statistics | Yes |

### Health (`/api/health/`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/quiz/` | Get health eligibility quiz | Yes |
| POST | `/quiz/submit/` | Submit quiz responses | Yes |
| GET | `/eligibility/` | Check eligibility status | Yes |

---

## Firebase Integration

### Firebase Chat Service

The chat functionality is implemented using Firebase Cloud Firestore, allowing real-time messaging between donors and patients.

#### FirebaseChatService Class

```dart
class FirebaseChatService {
  // Initialization
  static Future<void> initialize()
  
  // Conversations
  Future<ChatConversation> getOrCreateConversation({
    required String requestId,
    required String patientId,
    required String patientName,
    required String donorId,
    required String donorName,
  })
  
  // Messages
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    String? receiverId,
  })
  
  Future<void> sendSystemMessage({
    required String conversationId,
    required String text,
  })
  
  // Streams
  Stream<List<ChatMessage>> getMessagesStream(String conversationId)
  Stream<List<ChatConversation>> getUserConversationsStream()
  
  // Utilities
  Future<void> markMessagesAsRead({...})
  Future<void> updateUnreadCount({...})
  Future<void> archiveConversation(String conversationId)
}
```

#### Conversation ID Generation

```
conv_{requestId}_{sortedPatientId}_{sortedDonorId}
```

This ensures both parties get the same conversation ID regardless of who initiates.

#### Collections Structure

1. **conversations** - Top-level collection
   - Document ID: `{conversationId}`
   - Fields: participant info, timestamps, unread count

2. **messages** - Subcollection under each conversation
   - Document ID: Auto-generated
   - Fields: sender info, content, timestamp, read status

---

## Key Features

### 1. User Registration & Authentication

**Flow:**
1. User enters email, password, full name, phone number
2. System creates `CustomUser` account
3. System sends 6-digit OTP via SMS (Twilio) or logs to console (dev)
4. User verifies OTP → `phone_verified = True`
5. JWT access token (60 min) and refresh token (7 days) issued
6. Tokens stored in Flutter secure storage

**Security Features:**
- Password confirmation required
- Phone validation with regex
- OTP expires after 10 minutes
- Max 3 OTP attempts
- 60-second resend cooldown
- JWT token rotation on refresh

### 2. Profile Setup

**Required Fields:**
- Blood group (A+, A-, B+, B-, AB+, AB-, O+, O-)
- Date of birth
- Gender
- Weight
- City
- Country (default: Pakistan)

**Optional Fields:**
- Profile picture
- State/Province
- Postal code
- Full address
- GPS coordinates (latitude, longitude)

**Completion Tracking:**
- `profile_completion_percentage` - 0-100% based on filled fields
- Users must complete profile before donating

### 3. Blood Requests

**Request Lifecycle:**
```
Created → Pending → Pledged → Donated → Fulfilled
                 ↓
              Cancelled
```

**Fields:**
- Patient name
- Blood group required
- Units needed
- Urgency level (critical, urgent, normal)
- Contact number
- Hospital name & location
- Additional notes

**Progress Tracking:**
- `units_pledged` - Total pledged by donors
- `units_received` - Total actually donated
- `responders_count` - Number of unique donors
- `units_remaining` - Calculated: `units_needed - units_pledged`

### 4. Donor Pledges

Donors can pledge to donate to specific requests:

**Pledge Status:**
- `pledged` - Initial commitment
- `donated` - Confirmed donation
- `cancelled` - Pledge cancelled

**Pledge Details:**
- Number of units pledged
- Preferred donation date
- Note to patient

### 5. SOS Emergency Requests

**For critical situations requiring immediate blood:**

**Urgency Levels:**
- `critical` - Immediate attention needed
- `urgent` - Within 2 hours

**Request Details:**
- Blood type
- Patient name, age, gender
- Hospital name, address, coordinates
- Emergency contact
- Units needed

**Response System:**
- Donors nearby notified
- Responders indicate if they can help
- Estimated arrival time collected
- Request marked resolved when fulfilled

### 6. Health Eligibility Quiz

**Interactive screening quiz:**
- Covers medical history, medications, lifestyle
- Results determine eligibility
- Eligibility valid until next donation date + 56 days
- Re-quiz required after each donation

**Key Questions Include:**
- Recent tattoos/piercings
- Medical conditions
- Medications taken
- Travel history
- Sexual activity history
- Drug use

### 7. Donation Records

**Tracked Information:**
- Donor ID
- Blood request (if applicable)
- Blood type donated
- Units donated
- Donation date
- Donation center
- Health metrics (hemoglobin, blood pressure)
- Certificate number
- Patient acknowledgment status

**Certificate Generation:**
- Format: `DN-{YEAR}-{RANDOM}`
- Generated after donation
- Patient acknowledgment required
- Downloadable from app

### 8. Real-time Chat

**Firebase Cloud Firestore-based:**

**Features:**
- Real-time message delivery
- Read receipts
- Typing indicators (future)
- Image sharing (future)
- Conversation archiving
- System messages (pledge notifications)

**Chat Initiated When:**
1. Donor pledges to request
2. Patient accepts pledge
3. System sends introduction message

### 9. Location Services

**Features:**
- GPS-based donor search
- Radius-based filtering (default 50km)
- Manual location entry option
- Nearby blood requests
- Nearby SOS alerts

**Coordinate Format:**
- Latitude: 9 digits, 6 decimal places
- Longitude: 9 digits, 6 decimal places

### 10. Notifications

**Notification Types:**
- Pledge received
- Donation acknowledgment
- Request fulfilled
- SOS nearby
- Chat messages (via Firebase)
- System announcements

**Preferences:**
- Push notifications enable/disable
- Per-type filtering

### 11. Password Reset

**Email-based reset flow:**
1. User enters email
2. System generates UUID token
3. Deep link sent: `blooddonation://reset-password?email={email}&token={token}`
4. App handles deep link → reset screen
5. User sets new password
6. Token invalidated (one-time use)

**Token Expiry:** 1 hour

### 12. Statistics

**Public Stats:**
- Total donors
- Total donations
- Blood type distribution
- Active requests count

**User Stats:**
- Personal donation count
- Lives impacted estimate
- Achievement progress
- Availability streak

---

## Authentication & Security

### Authentication Flow

```
┌─────────┐         ┌─────────┐         ┌─────────┐
│ Flutter │         │ Django  │         │ Database│
└────┬────┘         └────┬────┘         └────┬────┘
     │                  │                  │
     │ POST /login/     │                  │
     │─────────────────>│                  │
     │                  │ Validate cred    │
     │                  │─────────────────>│
     │                  │                  │
     │                  │ User found       │
     │                  │<─────────────────│
     │                  │                  │
     │ JWT tokens       │                  │
     │<─────────────────│                  │
     │                  │                  │
     │ Store tokens     │                  │
     │ in SharedPreferences              │
     │                  │                  │
```

### Token Management

**Access Token:**
- Lifetime: 60 minutes
- Used for API requests
- Header: `Authorization: Bearer {token}`

**Refresh Token:**
- Lifetime: 7 days
- Used to get new access token
- Rotated on refresh
- Old tokens blacklisted

**Token Refresh Flow:**
```dart
if (response.statusCode == 401) {
  final refreshed = await _refreshAccessToken();
  if (refreshed) {
    // Retry original request with new token
  }
}
```

### Security Measures

1. **Password Security**
   - Minimum length validation
   - Common password detection
   - Hashed with Django's default (PBKDF2)

2. **OTP Security**
   - 6-digit numeric code
   - 10-minute expiry
   - Max 3 attempts
   - 60-second resend cooldown

3. **JWT Security**
   - Signed with SECRET_KEY
   - Short access token lifetime
   - Refresh token rotation
   - Token blacklist on logout

4. **CORS Configuration**
   - Configured for Flutter app
   - Credentials allowed
   - Origins configurable per environment

5. **Rate Limiting**
   - Applied to sensitive endpoints
   - Prevents abuse

6. **SQL Injection Protection**
   - Django ORM parameterized queries
   - No raw SQL in user input handling

---

## Development Setup

### Prerequisites

**Backend:**
- Python 3.9+
- MySQL 8.0+ (or SQLite for dev)
- Virtual environment tool

**Frontend:**
- Flutter SDK 3.12.0+
- Dart SDK 3.12.0+
- Android Studio / Xcode
- Firebase account (for chat)

### Backend Setup

```bash
# Navigate to backend directory
cd django-backend

# Create virtual environment
python -m venv .venv

# Activate virtual environment
# On Windows:
.venv\Scripts\activate
# On macOS/Linux:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
# - SECRET_KEY
# - DATABASE settings
# - EMAIL settings
# - TWILIO settings (optional)
# - FIREBASE settings (optional)

# Run migrations
python manage.py makemigrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Run development server
python manage.py runserver
```

### Frontend Setup

```bash
# Navigate to Flutter app
cd flutter-project/flutter_app

# Get dependencies
flutter pub get

# Create Firebase configuration
# Follow FIREBASE_SETUP.md instructions

# Run on connected device/emulator
flutter run

# Or run on specific platform
flutter run -d android
flutter run -d ios
```

### Firebase Chat Setup

1. Create Firebase project at console.firebase.google.com
2. Enable Cloud Firestore
3. Create Firestore database
4. Download service account key
5. Add Firebase config to Flutter app

```dart
// lib/firebase_options.dart (generated)
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

---

## Production Deployment

### Backend Deployment

**Recommended:**

1. **Server:** AWS EC2, DigitalOcean, or Heroku
2. **Database:** MySQL or PostgreSQL
3. **Web Server:** Gunicorn
4. **Reverse Proxy:** Nginx
5. **SSL:** Let's Encrypt

**Production Settings:**

```python
# backend/settings.py

DEBUG = False
ALLOWED_HOSTS = ['yourdomain.com']
SECRET_KEY = 'production-secret-key'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'blood_donation_db',
        'USER': 'db_user',
        'PASSWORD': 'secure_password',
        'HOST': 'localhost',
        'PORT': '3306',
    }
}

# Security
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
```

### Frontend Deployment

**Build for Android:**

```bash
cd flutter-project/flutter_app

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

**Build for iOS:**

```bash
# Build IPA
flutter build ios --release
```

**Required:**
- App signing keys
- Play Store / App Store developer account
- Firebase configuration for production

---

## Testing

### Backend Tests

```bash
cd django-backend

# Run all tests
python manage.py test

# Run specific app tests
python manage.py test account
python manage.py test blood_requests
python manage.py test donations

# Run with coverage
pip install coverage
coverage run --source='.' manage.py test
coverage report
```

### Frontend Tests

```bash
cd flutter-project/flutter_app

# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

### Test Files

**Backend:**
- `test_blood_requests.py` - Blood request tests
- `test_email.py` - Email functionality tests
- `test_password_reset.py` - Password reset flow tests
- `test_smtp_connection.py` - SMTP connection tests

**Frontend:**
- `test/` directory contains widget tests

---

## Environment Variables

### Backend (.env)

```bash
# Django
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=*

# Database
DB_NAME=blood_donation_db
DB_USER=root
DB_PASSWORD=
DB_HOST=localhost
DB_PORT=3306

# Email
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=your-email@gmail.com

# Twilio (optional)
TWILIO_ACCOUNT_SID=your-account-sid
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=your-twilio-number

# Firebase (optional)
FIREBASE_CREDENTIALS_PATH=path/to/firebase-credentials.json

# Frontend
FRONTEND_URL=http://localhost:3000
APP_DEEP_LINK_SCHEME=blooddonation
```

### Frontend (api_config.dart)

```dart
class ApiConfig {
  // Update with your server IP/domain
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  static String get authEndpoint => '$baseUrl/api/auth';
  static String get bloodRequestsEndpoint => '$baseUrl/api/blood-requests';
  static String get sosEndpoint => '$baseUrl/api/sos';
  static String get donationsEndpoint => '$baseUrl/api/donations';
  static String get bloodTypesEndpoint => '$baseUrl/api/blood-types';
  static String get statsEndpoint => '$baseUrl/api/stats';
  static String get healthEndpoint => '$baseUrl/api/health';
  static String get searchEndpoint => '$baseUrl/api/search';
  static String get messagesEndpoint => '$baseUrl/api/messages';
  static String get notificationsEndpoint => '$baseUrl/api/notifications';
  static String get achievementsEndpoint => '$baseUrl/api/achievements';
}
```

**Note:** `10.0.2.2` is used for Android emulator to access localhost.

---

## Troubleshooting

### Common Issues

**1. CORS Errors**
- Ensure `CORS_ALLOW_ALL_ORIGINS = True` in development
- Add Flutter app domain to `CORS_ALLOWED_ORIGINS` in production

**2. JWT Token Not Found**
- Check token storage in SharedPreferences
- Verify token is being sent in Authorization header
- Check token expiry (60 minutes for access token)

**3. Firebase Connection Failed**
- Verify Firebase project configuration
- Check Firestore rules (should allow authenticated users)
- Ensure internet connectivity

**4. OTP Not Sending**
- In development mode, OTP is logged to console (not sent via SMS)
- Configure Twilio credentials for production SMS
- Check phone number format (+92XXXXXXXXX)

**5. Database Connection Issues**
- Verify database is running
- Check credentials in .env
- Ensure MySQL service is started

**6. Location Services**
- Ensure location permissions granted
- Check GPS is enabled
- Verify coordinate format in database

---

## API Response Formats

### Success Response

```json
{
  "success": true,
  "message": "Operation successful",
  "data": {
    // Response data
  }
}
```

### Error Response

```json
{
  "success": false,
  "message": "Error description",
  "errors": {
    // Field-specific errors
  }
}
```

### Paginated Response

```json
{
  "success": true,
  "count": 100,
  "next": "http://apiurl?page=2",
  "previous": null,
  "results": [
    // Data items
  ]
}
```

---

## Future Enhancements

### Planned Features

1. **Blood Inventory Management**
   - Hospital blood bank integration
   - Real-time inventory tracking

2. **Donor Rewards System**
   - Points per donation
   - Badge achievements
   - Partner discounts

3. **AI-Powered Matching**
   - Smart donor-request matching
   - Predictive demand forecasting

4. **Video Consultations**
   - Telemedicine integration
   - Pre-donation screening

5. **Multi-language Support**
   - Urdu, Arabic, and other languages
   - RTL layout support

6. **Offline Mode**
   - View cached requests offline
   - Sync when connected

7. **Wear OS Support**
   - Quick SOS alerts
   - Donation reminders

8. **Hospital Dashboard**
   - Web-based admin panel
   - Request management
   - Donor communication

---

## License

This project is private and proprietary.

---

## Contact

For questions or support, contact the development team.

---

**Document Version:** 1.0
**Last Updated:** June 8, 2026
**Project Status:** Active Development
