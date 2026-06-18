# LifeDrop Project Structure

## Corrected Folder Structure

```
Blood-Donation/
│
├── .git/                          # Git repository (root only)
├── .gitignore                     # Git ignore rules
├── .venv/                         # Python virtual environment
├── README.md                      # Project overview and quick start
│
├── docs/                          # Documentation
│   ├── API_ENDPOINTS.md           # Complete API reference
│   ├── COMPLETE_PROJECT_DOCUMENTATION.md  # Full project docs
│   ├── DATABASE_SCHEMA.md         # Database schema documentation
│   └── PROJECT_OVERVIEW.md        # High-level project overview
│
├── django-backend/                # Django REST API Backend
│   │
│   ├── .venv/                     # Python virtual environment
│   ├── .env                       # Environment variables (not in git)
│   ├── .env.example               # Environment variables template
│   ├── db.sqlite3                 # SQLite database (development)
│   ├── manage.py                  # Django management script
│   ├── requirements.txt           # Python dependencies
│   │
│   ├── README.md                  # Backend-specific README
│   ├── FLUTTER_INTEGRATION.md     # Flutter integration guide
│   ├── PRODUCTION_DEPLOYMENT.md   # Production deployment guide
│   ├── PRODUCTION_README.md       # Production-specific notes
│   ├── TEST_RESULTS.md            # Test results documentation
│   │
│   ├── account/                   # User authentication & profiles
│   │   ├── __init__.py
│   │   ├── admin.py               # Django admin configuration
│   │   ├── apps.py                # App configuration
│   │   ├── models.py              # CustomUser, UserProfile, PasswordReset
│   │   ├── serializers.py         # Data serialization
│   │   ├── urls.py                # Account routes
│   │   ├── views.py               # Authentication endpoints
│   │   └── migrations/            # Database migrations
│   │
│   ├── blood_requests/            # Blood request management
│   │   ├── __init__.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py              # BloodRequest, DonorResponse
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   ├── views.py
│   │   └── migrations/
│   │
│   ├── blood_types/               # Blood type reference data
│   │   ├── __init__.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py              # BloodType model
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   ├── views.py
│   │   ├── management/
│   │   │   └── commands/
│   │   │       └── seed_blood_types.py
│   │   └── migrations/
│   │
│   ├── donations/                 # Donation records & certificates
│   │   ├── __init__.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py              # Donation model
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   ├── views.py
│   │   └── migrations/
│   │
│   ├── sos/                       # Emergency SOS requests
│   │   ├── __init__.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py              # SOSRequest, SOSResponse
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   ├── views.py
│   │   └── migrations/
│   │
│   ├── stats/                     # Statistics & analytics
│   │   ├── __init__.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py
│   │   ├── urls.py
│   │   ├── views.py
│   │   └── migrations/
│   │
│   ├── health/                    # Health eligibility quiz
│   │   ├── __init__.py
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── urls.py
│   │   ├── views.py
│   │   └── migrations/
│   │
│   ├── backend/                   # Django project configuration
│   │   ├── __init__.py
│   │   ├── settings.py            # Django settings
│   │   ├── urls.py                # Root URL configuration
│   │   ├── wsgi.py                # WSGI configuration
│   │   └── asgi.py                # ASGI configuration
│   │
│   ├── tests/                     # Backend tests
│   │   ├── test_blood_requests.py
│   │   ├── test_email.py
│   │   ├── test_password_reset.py
│   │   └── test_smtp_connection.py
│   │
│   ├── logs/                      # Application logs
│   └── profile_pictures/          # Uploaded profile pictures
│       └── .gitkeep               # Keep empty dir in git
│
└── flutter-project/               # Flutter Mobile App
    └── flutter_app/
        │
        ├── android/               # Android platform code
        │   ├── app/
        │   │   ├── google-services.json  # Firebase config
        │   │   └── src/
        │   └── build.gradle
        │
        ├── ios/                   # iOS platform code
        │   ├── Runner/
        │   │   ├── Assets.xcassets/
        │   │   └── AppDelegate.swift
        │   └── Flutter/
        │
        ├── lib/                   # Flutter source code
        │   ├── main.dart          # App entry point
        │   ├── app.dart           # Root widget
        │   ├── app_routes.dart    # Route definitions
        │   │
        │   └── src/
        │       ├── config/        # Configuration
        │       │   └── api_config.dart
        │       │
        │       ├── models/        # Data models
        │       │   ├── blood_request.dart
        │       │   ├── chat_conversation.dart
        │       │   ├── chat_message.dart
        │       │   ├── donation_response.dart
        │       │   ├── donor_pledge.dart
        │       │   ├── notification.dart
        │       │   ├── profile.dart
        │       │   ├── sos_request.dart
        │       │   └── statistics.dart
        │       │
        │       ├── services/      # Business logic
        │       │   ├── api_service.dart          # API client
        │       │   ├── firebase_chat_service.dart # Chat service
        │       │   ├── location_service.dart
        │       │   └── search_analytics_service.dart
        │       │
        │       ├── screens/       # UI Screens
        │       │   ├── auth/      # Authentication
        │       │   │   ├── login_screen.dart
        │       │   │   ├── sign_up_screen.dart
        │       │   │   ├── forgot_password_screen.dart
        │       │   │   ├── reset_password_screen.dart
        │       │   │   └── profile_setup_screen.dart
        │       │   │
        │       │   ├── onboarding/  # Onboarding screens
        │       │   │   ├── onboarding_screen.dart
        │       │   │   ├── onboarding_screen_2.dart
        │       │   │   └── onboarding_screen3.dart
        │       │   │
        │       │   ├── blood_request/  # Blood request screens
        │       │   │   └── blood_request_form_screen.dart
        │       │   │
        │       │   ├── chat/      # Firebase Chat
        │       │   │   ├── chat_list_screen.dart
        │       │   │   └── chat_conversation_screen.dart
        │       │   │
        │       │   ├── donations/  # Donation management
        │       │   │   ├── my_donations_screen.dart
        │       │   │   └── donation_certificate_screen.dart
        │       │   │
        │       │   ├── donors/     # Donor search
        │       │   │   ├── donor_profile_screen.dart
        │       │   │   ├── find_donors_screen.dart
        │       │   │   └── nearby_donors_map_screen.dart
        │       │   │
        │       │   ├── notifications/
        │       │   │   ├── notifications_screen.dart
        │       │   │   └── notifications_screen_api.dart
        │       │   │
        │       │   ├── quiz/       # Health eligibility
        │       │   │   └── health_eligibility_quiz_screen.dart
        │       │   │
        │       │   ├── requests/   # Blood request management
        │       │   │   ├── blood_request_detail_screen.dart
        │       │   │   ├── my_requests_screen.dart
        │       │   │   └── nearby_requests_screen.dart
        │       │   │
        │       │   ├── sos/        # Emergency SOS
        │       │   │   ├── sos_screen.dart
        │       │   │   ├── sos_active_screen.dart
        │       │   │   ├── sos_screen_api.dart
        │       │   │   └── sos_screen_api.dart
        │       │   │
        │       │   ├── messages/   # Messaging
        │       │   │   ├── messages_screen.dart
        │       │   │   ├── messages_screen_api.dart
        │       │   │   └── chat_conversation_screen_api.dart
        │       │   │
        │       │   ├── home/      # Home screens
        │       │   │   └── home_screen.dart
        │       │   │
        │       │   ├── profile/   # User profile
        │       │   │   └── profile_screen.dart
        │       │   │
        │       │   ├── settings/  # App settings
        │       │   │   └── settings_screen.dart
        │       │   │
        │       │   ├── splash/    # Splash screen
        │       │   │   └── splash_screen.dart
        │       │   │
        │       │   ├── role_selection/
        │       │   │   └── role_selection_screen.dart
        │       │   │
        │       │   ├── patient_home/
        │       │   │   └── patient_home_screen.dart
        │       │   │
        │       │   └── search/
        │       │       └── search_screen.dart
        │       │
        │       ├── theme/         # App theming
        │       │   └── app_theme.dart
        │       │
        │       └── widgets/       # Reusable widgets
        │           ├── avatar_with_status.dart
        │           ├── blood_request_progress_bar.dart
        │           ├── blood_type_chip.dart
        │           ├── buttons/
        │           │   ├── primary_button.dart
        │           │   └── secondary_button.dart
        │           ├── pledged_donor_card.dart
        │           ├── pledge_dialog.dart
        │           ├── promotional_banner.dart
        │           └── urgency_tag.dart
        │
        ├── pubspec.yaml           # Dart dependencies
        ├── README.md              # Flutter app README
        ├── FIREBASE_SETUP.md      # Firebase configuration
        ├── FIREBASE_CHAT_SUMMARY.md
        ├── analysis_options.yaml   # Dart linter configuration
        │
        └── build/                 # Build output (generated)
```

