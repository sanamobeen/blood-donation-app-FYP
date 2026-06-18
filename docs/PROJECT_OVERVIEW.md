# LifeDrop - Blood Donation Platform

## 📋 Complete Project Documentation

**Project Name:** LifeDrop  
**Version:** 1.0.0  
**Last Updated:** 2026-06-08  
**Type:** Full-Stack Mobile Application  
**Architecture:** Client-Server (REST API + Mobile App)

---

## 📖 Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Features & Functionality](#features--functionality)
6. [Database Schema](#database-schema)
7. [API Endpoints](#api-endpoints)
8. [Authentication & Security](#authentication--security)
9. [User Roles & Workflows](#user-roles--workflows)
10. [Installation & Setup](#installation--setup)
11. [Development Workflow](#development-workflow)
12. [Deployment Guide](#deployment-guide)
13. [Testing](#testing)
14. [Troubleshooting](#troubleshooting)

---

## 🎯 Project Overview

**LifeDrop** is a comprehensive blood donation platform that connects blood donors with patients in need. The platform facilitates:

- **Blood Donation Requests:** Patients can request blood when needed
- **Donor-Patient Matching:** System matches donors with patients based on blood type, location, and urgency
- **SOS Emergency Requests:** Critical blood needs can be broadcast as emergency alerts
- **Real-time Communication:** Built-in chat between donors and patients
- **Health Eligibility Quiz:** Donors complete health questionnaires to verify eligibility
- **Donation Tracking:** Complete record of donations with certificates
- **Location-based Search:** Find nearby donors and blood requests

### Core Purpose

To save lives by creating an efficient bridge between blood donors and patients, reducing the time and effort required to find compatible blood donors during emergencies.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         LifeDrop Platform                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐         ┌──────────────────┐              │
│  │   Flutter App   │◄────────┤  REST API (Django)│              │
│  │  (Mobile Client) │  HTTP   │  Django REST      │              │
│  │                 │◄────────┤  Framework        │              │
│  └─────────────────┘         └──────────────────┘              │
│         │                             │                          │
│         │ Firebase                   │ SQLite/MySQL              │
│         │ (Chat Service)             │ (Database)               │
│         ▼                             ▼                          │
│  ┌─────────────────┐         ┌──────────────────┐              │
│  │ Cloud Firestore │         │  Database Server │              │
│  │   (Real-time    │         │                  │              │
│  │    Messaging)   │         │                  │              │
│  └─────────────────┘         └──────────────────┘              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Architecture Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Mobile Client** | Flutter (Dart) | Cross-platform mobile application for Android/iOS |
| **REST API** | Django + DRF | Backend API for data operations and authentication |
| **Database** | SQLite/MySQL | Persistent data storage for users, requests, donations |
| **Chat Service** | Firebase Firestore | Real-time messaging between donors and patients |
| **Authentication** | JWT + SimpleJWT | Token-based authentication with refresh tokens |
| **Location Services** | Geolocator | GPS-based location for finding nearby donors/requests |

---

## 🔧 Technology Stack

### Backend (Django)

```
Django 5.2.3
├── Django REST Framework 3.15.2     # API framework
├── Simple JWT 5.5.0                  # JWT authentication
├── CORS Headers 4.6.0                # Cross-origin support
├── Python Decouple 3.8               # Environment configuration
├── Django Filter 24.3                # Query filtering
├── Django Rate Limit 4.1.0           # API rate limiting
├── Twilio 9.0.0                      # SMS service
├── Firebase Admin 6.5.0              # Firebase integration
└── MySQL Client 2.2.4                # MySQL database driver
```

### Frontend (Flutter)

```
Flutter SDK 3.12.0+
├── http 1.2.0                        # HTTP requests
├── provider 6.1.0                    # State management
├── shared_preferences 2.2.2          # Local storage
├── image_picker 1.0.7                # Image handling
├── geolocator 12.0.0                 # GPS/location services
├── app_links 7.1.1                   # Deep linking
├── firebase_core 3.0.0               # Firebase base
├── cloud_firestore 5.0.0             # Firestore database
├── firebase_auth 5.0.0               # Firebase auth
└── intl 0.19.0                       # Internationalization
```

---

## 📁 Project Structure

```
e:/Blood-Donation/
│
├── django-backend/                    # Django REST API Backend
│   ├── account/                       # User authentication & profiles
│   │   ├── models.py                  # CustomUser, UserProfile models
│   │   ├── views.py                   # Auth, OTP, profile endpoints
│   │   ├── serializers.py             # Data serialization
│   │   └── urls.py                    # Auth route URLs
│   ├── blood_requests/                # Blood request management
│   │   ├── models.py                  # BloodRequest model
│   │   ├── views.py                   # CRUD operations
│   │   └── urls.py                    # Request routes
│   ├── blood_types/                   # Blood type reference
│   ├── donations/                     # Donation records
│   │   ├── models.py                  # Donation model
│   │   ├── views.py                   # Donation endpoints
│   │   └── urls.py                    # Donation routes
│   ├── sos/                           # Emergency SOS requests
│   │   ├── models.py                  # SOSRequest model
│   │   ├── views.py                   # SOS endpoints
│   │   └── urls.py                    # SOS routes
│   ├── health/                        # Health eligibility quiz
│   │   ├── models.py                  # HealthEligibilityResponse
│   │   ├── views.py                   # Quiz endpoints
│   │   └── urls.py                    # Health routes
│   ├── stats/                         # Statistics endpoints
│   ├── backend/                       # Django project settings
│   │   ├── settings.py                # Project configuration
│   │   ├── urls.py                    # Root URL routing
│   │   └── wsgi.py/asgi.py            # ASGI/WSGI config
│   ├── manage.py                      # Django CLI
│   ├── requirements.txt               # Python dependencies
│   ├── .env                           # Environment variables
│   ├── db.sqlite3                     # SQLite database (dev)
│   ├── logs/                          # Application logs
│   └── profile_pictures/              # Uploaded profile images
│
├── flutter-project/                   # Flutter Mobile Application
│   └── flutter_app/
│       ├── lib/
│       │   ├── main.dart              # App entry point
│       │   ├── src/
│       │   │   ├── app.dart           # MaterialApp setup
│       │   │   ├── app_routes.dart    # Route definitions
│       │   │   ├── config/
│       │   │   │   └── api_config.dart # API base URLs
│       │   │   ├── models/            # Data models
│       │   │   │   ├── chat_message.dart
│       │   │   │   ├── chat_conversation.dart
│       │   │   │   ├── blood_request.dart
│       │   │   │   ├── donor_pledge.dart
│       │   │   │   ├── notification.dart
│       │   │   │   ├── profile.dart
│       │   │   │   ├── sos_request.dart
│       │   │   │   ├── statistics.dart
│       │   │   │   └── donation_response.dart
│       │   │   ├── screens/           # UI Screens
│       │   │   │   ├── splash/
│       │   │   │   ├── onboarding/    # Intro screens
│       │   │   │   ├── auth/           # Login, signup, profile setup
│       │   │   │   ├── home/           # Main home screen
│       │   │   │   ├── donors/         # Donor-related screens
│       │   │   │   ├── requests/       # Blood request screens
│       │   │   │   ├── sos/            # Emergency SOS screens
│       │   │   │   ├── chat/           # Messaging screens
│       │   │   │   ├── messages/       # Messages list
│       │   │   │   ├── notifications/   # Notification screens
│       │   │   │   ├── profile/        # User profile
│       │   │   │   ├── settings/       # App settings
│       │   │   │   ├── quiz/           # Health eligibility quiz
│       │   │   │   └── role_selection/ # Donor/Patient selection
│       │   │   ├── services/          # Business logic
│       │   │   │   ├── api_service.dart       # API client
│       │   │   │   ├── firebase_chat_service.dart # Chat service
│       │   │   │   ├── location_service.dart    # GPS services
│       │   │   │   └── search_analytics_service.dart
│       │   │   ├── widgets/           # Reusable UI components
│       │   │   │   ├── buttons/
│       │   │   │   ├── blood_type_chip.dart
│       │   │   │   ├── urgency_tag.dart
│       │   │   │   ├── pledge_dialog.dart
│       │   │   │   └── avatar_with_status.dart
│       │   │   └── theme/            # App theming
│       │   │       └── app_theme.dart
│       │   └── test/                  # Unit tests
│       ├── pubspec.yaml                # Flutter dependencies
│       ├── android/                    # Android build files
│       ├── ios/                        # iOS build files
│       └── build/                      # Build output
│
├── API_ENDPOINTS.md                   # API documentation
├── DATABASE_SCHEMA.md                 # Database documentation
├── FLUTTER_INTEGRATION.md             # Flutter-Django integration guide
├── PRODUCTION_DEPLOYMENT.md          # Production deployment guide
├── PRODUCTION_README.md              # Production setup notes
├── TEST_RESULTS.md                   # Test results
└── PROJECT_OVERVIEW.md               # This file
```

---

## ✨ Features & Functionality

### 1. User Management

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Registration** | Email/password signup with role selection | `POST /api/auth/register/` |
| **Login** | JWT-based authentication | `POST /api/auth/login/` |
| **Profile Setup** | Complete donor/patient profile | `PUT /api/donor/profile/` |
| **Profile Picture** | Upload and manage profile photo | `POST /api/auth/profile/picture/` |
| **Password Reset** | Email-based password recovery | `POST /api/auth/forgot-password/` |
| **Phone Verification** | OTP-based phone number verification | `POST /api/auth/send-otp/` |

### 2. Blood Request Management

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Create Request** | Patients create blood donation requests | `POST /api/blood-requests/` |
| **List Requests** | Browse all active blood requests | `GET /api/blood-requests/` |
| **My Requests** | View own blood requests | `GET /api/blood-requests/my/` |
| **Request Details** | Full request information | `GET /api/blood-requests/{id}/` |
| **Update Request** | Modify request details | `PATCH /api/blood-requests/{id}/` |
| **Cancel Request** | Mark request as cancelled | `POST /api/blood-requests/{id}/cancel/` |
| **Nearby Requests** | Find requests by location | `GET /api/blood-requests/nearby/` |
| **Filter by Blood Type** | Find compatible requests | Query param: `blood_type` |
| **Filter by Urgency** | Critical/High/Normal urgency | Query param: `urgency` |

### 3. Donor Management

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Donor Profile** | Complete donor information | `GET /api/donor/profile/` |
| **Find Donors** | Search for donors by blood type/location | `GET /api/donor/nearby/` |
| **Donor Map** | Visual map of nearby donors | `GET /api/donor/nearby/` |
| **Availability Toggle** | Set donation availability | `POST /api/donor/profile/toggle-availability/` |
| **Location Update** | Update current location | `PATCH /api/donor/profile/location/` |

### 4. Emergency SOS Requests

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Create SOS** | Broadcast emergency blood need | `POST /api/sos/` |
| **Active SOS List** | View all active emergency requests | `GET /api/sos/active/` |
| **Respond to SOS** | Indicate willingness to donate | `POST /api/sos/{id}/respond/` |
| **Resolve SOS** | Mark emergency as resolved | `POST /api/sos/{id}/resolve/` |
| **Cancel SOS** | Cancel emergency request | `POST /api/sos/{id}/cancel/` |
| **Nearby SOS** | Find SOS requests by location | `GET /api/sos/active/` |

### 5. Donation Records

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Record Donation** | Log completed blood donation | `POST /api/donations/` |
| **My Donations** | View donation history | `GET /api/donations/my/` |
| **Donation Details** | Full donation information | `GET /api/donations/{id}/` |
| **Donation Certificate** | Generate donation certificate | `GET /api/donations/{id}/certificate/` |
| **Donation Stats** | Personal donation statistics | `GET /api/donations/stats/` |

### 6. Health Eligibility Quiz

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Get Quiz** | Fetch health questionnaire | `GET /api/health/quiz/` |
| **Submit Quiz** | Submit health responses | `POST /api/health/quiz/submit/` |
| **Check Eligibility** | Verify donation eligibility | `GET /api/health/eligibility/` |

### 7. Real-time Chat

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **Conversation List** | View all chat conversations | Firebase Firestore |
| **Send Message** | Send text messages | Firebase Firestore |
| **System Messages** | Automated status messages | Firebase Firestore |
| **Read Receipts** | Mark messages as read | Firebase Firestore |
| **Real-time Updates** | Instant message delivery | Stream subscriptions |

### 8. Notifications

| Feature | Description | Type |
|---------|-------------|------|
| **Blood Request Match** | New compatible request nearby | Push |
| **SOS Alert** | Emergency blood need | Push |
| **Donation Reminder** | Eligible to donate again | Push |
| **Message Received** | New chat message | Push |
| **Request Fulfilled** | Blood request completed | Push |
| **Achievement Earned** | Badge unlocked | Push |

### 9. Statistics

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Public Stats** | Platform-wide statistics | `GET /api/stats/public/` |
| **User Stats** | Personal contribution stats | `GET /api/stats/user/` |
| **Lives Saved** | Impact calculation | Derived from donations |

### 10. Search & Discovery

| Feature | Description | Endpoints |
|---------|-------------|------------|
| **Search Donors** | Find donors by criteria | `GET /api/search/donors/` |
| **Search Requests** | Find blood requests | `GET /api/search/requests/` |
| **Location-based Search** | Results by distance | Query params: lat, lng, radius |

---

## 🗄️ Database Schema

### Core Tables

#### 1. account_customuser (User Authentication)
```python
- id: UUID (Primary Key)
- email: EmailField (Unique)
- password: CharField (Hashed)
- full_name: CharField
- phone_num: CharField (Nullable)
- phone_verified: BooleanField
- otp_code: CharField (Nullable)
- otp_expires_at: DateTimeField (Nullable)
- otp_attempts: IntegerField
- otp_last_sent_at: DateTimeField (Nullable)
- role: CharField (donor/patient)
- is_active: BooleanField
- date_joined: DateTimeField
- last_login: DateTimeField
```

#### 2. account_userprofile (Extended Profile)
```python
- id: UUID (Primary Key)
- user: ForeignKey (CustomUser)
- profile_picture: ImageField
- blood_group: CharField
- date_of_birth: DateField
- gender: CharField
- weight: DecimalField
- location_lat: DecimalField
- location_lng: DecimalField
- address: TextField
- city: CharField
- state: CharField
- country: CharField
- postal_code: CharField
- is_available_for_donation: BooleanField
- last_donation_date: DateField
- total_donations: IntegerField
- eligibility_verified: BooleanField
- eligibility_valid_until: DateField
```

#### 3. bloodrequest (Blood Donation Requests)
```python
- id: UUID (Primary Key)
- patient: ForeignKey (CustomUser)
- blood_type: ForeignKey (BloodType)
- urgency: CharField (critical/high/normal)
- units_needed: IntegerField
- hospital_name: CharField
- hospital_address: TextField
- hospital_lat: DecimalField
- hospital_lng: DecimalField
- contact_person: CharField
- contact_phone: CharField
- diagnosis: CharField
- required_date: DateField
- status: CharField (active/fulfilled/cancelled/expired)
- is_anonymous: BooleanField
- views_count: IntegerField
- created_at: DateTimeField
- updated_at: DateTimeField
- fulfilled_at: DateTimeField
```

#### 4. donation (Donation Records)
```python
- id: UUID (Primary Key)
- donor: ForeignKey (CustomUser)
- blood_request: ForeignKey (BloodRequest)
- blood_type: ForeignKey (BloodType)
- units: IntegerField
- donation_date: DateField
- donation_center: CharField
- donation_center_address: TextField
- hemoglobin_level: DecimalField
- blood_pressure: CharField
- health_status: CharField
- notes: TextField
- certificate_issued: BooleanField
- created_at: DateTimeField
```

#### 5. sosrequest (Emergency Requests)
```python
- id: UUID (Primary Key)
- requester: ForeignKey (CustomUser)
- blood_type: ForeignKey (BloodType)
- patient_name: CharField
- hospital_name: CharField
- hospital_address: TextField
- hospital_lat: DecimalField
- hospital_lng: DecimalField
- contact_phone: CharField
- age: IntegerField
- gender: CharField
- units_needed: IntegerField
- status: CharField (active/responded/resolved/cancelled)
- responders_count: IntegerField
- created_at: DateTimeField
- resolved_at: DateTimeField
```

#### 6. healtheligibilityresponse (Health Quiz Responses)
```python
- id: UUID (Primary Key)
- user: ForeignKey (CustomUser)
- responses: JSONField
- is_eligible: BooleanField
- ineligibility_reasons: JSONField
- quiz_version: CharField
- created_at: DateTimeField
```

**See [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) for complete database documentation.**

---

## 🔌 API Endpoints

### Base URL
```
Development: http://127.0.0.1:8000/api
Production: https://your-domain.com/api
```

### Authentication Endpoints
```
POST   /api/auth/register/              # Register new user
POST   /api/auth/login/                 # Login user
POST   /api/auth/logout/                # Logout user
POST   /api/auth/token/refresh/         # Refresh access token
GET    /api/auth/profile/               # Get user profile
PATCH  /api/auth/profile/update/        # Update profile
POST   /api/auth/change-password/       # Change password
POST   /api/auth/send-otp/              # Send OTP code
POST   /api/auth/verify-otp/            # Verify OTP
POST   /api/auth/resend-otp/            # Resend OTP
POST   /api/auth/forgot-password/       # Request password reset
POST   /api/auth/reset-password/         # Reset password
```

### Blood Request Endpoints
```
POST   /api/blood-requests/             # Create request
GET    /api/blood-requests/             # List all requests
GET    /api/blood-requests/my/          # Get my requests
GET    /api/blood-requests/{id}/        # Get request details
PATCH  /api/blood-requests/{id}/        # Update request
POST   /api/blood-requests/{id}/cancel/ # Cancel request
GET    /api/blood-requests/nearby/      # Find nearby requests
```

### Donor Endpoints
```
GET    /api/donor/profile/              # Get donor profile
PUT     /api/donor/profile/             # Create/update profile
PATCH  /api/donor/profile/location/     # Update location
POST   /api/donor/profile/toggle-availability/ # Toggle availability
GET    /api/donor/nearby/               # Find nearby donors
GET    /api/donor/profile/{id}/         # Get donor by ID
```

### Donation Endpoints
```
POST   /api/donations/                  # Record donation
GET    /api/donations/my/               # Get my donations
GET    /api/donations/{id}/             # Get donation details
GET    /api/donations/{id}/certificate/ # Get certificate
GET    /api/donations/stats/            # Get statistics
```

### SOS Endpoints
```
POST   /api/sos/                        # Create SOS
GET    /api/sos/active/                 # List active SOS
POST   /api/sos/{id}/respond/           # Respond to SOS
GET    /api/sos/{id}/                   # Get SOS details
POST   /api/sos/{id}/resolve/           # Resolve SOS
POST   /api/sos/{id}/cancel/            # Cancel SOS
```

### Health Endpoints
```
GET    /api/health/quiz/                # Get health quiz
POST   /api/health/quiz/submit/         # Submit quiz
GET    /api/health/eligibility/         # Check eligibility
```

### Statistics Endpoints
```
GET    /api/stats/public/               # Public statistics
GET    /api/stats/user/                 # User statistics
```

**See [API_ENDPOINTS.md](API_ENDPOINTS.md) for complete API documentation with request/response examples.**

---

## 🔐 Authentication & Security

### JWT Token Flow

```
1. User Login/Signup
   ↓
2. Server Generates JWT Tokens (Access + Refresh)
   ↓
3. Client Stores Tokens Securely
   ↓
4. Access Token Sent in Authorization Header
   ↓
5. Access Token Expires (60 minutes)
   ↓
6. Refresh Token Used to Get New Access Token
   ↓
7. New Access Token Returned
```

### Token Configuration

| Token Type | Lifetime | Purpose |
|------------|----------|---------|
| Access Token | 60 minutes | API authentication |
| Refresh Token | 7 days | Obtain new access tokens |

### Security Features

- ✅ Password validation (minimum length, common passwords)
- ✅ OTP rate limiting (3 requests per minute)
- ✅ OTP resend cooldown (60 seconds)
- ✅ OTP expiration (10 minutes)
- ✅ Failed OTP attempt tracking (max 3 attempts)
- ✅ JWT token blacklisting on logout
- ✅ CORS configuration for Flutter
- ✅ Input sanitization and validation
- ✅ SQL injection prevention (ORM)

### Rate Limiting

| Endpoint | Limit | Purpose |
|----------|-------|---------|
| `/api/auth/send-otp/` | 3/minute | Prevent OTP spam |
| `/api/auth/login/` | 10/minute | Prevent brute force |
| `/api/auth/register/` | 5/hour | Prevent spam registration |

---

## 👥 User Roles & Workflows

### Role Selection Flow

```
┌─────────────┐
│ App Launch  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Onboarding  │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  Role Selection    │
│  ┌───────────────┐ │
│  │   Donor       │ │
│  └───────────────┘ │
│  ┌───────────────┐ │
│  │   Patient     │ │
│  └───────────────┘ │
└─────────┬───────────┘
          │
          ▼
    ┌─────────┐
    │  Login  │
    └─────────┘
```

### Donor Workflow

```
1. Register/Login
   ↓
2. Complete Profile Setup
   - Blood type
   - Date of birth
   - Weight
   - Location
   ↓
3. Health Eligibility Quiz
   - Answer health questions
   - Get eligibility status
   ↓
4. Browse Blood Requests
   - View all requests
   - Filter by blood type
   - Filter by location
   ↓
5. Respond to Request
   - Pledge to donate
   - Start chat with patient
   ↓
6. Complete Donation
   - Record donation
   - Generate certificate
   - Update last donation date
   ↓
7. Track Impact
   - View donation history
   - See lives saved
```

### Patient Workflow

```
1. Register/Login
   ↓
2. Complete Profile Setup
   ↓
3. Create Blood Request
   - Specify blood type
   - Set urgency level
   - Add hospital details
   ↓
4. Wait for Donor Responses
   - Receive notifications
   - View pledged donors
   ↓
5. Communicate with Donors
   - Real-time chat
   - Coordinate donation
   ↓
6. Mark Request Fulfilled
   - Update request status
   - Rate donor (optional)
```

---

## 🚀 Installation & Setup

### Prerequisites

- Python 3.8+
- Flutter SDK 3.12.0+
- Node.js (for some tools)
- Git
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)

### Backend Setup

```bash
# Navigate to backend directory
cd e:/Blood-Donation/django-backend

# Create virtual environment
python -m venv .venv

# Activate virtual environment
# On Windows:
.venv\Scripts\activate
# On Linux/Mac:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create environment file
copy .env.example .env

# Edit .env with your configuration
notepad .env

# Run migrations
python manage.py makemigrations
python manage.py migrate

# Create superuser (optional)
python manage.py createsuperuser

# Run development server
python manage.py runserver
```

### Flutter App Setup

```bash
# Navigate to Flutter app directory
cd e:/Blood-Donation/flutter-project/flutter_app

# Get dependencies
flutter pub get

# Update API configuration
# Edit lib/src/config/api_config.dart
# Set your backend URL

# Run on connected device/emulator
flutter run

# Build for Android
flutter build apk

# Build for iOS
flutter build ios
```

### Firebase Setup (Chat Service)

```bash
# Create Firebase project at console.firebase.google.com

# Add Android app
# Download google-services.json
# Place at android/app/google-services.json

# Add iOS app
# Download GoogleService-Info.plist
# Place at ios/Runner/GoogleService-Info.plist

# Enable Cloud Firestore
# Create database: conversations, messages collections
```

---

## 💻 Development Workflow

### Running Full Stack Locally

**Terminal 1 - Django Backend:**
```bash
cd e:/Blood-Donation/django-backend
.venv\Scripts\activate
python manage.py runserver
# Server running at http://127.0.0.1:8000
```

**Terminal 2 - Flutter App:**
```bash
cd e:/Blood-Donation/flutter-project/flutter_app
flutter run
```

### API Configuration

For local development with Flutter:

**Android Emulator:** Use `http://10.0.2.2:8000/api`  
**iOS Simulator:** Use `http://127.0.0.1:8000/api`  
**Physical Device:** Use your computer's IP address

### Testing Backend APIs

```bash
# Test registration
curl -X POST http://127.0.0.1:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"SecurePass123","password_confirm":"SecurePass123","full_name":"Test User","phone_num":"+1234567890"}'

# Test login
curl -X POST http://127.0.0.1:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"SecurePass123"}'
```

### Code Organization Best Practices

1. **Backend (Django):**
   - One app per feature module
   - Separation: models, serializers, views, urls
   - Use viewsets for CRUD operations
   - Custom permissions for sensitive endpoints

2. **Frontend (Flutter):**
   - Feature-based folder structure
   - Separate screens, widgets, services
   - Use Provider for state management
   - Reusable widgets in common folder

---

## 🌐 Deployment Guide

### Backend Deployment

**Production Checklist:**

- [ ] Set `DEBUG = False` in settings
- [ ] Set `ALLOWED_HOSTS` to your domain
- [ ] Configure PostgreSQL database
- [ ] Set up environment variables
- [ ] Remove `CORS_ALLOW_ALL_ORIGINS = True`
- [ ] Add specific origins to `CORS_ALLOWED_ORIGINS`
- [ ] Remove OTP from API responses
- [ ] Configure email service
- [ ] Set up SSL/HTTPS
- [ ] Configure logging
- [ ] Set up monitoring

**Hosting Options:**

1. **Heroku** - Easy deployment
2. **DigitalOcean** - Full control
3. **AWS** - Enterprise solution
4. **Google Cloud Platform** - Firebase integration

### Flutter App Deployment

**Android:**

```bash
# Generate signed APK
flutter build apk --release

# Generate App Bundle (for Play Store)
flutter build appbundle --release
```

**iOS:**

```bash
# Build for iOS
flutter build ios --release

# Open in Xcode for final signing
open ios/Runner.xcworkspace
```

### Environment Variables

**Backend (.env):**
```env
DEBUG=False
SECRET_KEY=your-production-secret-key
DATABASE_URL=mysql://user:password@host:port/database
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
TWILIO_PHONE_NUMBER=+1234567890
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
```

---

## 🧪 Testing

### Backend Testing

```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test account
python manage.py test blood_requests

# With coverage
pip install coverage
coverage run --source='.' manage.py test
coverage report
```

### API Testing

```bash
# Test blood request creation
curl -X POST http://127.0.0.1:8000/api/blood-requests/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{"blood_type":1,"urgency":"critical","units_needed":2,"hospital_name":"City Hospital"}'
```

### Flutter Testing

```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/widget_test.dart
```

**See [TEST_RESULTS.md](TEST_RESULTS.md) for detailed test results.**

---

## 🔧 Troubleshooting

### Common Issues

**1. Flutter - Gradle Version Warning**
```
Warning: Flutter support for your project's Android Gradle Plugin version will soon be dropped.
```
**Solution:** Update Android Gradle Plugin to 8.11.1+ in `android/build.gradle`

**2. Django - CORS Errors**
```
Access to XMLHttpRequest has been blocked by CORS policy
```
**Solution:** Ensure `CORS_ALLOW_ALL_ORIGINS = True` in development

**3. Firebase - Initialization Error**
```
Firebase initialization error
```
**Solution:** Ensure `google-services.json` is properly configured

**4. Database - Migration Errors**
```
django.db.migrations.exceptions.InconsistentMigrationHistory
```
**Solution:** Drop and recreate database or fake migrations

**5. OTP - Not Received**
```
OTP not received on phone
```
**Solution:** Check Twilio configuration, in development OTP is returned in API response

### Debug Mode

**Backend:**
```python
# settings.py
DEBUG = True
LOGGING_LEVEL = 'DEBUG'
```

**Frontend:**
```dart
// Enable Flutter debug logs
print('Debug: $variable');
```

### Support Resources

- Django Documentation: https://docs.djangoproject.com/
- Flutter Documentation: https://flutter.dev/docs
- Firebase Documentation: https://firebase.google.com/docs

---

## 📞 Contact & Support

For issues, questions, or contributions:

- **Project Repository:** Internal Git Repository
- **Documentation:** See `.md` files in project root
- **API Documentation:** [API_ENDPOINTS.md](API_ENDPOINTS.md)
- **Database Schema:** [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)

---

## 📝 License & Credits

**Project:** LifeDrop - Blood Donation Platform  
**Version:** 1.0.0  
**Last Updated:** 2026-06-08  

This project is developed to facilitate blood donation and save lives through technology.

---

**End of Documentation**
