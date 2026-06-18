# Firebase Chat Setup Guide

This guide will help you set up Firebase Cloud Firestore for the donor-patient chat functionality.

## Prerequisites

1. A Firebase project (create one at https://console.firebase.google.com/)
2. Flutter project with Firebase dependencies installed ✅ (Already done)

## Step-by-Step Setup

### 1. Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: "blood-donation-chat"
4. Click "Create project"

### 2. Add Android App

1. In Firebase Console, click the Android icon (Add app)
2. Enter package name: `com.example.flutter_app`
3. Click "Register app"
4. Download `google-services.json`
5. Place it in: `android/app/google-services.json`

### 3. Add iOS App (Optional)

1. In Firebase Console, click the iOS icon (Add app)
2. Enter bundle ID: `com.example.flutterApp`
3. Click "Register app"
4. Download `GoogleService-Info.plist`
5. Place it in: `ios/Runner/GoogleService-Info.plist`

### 4. Enable Cloud Firestore

1. In Firebase Console, go to "Build" → "Firestore Database"
2. Click "Create database"
3. Choose location (e.g., nam5/us-central)
4. Select "Start in Test Mode" (for development)
5. Click "Enable"

### 5. Set Firestore Rules

In Firebase Console → Firestore → Rules, use these rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Conversations collection
    match /conversations/{conversationId} {
      // Allow read if user is a participant
      allow read: if request.auth != null &&
        (resource.data.participant1_id == request.auth.uid ||
         resource.data.participant2_id == request.auth.uid);
      
      // Allow create if authenticated
      allow create: if request.auth != null;
      
      // Allow update if user is a participant
      allow update: if request.auth != null &&
        (resource.data.participant1_id == request.auth.uid ||
         resource.data.participant2_id == request.auth.uid);
      
      // Messages subcollection
      match /messages/{messageId} {
        // Allow read if conversation participant
        allow read: if request.auth != null &&
          get(/databases/$(database)/documents/conversations/$(conversationId))
          .data.participant1_id == request.auth.uid ||
          get(/databases/$(database)/documents/conversations/$(conversationId))
          .data.participant2_id == request.auth.uid;
        
        // Allow create if conversation participant
        allow create: if request.auth != null &&
          (get(/databases/$(database)/documents/conversations/$(conversationId))
           .data.participant1_id == request.auth.uid ||
           get(/databases/$(database)/documents/conversations/$(conversationId))
           .data.participant2_id == request.auth.uid);
        
        // Allow update if sender
        allow update: if request.auth != null &&
          resource.data.sender_id == request.auth.uid;
      }
    }
  }
}
```

### 6. Update Android Configuration

In `android/build.gradle`, add:

```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

In `android/app/build.gradle`, add:

```gradle
plugins {
    id 'com.android.application'
    // Add this line
    id 'com.google.gms.google-services'
}
```

### 7. Update iOS Configuration (If applicable)

In `ios/Podfile`, add:

```ruby
pod 'Firebase/Core'
pod 'Firebase/Firestore'
```

Then run:
```bash
cd ios
pod install
```

## Testing the Chat

Once Firebase is set up:

1. Run the app: `flutter run`
2. Login as a donor
3. Navigate to a blood request
4. Click "I Can Help" and pledge
5. Chat will open automatically between donor and patient
6. Send messages to test real-time sync

## Troubleshooting

### "Firebase not initialized" Error
- Ensure `google-services.json` is in `android/app/` folder
- Check that Firebase is initialized in `main.dart`

### "Permission Denied" Errors
- Verify Firestore rules are set correctly
- Check that user is authenticated
- Ensure collection names match (`conversations`, `messages`)

### Chat not syncing
- Check internet connection
- Verify Firebase project is active
- Enable Firestore indexing

## Chat Features

✅ **Real-time messaging** - Messages sync instantly
✅ **Conversation management** - Auto-created on pledge
✅ **Message status** - Read receipts supported
✅ **System messages** - Auto-generated notifications
✅ **User identification** - Donor/Patient roles shown

## Next Steps

1. Set up Firebase project following steps above
2. Download `google-services.json` and place in `android/app/`
3. Update Android build.gradle files
4. Enable Cloud Firestore in Firebase Console
5. Set Firestore rules
6. Run `flutter clean && flutter pub get`
7. Test chat functionality!

For more information, visit:
- Firebase Flutter Setup: https://firebase.flutter.dev/docs/overview
- Cloud Firestore Guide: https://firebase.google.com/docs/firestore
