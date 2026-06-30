import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'theme/app_theme.dart';
import 'providers/role_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/requests/blood_request_detail_screen.dart';
import 'screens/messages/chat_conversation_screen_api.dart';

class LifeDropApp extends StatefulWidget {
  const LifeDropApp({super.key});

  @override
  State<LifeDropApp> createState() => _LifeDropAppState();
}

class _LifeDropAppState extends State<LifeDropApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
      if (parts.length >= 4) {
        final requestId = parts[3];
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
        title: 'LifeDrop',
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
