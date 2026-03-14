import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/create_profile_page.dart';
import 'config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ui/app_theme.dart';
import 'brand/brand_dashboard_page.dart';
import 'agency/agency_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ModelX App',
      theme: AppTheme.light(),
      home: const AppEntry(),
    );
  }
}

/// Decides whether to show onboarding or auth flow
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool? hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hasSeenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hasSeenOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If the user is already signed in, show the auth gate immediately.
    if (FirebaseAuth.instance.currentUser != null) {
      return const AuthGate();
    }

    if (kForceShowOnboarding) {
      return OnboardingPage(
        onFinish: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('seen_onboarding', true);
        },
      );
    }

    return hasSeenOnboarding! ? const AuthGate() : OnboardingPage(
      onFinish: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('seen_onboarding', true);
      },
    );
  }
}

/// Shows Login or Dashboard based on FirebaseAuth state
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getHome(User user) async {
    final uid = user.uid;

    // 🔍 1. Check MODEL (users)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final profileCompleted = data != null && (data['profileCompleted'] == true);
      if (profileCompleted) return const DashboardPage();
      return const CreateProfilePage();
    }

    // 🔍 2. Check BRAND
    final brandDoc = await FirebaseFirestore.instance.collection('brands').doc(uid).get();
    if (brandDoc.exists) {
      return const BrandDashboardPage();
    }

    // 🔍 3. Check AGENCY
    final agencyDoc = await FirebaseFirestore.instance.collection('agency').doc(uid).get();
    if (agencyDoc.exists) {
      return const AgencyDashboardPage();
    }

    // ❌ Edge case: logged in but no profile -> sign out to show login
    await FirebaseAuth.instance.signOut();
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<Widget>(
          future: _getHome(user),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return snapshot.data!;
          },
        );
      },
    );
  }
}
