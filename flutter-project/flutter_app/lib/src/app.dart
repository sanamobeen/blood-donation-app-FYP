import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_routes.dart';
import 'theme/app_theme.dart';
import 'providers/role_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/requests/blood_request_detail_screen.dart';
import 'screens/messages/chat_conversation_screen_api.dart';
import 'services/notification_service.dart';

class BloodDonorApp extends StatefulWidget {
  const BloodDonorApp({super.key});

  @override
  State<BloodDonorApp> createState() => _BloodDonorAppState();
}

class _BloodDonorAppState extends State<BloodDonorApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _initDeepLinks();
    // Set navigator key for notification service navigation
    NotificationService.navigatorKey = navigatorKey;
  }

  /// Initialize Firebase Core
  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        debugPrint('Firebase initialized successfully');
      } else {
        debugPrint('Firebase already initialized');
      }
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    // Handle deep links when app is already running
    _sub = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      if (kDebugMode) {
      }
    });

    // Handle deep link when app is launched from cold start
    _getInitialUri();
  }

  Future<void> _getInitialUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }

  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
    }

    // Handle reset password deep link
    // blooddonation://reset-password?email=user@example.com&token=uuid
    if (uri.scheme == 'blooddonation' && uri.path == '/reset-password') {
      final email = uri.queryParameters['email'];
      final token = uri.queryParameters['token'];

      if (kDebugMode) {
      }

      if (email != null && token != null) {
        if (kDebugMode) {
        }

        // Navigate to reset password screen
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.resetPassword,
          (route) => route.settings.name == AppRoutes.splash,
          arguments: {'email': email, 'token': token},
        );
      } else {
        if (kDebugMode) {
        }
      }
    } else {
      if (kDebugMode) {
      }
    }
  }

  final navigatorKey = GlobalKey<NavigatorState>();

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    // Handle blood request detail route: /blood-request-detail/{id}
    if (settings.name?.startsWith('/blood-request-detail/') == true) {
      final parts = settings.name?.split('/') ?? [];
      if (parts.length >= 3) {
        final requestId = parts[2];
        if (requestId.isNotEmpty) {
          return MaterialPageRoute(
            builder: (context) => BloodRequestDetailScreen(requestId: requestId),
            settings: settings,
          );
        }
      }
    }

    // Handle chat route: /chat/{conversationId}
    if (settings.name?.startsWith('/chat/') == true) {
      final parts = settings.name?.split('/') ?? [];
      if (parts.length >= 3) {
        final conversationId = parts[2];
        if (conversationId.isNotEmpty) {
          return MaterialPageRoute(
            builder: (context) => ChatConversationScreenApi(
              conversationId: conversationId,
            ),
            settings: settings,
          );
        }
      }
    }

    // TODO: Handle SOS detail route when SOSDetailScreen is implemented
    // For now, return null for unhandled routes
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'Blood Donor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        navigatorKey: navigatorKey,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }
}
