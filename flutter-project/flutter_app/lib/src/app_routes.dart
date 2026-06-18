import 'package:flutter/material.dart';

import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/change_password_step1_screen.dart';
import 'screens/auth/change_password_step2_screen.dart';
import 'screens/ai_chatbot/ai_chatbot_screen.dart';
import 'screens/blood_request/blood_request_form_screen.dart';
import 'screens/donations/my_donations_screen.dart';
// import 'screens/home/home_screen.dart'; // Removed - using MainNavigationScreen instead
import 'screens/messages/messages_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/onboarding_screen_2.dart';
import 'screens/onboarding/onboarding_screen3.dart';
import 'screens/patient_home/patient_home_screen.dart';
// Quiz feature removed from donor side
// import 'screens/quiz/health_eligibility_quiz_screen.dart';
import 'screens/donors/donor_profile_screen.dart';
import 'screens/donors/find_donors_screen.dart';
import 'screens/patient/nearby_donors_map_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/requests/my_requests_screen.dart';
import 'screens/requests/nearby_requests_screen.dart';
import 'screens/role_selection/role_selection_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'screens/sos/sos_active_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/about/about_screen.dart';
import 'screens/about/legal_terms_screen.dart';
import 'screens/medical/medical_info_screen.dart';
import 'screens/role/role_switch_screen.dart';
import 'screens/main/main_navigation_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const onboarding2 = '/onboarding-2';
  static const onboarding3 = '/onboarding-3';
  static const roleSelection = '/role-selection';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const changePassword = '/change-password'; // Step 1 screen
  static const profileSetup = '/profile-setup';
  static const home = '/home';
  static const mainNavigation = '/main-navigation';
  static const sos = '/sos';
  static const sosActive = '/sos-active';
  static const myDonations = '/my-donations';
  static const donorProfile = '/donor-profile';
  static const findDonors = '/find-donors';
  static const nearbyDonorsMap = '/nearby-donors-map';
  static const myRequests = '/my-requests';
  static const nearbyRequests = '/nearby-requests';
  static const messages = '/messages';
  static const chatList = '/chat-list';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const patientHome = '/patient-home';
  static const bloodRequestForm = '/blood-request-form';
  // Quiz feature removed from donor side
  // static const healthEligibilityQuiz = '/health-eligibility-quiz';
  static const aiChatbot = '/ai-chatbot';
  static const settings = '/settings';
  static const help = '/help';
  static const about = '/about';
  static const legalTerms = '/legal-terms';
  static const medicalInfo = '/medical-info';
  static const roleSwitch = '/role-switch';
  static const adminDashboard = '/admin/dashboard';
  static const adminUsers = '/admin/users';
  static const adminUserDetail = '/admin/user-detail';
  static const adminAnalytics = '/admin/analytics';

  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    onboarding: (context) => const OnboardingScreen(),
    onboarding2: (context) => const OnboardingScreen2(),
    onboarding3: (context) => const OnboardingScreen3(),
    roleSelection: (context) => const RoleSelectionScreen(),
    login: (context) => const LoginScreen(),
    signUp: (context) => const SignUpScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    resetPassword: (context) => const ResetPasswordScreen(),
    changePassword: (context) => const ChangePasswordStep1Screen(),
    profileSetup: (context) => const ProfileSetupScreen(),
    home: (context) => const MainNavigationScreen(), // Redirect to MainNavigationScreen
    mainNavigation: (context) => const MainNavigationScreen(),
    sos: (context) => const SOSScreen(),
    sosActive: (context) => const SOSActiveScreen(),
    findDonors: (context) => const FindDonorsScreen(),
    donorProfile: (context) {
      final donor = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return DonorProfileScreen(donor: donor ?? {});
    },
    nearbyDonorsMap: (context) => const NearbyDonorsMapScreen(),
    myRequests: (context) => const MyRequestsScreen(),
    nearbyRequests: (context) => const NearbyRequestsScreen(),
    messages: (context) => const MessagesScreen(),
    chatList: (context) => const MessagesScreen(),
    notifications: (context) => const NotificationsScreen(),
    myDonations: (context) => const MyDonationsScreen(),
    profile: (context) => const ProfileScreen(),
    editProfile: (context) => const EditProfileScreen(),
    patientHome: (context) => const PatientHomeScreen(),
    bloodRequestForm: (context) => const BloodRequestFormScreen(),
    // Quiz feature removed from donor side
    // healthEligibilityQuiz: (context) => const HealthEligibilityQuizScreen(),
    aiChatbot: (context) => const AIChatbotScreen(),
    settings: (context) => const SettingsScreen(),
    help: (context) => const HelpScreen(),
    about: (context) => const AboutScreen(),
    legalTerms: (context) => const LegalTermsScreen(),
    medicalInfo: (context) => const MedicalInfoScreen(),
    roleSwitch: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return RoleSwitchScreen(currentRole: args?['currentRole'] ?? 'patient');
    },
    adminDashboard: (context) => const AdminDashboardScreen(),
  };
}
