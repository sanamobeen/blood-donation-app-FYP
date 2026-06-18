# LifeDrop - Blood Donation Platform

A comprehensive full-stack blood donation platform connecting donors with patients in real-time.

## Quick Links

- [Complete Documentation](docs/COMPLETE_PROJECT_DOCUMENTATION.md)
- [API Endpoints](docs/API_ENDPOINTS.md)
- [Database Schema](docs/DATABASE_SCHEMA.md)
- [Project Overview](docs/PROJECT_OVERVIEW.md)

## Project Structure

```
Blood-Donation/
├── docs/                           # Project documentation
│   ├── API_ENDPOINTS.md
│   ├── COMPLETE_PROJECT_DOCUMENTATION.md
│   ├── DATABASE_SCHEMA.md
│   └── PROJECT_OVERVIEW.md
│
├── django-backend/                # Django REST API Backend
│   ├── account/                   # User authentication & profiles
│   ├── blood_requests/            # Blood request management
│   ├── blood_types/               # Blood type reference
│   ├── donations/                 # Donation records & certificates
│   ├── sos/                       # Emergency SOS requests
│   ├── stats/                     # Statistics & analytics
│   ├── health/                    # Health eligibility quiz
│   ├── tests/                     # Backend tests
│   ├── logs/                      # Application logs
│   ├── profile_pictures/          # Uploaded profile pictures
│   ├── backend/                   # Django project settings
│   ├── manage.py
│   ├── requirements.txt
│   └── .env.example
│
└── flutter-project/               # Flutter Mobile App
    └── flutter_app/
        ├── android/               # Android platform code
        ├── ios/                   # iOS platform code
        ├── lib/
        │   ├── main.dart
        │   ├── app.dart
        │   ├── app_routes.dart
        │   ├── config/            # API configuration
        │   ├── models/            # Data models
        │   ├── screens/           # UI screens
        │   ├── services/          # API & Firebase services
        │   ├── widgets/           # Reusable widgets
        │   └── theme/             # App theming
        ├── pubspec.yaml
        └── FIREBASE_SETUP.md
```

## Technology Stack

### Backend
- **Framework**: Django 5.2.3 + Django REST Framework 3.15.2
- **Authentication**: JWT (Simple JWT 5.5.0)
- **Database**: MySQL / SQLite
- **SMS**: Twilio 9.0.0 (optional)
- **Email**: SMTP

### Frontend
- **Framework**: Flutter 3.12.0+
- **State Management**: Provider
- **Chat**: Firebase Cloud Firestore
- **Maps**: Geolocator
- **Storage**: SharedPreferences

## Features

- ✅ User registration with OTP phone verification
- ✅ JWT-based authentication with token refresh
- ✅ Blood request creation and management
- ✅ Donor pledge system
- ✅ Emergency SOS requests
- ✅ Health eligibility quiz
- ✅ Real-time donor-patient chat (Firebase)
- ✅ Location-based donor search
- ✅ Donation tracking with certificates
- ✅ Password reset via email/deep link

## Getting Started

### Prerequisites
- Python 3.9+
- Flutter SDK 3.12.0+
- MySQL 8.0+ (or SQLite for development)
- Firebase account (for chat feature)

### Backend Setup

```bash
cd django-backend

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment file
cp .env.example .env
# Edit .env with your configuration

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Seed blood types
python manage.py seed_blood_types

# Run server
python manage.py runserver
```

### Frontend Setup

```bash
cd flutter-project/flutter_app

# Get dependencies
flutter pub get

# Configure Firebase (see FIREBASE_SETUP.md)

# Run app
flutter run
```

## API Documentation

The API documentation is available in [docs/API_ENDPOINTS.md](docs/API_ENDPOINTS.md).

Key endpoints:
- Authentication: `/api/auth/`
- Blood Requests: `/api/blood-requests/`
- SOS Emergency: `/api/sos/`
- Donations: `/api/donations/`
- Statistics: `/api/stats/`

## Environment Variables

See [`.env.example`](django-backend/.env.example) for required environment variables.

## Testing

### Backend Tests
```bash
cd django-backend
python manage.py test
```

### Frontend Tests
```bash
cd flutter-project/flutter_app
flutter test
```

## Production Deployment

See backend deployment guide: [django-backend/PRODUCTION_DEPLOYMENT.md](django-backend/PRODUCTION_DEPLOYMENT.md)

## License

This project is private and proprietary.

## Support

For questions or support, please contact the development team.
