# Blood Donation Django Backend

RESTful API backend for the Blood Donation Flutter application with JWT authentication and OTP phone verification.

## Features

- ✅ User Registration & Login
- ✅ JWT Authentication with Token Refresh
- ✅ Phone Number Verification with OTP
- ✅ Profile Management
- ✅ Password Change
- ✅ Django Admin Integration
- ✅ CORS Support for Flutter
- ✅ Input Validation & Error Handling

## Tech Stack

- Django 5.2.3
- Django REST Framework 3.15.2
- Simple JWT 5.5.0
- SQLite (development) / PostgreSQL (production)

## Installation

### 1. Create Virtual Environment

```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Database Setup

```bash
python manage.py makemigrations
python manage.py migrate
```

### 4. Create Superuser (Optional)

```bash
python manage.py createsuperuser
```

### 5. Run Development Server

```bash
python manage.py runserver
```

The API will be available at `http://127.0.0.1:8000`

## API Endpoints

### Authentication

#### Register
```http
POST /api/auth/register/
Content-Type: application/json

{
    "email": "user@example.com",
    "password": "SecurePass123",
    "password_confirm": "SecurePass123",
    "full_name": "John Doe",
    "phone_num": "+1234567890",
    "address": "123 Street, City"
}
```

**Response (201 Created):**
```json
{
    "success": true,
    "message": "Registration successful. Please verify your phone number.",
    "user": {
        "id": "uuid",
        "email": "user@example.com",
        "full_name": "John Doe",
        "phone_num": "+1234567890",
        "phone_verified": false,
        "address": "123 Street, City",
        "date_joined": "2024-01-01T00:00:00Z"
    },
    "tokens": {
        "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
}
```

#### Login
```http
POST /api/auth/login/
Content-Type: application/json

{
    "email": "user@example.com",
    "password": "SecurePass123"
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "message": "Login successful.",
    "user": {...},
    "tokens": {
        "access": "...",
        "refresh": "..."
    }
}
```

#### Logout
```http
POST /api/auth/logout/
Content-Type: application/json
Authorization: Bearer <access_token>

{
    "refresh": "refresh_token_string"
}
```

#### Refresh Token
```http
POST /api/auth/token/refresh/
Content-Type: application/json

{
    "refresh": "refresh_token_string"
}
```

### OTP Verification

#### Send OTP
```http
POST /api/auth/send-otp/
Content-Type: application/json

{
    "phone_num": "+1234567890"
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "message": "OTP sent to +1234567890",
    "otp_code": "123456",  // REMOVE IN PRODUCTION!
    "expires_in": 600,
    "phone_num": "+1234567890"
}
```

#### Verify OTP
```http
POST /api/auth/verify-otp/
Content-Type: application/json

{
    "phone_num": "+1234567890",
    "otp_code": "123456"
}
```

**Response (200 OK):**
```json
{
    "success": true,
    "message": "Phone verified successfully",
    "user": {
        "id": "uuid",
        "phone_verified": true,
        ...
    }
}
```

#### Resend OTP
```http
POST /api/auth/resend-otp/
Content-Type: application/json

{
    "phone_num": "+1234567890"
}
```

### Profile Management

#### Get Profile
```http
GET /api/auth/profile/
Authorization: Bearer <access_token>
```

#### Update Profile
```http
PATCH /api/auth/profile/update/
Authorization: Bearer <access_token>
Content-Type: application/json

{
    "full_name": "John Updated Doe",
    "phone_num": "+9876543210",
    "address": "New address"
}
```

#### Change Password
```http
POST /api/auth/change-password/
Authorization: Bearer <access_token>
Content-Type: application/json

{
    "old_password": "OldPass123",
    "new_password": "NewPass123",
    "new_password_confirm": "NewPass123"
}
```

## Flutter Integration

### API Service Example

```dart
class ApiService {
  final baseUrl = 'http://10.0.2.2:8000/api/auth';  // For Android Emulator
  // final baseUrl = 'http://127.0.0.1:8000/api/auth';  // For iOS Simulator

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Login failed');
    }
  }
}
```

### Store Tokens Securely

Use `flutter_secure_storage` package:

```dart
final storage = FlutterSecureStorage();

// Save tokens
await storage.write(key: 'access', value: accessToken);
await storage.write(key: 'refresh', value: refreshToken);

// Retrieve tokens
final accessToken = await storage.read(key: 'access');
```

## Password Requirements

- Minimum 8 characters
- At least one letter
- At least one number
- Cannot be a common password
- Cannot be too similar to personal info

## Phone Number Format

Phone numbers must be in international format: `+999999999`

Examples:
- ✅ `+1234567890`
- ✅ `+91 98765 43210` (spaces are removed automatically)
- ❌ `9876543210` (missing country code)

## Development Notes

### OTP in Development

Currently, the OTP is returned in the API response for testing purposes. **REMOVE THIS IN PRODUCTION** and integrate with an SMS service:

### SMS Integration (Twilio Example)

```python
# In views.py, replace the OTP return with:
from twilio.rest import Client

def send_sms(phone_num, otp_code):
    client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    client.messages.create(
        body=f'Your Blood Donation verification code is: {otp_code}',
        from_=settings.TWILIO_PHONE_NUMBER,
        to=phone_num
    )
```

## Production Deployment Checklist

- [ ] Set `DEBUG = False` in settings
- [ ] Set `ALLOWED_HOSTS` to your domain
- [ ] Remove `CORS_ALLOW_ALL_ORIGINS = True`
- [ ] Add specific origins to `CORS_ALLOWED_ORIGINS`
- [ ] Remove OTP from API responses
- [ ] Use PostgreSQL instead of SQLite
- [ ] Set up environment variables for sensitive data
- [ ] Configure HTTPS/SSL
- [ ] Set up proper logging
- [ ] Configure email service for notifications
- [ ] Implement rate limiting
- [ ] Set up monitoring and analytics

## Environment Variables

Create a `.env` file in the project root:

```env
DEBUG=True
SECRET_KEY=your-secret-key-here
DATABASE_URL=sqlite:///db.sqlite3

# Twilio (for SMS)
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=your_twilio_number
```

## Error Response Format

All error responses follow this format:

```json
{
    "success": false,
    "message": "Human-readable error message",
    "errors": {
        "field_name": ["Specific error for this field"]
    }
}
```

## Admin Panel

Access Django Admin at `http://127.0.0.1:8000/admin/`

Features:
- User management
- View OTP status
- Bulk activate/deactivate users
- Mark phones as verified

## License

This project is part of the Blood Donation application.
