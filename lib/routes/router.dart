import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/export_screen.dart';
import '../screens/import_screen.dart';
import '../screens/duplicate_numbers_screen.dart';
import '../screens/duplicate_names_screen.dart';
import '../screens/duplicate_emails_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => ExportScreen(),
      ),
      GoRoute(
        path: '/import',
        builder: (context, state) => ImportScreen(),
      ),
      GoRoute(
        path: '/duplicate-numbers',
        builder: (context, state) => DuplicateNumbersScreen(),
      ),
      GoRoute(
        path: '/duplicate-names',
        builder: (context, state) => DuplicateNamesScreen(),
      ),
      GoRoute(
        path: '/duplicate-emails',
        builder: (context, state) => DuplicateEmailsScreen(),
      ),
    ],
  );
}
