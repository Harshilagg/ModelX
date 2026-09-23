import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'onboarding/onboarding_flow.dart';
import 'onboarding/onboarding_theme.dart';
import 'pages/create_profile_page.dart';
import 'config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ui/app_theme.dart';
import 'ui/theme_controller.dart';
import 'brand/brand_dashboard_page.dart';
import 'agency/agency_dashboard_page.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'agency/team_access/invite_acceptance_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter prints the full details — the error-causing widget and the
  // stack — only for the *first* occurrence of an exception, and
  // abbreviates every repeat to "Another exception was thrown: ...".
  // In a widget that rebuilds, the useful report scrolls away and only
  // the useless one-liner keeps appearing. forceReport prints all of it,
  // every time, in debug builds only.
  if (kDebugMode) {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
  }

  // The theme preference is read here, not in an initState or a
  // FutureBuilder, because anything that resolves after the first frame
  // paints the app in the wrong theme and then corrects itself. Startup
  // is already waiting on Firebase, so this costs nothing.
  final results = await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    ThemeController.load(),
  ]);

  runApp(MyApp(themeController: results[1] as ThemeController));
}

class MyApp extends StatefulWidget {
  final ThemeController themeController;

  const MyApp({super.key, required this.themeController});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check initial link if app was opened via one
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen to incoming links while app is open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Received Deep Link: $uri');
    if (uri.host == 'invite' && uri.queryParameters.containsKey('token')) {
      final token = uri.queryParameters['token']!;
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => InviteAcceptancePage(token: token)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds only when the mode changes, which while
    // kThemeSwitchingEnabled is false is never.
    return ThemeScope(
      controller: widget.themeController,
      child: AnimatedBuilder(
        animation: widget.themeController,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'ModelX App',
          theme: AppTheme.light(),
          darkTheme: AppTheme.night(),
          themeMode: widget.themeController.mode,
          home: const AppEntry(),
        ),
      ),
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
    if (!mounted) return;
    setState(() {
      hasSeenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decodes the splash photographs while this screen is still
    // deciding what to show, so the masonry's first frame is a wall of
    // images rather than a wall of empty rectangles.
    OnboardingPhotos.precache(context);
  }

  @override
  Widget build(BuildContext context) {
    if (hasSeenOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If the user is already signed in, show the auth gate immediately.
    if (FirebaseAuth.instance.currentUser != null) {
      return const AuthGate();
    }

    if (kForceShowOnboarding) return const OnboardingFlow();

    // The flow records `seen_onboarding` itself, when the user leaves
    // the splash rather than when they finish signing up.
    return hasSeenOnboarding! ? const AuthGate() : const OnboardingFlow();
  }
}

/// Shows Login or Dashboard based on FirebaseAuth state
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _getHome(User user) async {
    final uid = user.uid;

    // 🔍 1. Check MODEL (users)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final profileCompleted =
          data != null && (data['profileCompleted'] == true);
      if (profileCompleted) return const DashboardPage();
      return const CreateProfilePage();
    }

    // 🔍 2. Check BRAND
    final brandDoc = await FirebaseFirestore.instance
        .collection('brands')
        .doc(uid)
        .get();
    if (brandDoc.exists) {
      return const BrandDashboardPage();
    }

    // 🔍 3. Check AGENCY
    final agencyDoc = await FirebaseFirestore.instance
        .collection('agency')
        .doc(uid)
        .get();
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