## Changes Made

### 1. Removed Duplicate Folders
- ✅ Removed `blood-donation-app/` (empty duplicate with nested .git)
- ✅ Removed `django-backend/.git/` (duplicate - git should only be at root)

### 2. Organized Documentation
- ✅ Created `docs/` directory
- ✅ Moved all `.md` files from root to `docs/`
- ✅ Created comprehensive `README.md` at project root

### 3. Organized Tests
- ✅ Created `tests/` directory in django-backend
- ✅ Moved all `test_*.py` files from root to `tests/`

### 4. Created Git Configuration
- ✅ Created `.gitignore` at project root with comprehensive rules
- ✅ Added `.gitkeep` to `profile_pictures/` to preserve empty directory

### 5. Project Structure Benefits
- **Single Git Repository**: Only one `.git` folder at root
- **Organized Documentation**: All docs in one location
- **Clean Tests**: Test files properly organized
- **Proper Ignores**: `.gitignore` prevents committing sensitive/temp files
- **Clear Hierarchy**: Easy to navigate structure

## Git Repository Status

The project now has a single Git repository at the root level:
```
/Blood-Donation/.git/
```

All subdirectories (`django-backend/`, `flutter-project/`, `docs/`) are tracked within this single repository.

## Next Steps

1. Commit the changes:
   ```bash
   git add .
   git commit -m "Reorganize project structure"
   ```

2. Update any deployment scripts or documentation that reference old paths

3. Update IDE configuration if needed (workspace settings, etc.)
