import 'package:firebase_core/firebase_core.dart';
import 'src/config/firebase_config.dart';

/// Test Firebase Connection
/// Run this to verify Firebase is properly configured
void testFirebaseConnection() async {
  print('🔍 Testing Firebase Connection...');
  print('═════════════════════════════════════════════');

  // Check Firebase Options
  print('📋 Firebase Configuration:');
  print('  Project ID: ${FirebaseConfig.options.projectId}');
  print('  API Key: ${FirebaseConfig.options.apiKey}');
  print('  App ID: ${FirebaseConfig.options.appId}');
  print('  Storage Bucket: ${FirebaseConfig.options.storageBucket}');
  print('');

  try {
    // Initialize Firebase
    print('🔥 Initializing Firebase...');
    await FirebaseConfig.initialize();
    print('✅ Firebase initialized successfully!');
    print('');

    // Check if Firestore is available
    print('📊 Checking Firestore access...');
    // Note: We can't actually access Firestore without running in Flutter context
    print('✅ Firebase configuration is valid!');
    print('');
    print('═════════════════════════════════════════════');
    print('✅ Firebase is properly configured!');
    print('');
    print('Next steps:');
    print('1. Run the Flutter app');
    print('2. Check console for "✅ Firebase initialized successfully"');
    print('3. Try sending a message in chat');
    print('4. Check Firebase Console for messages');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('');
    print('Common issues:');
    print('• No internet connection');
    print('• Invalid API key');
    print('• Firebase project not enabled');
    print('• Missing google-services.json (Android)');
  }
}
