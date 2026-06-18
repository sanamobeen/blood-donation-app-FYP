import 'package:firebase_core/firebase_core.dart';

/// Manual Firebase Configuration
/// Use this if google-services.json is not working properly
class FirebaseConfig {
  static const FirebaseOptions options = FirebaseOptions(
    apiKey: 'AIzaSyBT60r_MItYoUPlSn61odWkni7V-jEqJws',
    appId: '1:156809188521:android:21bb03ff6b6a4ee11c85b8',
    messagingSenderId: '156809188521',
    projectId: 'blood-donation-chat',
    storageBucket: 'blood-donation-chat.firebasestorage.app',
  );

  static Future<void> initialize() async {
    await Firebase.initializeApp(options: options);
  }
}
