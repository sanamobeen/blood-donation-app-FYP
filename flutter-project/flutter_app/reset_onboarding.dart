// Run this once to reset onboarding flag
// Add this to main.dart temporarily and run the app once

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('onboarding_completed');
  await prefs.remove('user_role');
  print('✅ Cleared onboarding and role flags');
  print('Now restart the app normally');
}
