import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'src/app.dart';
import 'src/config/firebase_config.dart';
import 'src/providers/role_provider.dart';
import 'src/services/notification_service.dart';
import 'src/services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with manual configuration
  try {
    await FirebaseConfig.initialize();
  } catch (e) {
    // Continue without Firebase - app will work but chat won't function
  }

  // Initialize notification services
  try {
    await LocalNotificationService().initialize();
    await NotificationService().initialize();
  } catch (e) {
  }

  runApp(const LifeDropApp());
}
