# Google Maps Setup Instructions

## Get Your Google Maps API Key

### Step 1: Create a Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "NEW PROJECT"
3. Enter project name (e.g., "Blood Donation App")
4. Click "CREATE"

### Step 2: Enable Maps SDK
1. In the left sidebar, go to **APIs & Services** → **Library**
2. Search for "Maps SDK for Android"
3. Click on it and click **ENABLE**
4. Repeat for "Maps SDK for iOS"

### Step 3: Create API Key
1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **API key**
3. Your API key will be created (copy it!)

### Step 4: Restrict API Key (Recommended)
1. Click on the API key you just created
2. Under "Application restrictions", select:
   - **Android apps**: Add your app's package name and SHA-1 fingerprint
   - **iOS apps**: Add your app's bundle ID
3. Under "API restrictions", select:
   - **Restrict key** → Select "Maps SDK for Android" and "Maps SDK for iOS"
4. Click **Save**

### Step 5: Add API Key to Your App

#### Android Configuration
Edit: `android/app/src/main/AndroidManifest.xml`

Replace:
```xml
<Google Maps API Key>
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

With:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="PASTE_YOUR_API_KEY_HERE"/>
```

#### iOS Configuration
Edit: `ios/Runner/AppDelegate.swift`

Replace:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
```

With:
```swift
GMSServices.provideAPIKey("PASTE_YOUR_API_KEY_HERE")
```

### Step 6: Install Dependencies
```bash
cd flutter-project/flutter_app
flutter pub get
```

### Step 7: Run the App
```bash
flutter run
```

---

## Using the Map Feature

1. **For Patients:**
   - Open the app as a Patient
   - You'll see a "Nearby Donors" floating button on the home screen
   - Tap it to see nearby donors on a map
   - Tap on donor markers to see their details

2. **Map Features:**
   - 🔵 **Blue marker** = Your location
   - 🟢 **Green markers** = Nearby donors
   - 📏 **Adjust search radius** (10, 25, 50, 100 km)
   - 🔄 **Refresh** to update donor list
   - 📍 **Tap markers** to see donor details

---

## Troubleshooting

### "Google Maps SDK not found"
- Make sure you've enabled "Maps SDK for Android" and "Maps SDK for iOS" in Google Cloud Console

### Blank map / No map tiles
- Check that your API key is correctly pasted
- Make sure your API key has Maps SDK enabled
- Check your internet connection

### Location permission denied
- Grant location permissions when prompted
- Enable location services in your device settings

### No markers showing
- Make sure donors have location data in the backend
- Check that the nearby donors API is working
- Try increasing the search radius

---

## Testing Without Real Devices

For development testing, you can mock location data:
```dart
// In nearby_donors_map_screen.dart
// Comment out real location and use mock data
_currentLat = 24.8607;  // Karachi coordinates
_currentLng = 67.0011;
```
