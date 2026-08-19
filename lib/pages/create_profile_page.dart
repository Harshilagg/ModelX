import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../agency/scouting/ai_scout_service.dart'; // Import AI Service
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

class CreateProfilePage extends StatefulWidget {
  final VoidCallback? onComplete; // for tests or custom flows to avoid Firebase calls

  const CreateProfilePage({super.key, this.onComplete});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();

  bool loading = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Prefill display name if available from auth (useful for Google users)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null) displayNameController.text = user.displayName!;

      // Prefill username and bio from firestore if exists
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['username'] != null) usernameController.text = data['username'];
          if (data['bio'] != null) bioController.text = data['bio'];
        }
      }).catchError((e) {
        // ignore errors here
      });
    }
  }

  Future<void> finishProfile() async {
    if (!_formKey.currentState!.validate()) return;
    // If an onComplete callback is provided (tests), skip Firebase writes and just call it
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }

    setState(() => loading = true);
    final user = FirebaseAuth.instance.currentUser!;
    final desiredUsername = usernameController.text.trim();

    // Validate username uniqueness (case-insensitive when usernameLower is available)
    if (desiredUsername.isNotEmpty) {
      final lower = desiredUsername.toLowerCase();
      final qLower = await FirebaseFirestore.instance.collection('users').where('usernameLower', isEqualTo: lower).get();
      final qExact = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: desiredUsername).get();
      final taken = qLower.docs.any((d) => d.id != user.uid) || qExact.docs.any((d) => d.id != user.uid);
      if (taken) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username already taken. Please choose another.')),
        );
        return;
      }
    }

    final profileData = {
      'fullName': displayNameController.text.trim(),
      'fullNameLower': displayNameController.text.trim().toLowerCase(),
      'username': desiredUsername,
      'usernameLower': desiredUsername.isNotEmpty ? desiredUsername.toLowerCase() : null,
      'bio': bioController.text.trim(),
      'profileCompleted': true,
    };

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(profileData, SetOptions(merge: true));

    // AUTO-SYNC: Index new user for AI Search
    AiScoutService().indexProfile(user.uid, profileData).catchError((e) {
      debugPrint('AI Initial Sync failed: $e');
    });

    setState(() => loading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile completed — welcome ${displayNameController.text.trim()}!')),
    );

    //Clear the navigation stack and make Dashboard the root so Back doesn't reveal auth/onboarding
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use a simple two-step Stepper for clarity: Profile info -> About
    return Scaffold(
      appBar: AppBar(title: const Text('Create your profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Stepper(
            currentStep: _currentStep,
            connectorColor: WidgetStateProperty.all(AppColors.line),
            connectorThickness: 2,
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: details.stepIndex == 0 ? 'Continue' : 'Finish',
                        onPressed: details.stepIndex == 1 && loading ? null : details.onStepContinue,
                        loading: details.stepIndex == 1 && loading,
                        expand: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Back',
                        variant: AppButtonVariant.secondary,
                        onPressed: details.onStepCancel,
                        expand: true,
                      ),
                    ),
                  ],
                ),
              );
            },
            onStepContinue: () {
              if (_currentStep == 0) {
                // validate first step fields
                if (displayNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a display name')));
                  return;
                }
                if (usernameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a username')));
                  return;
                }
                setState(() => _currentStep = 1);
              } else {
                finishProfile();
              }
            },
            onStepCancel: () {
              if (_currentStep == 0) return;
              setState(() => _currentStep = 0);
            },
            steps: [
              Step(
                title: const Text('Profile'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (FirebaseAuth.instance.currentUser?.providerData.any((p) => p.providerId.contains('google')) == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'We retrieved some info from your Google account — please confirm or edit below.',
                          style: AppTypography.caption.copyWith(color: AppColors.inkSoft),
                        ),
                      ),
                    AppTextField(
                      label: 'Display name',
                      controller: displayNameController,
                      validator: (v) => v!.isEmpty ? 'Enter a display name' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Username (letters, numbers, underscores)',
                      controller: usernameController,
                      validator: (v) {
                        final s = v ?? '';
                            final reg = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
                        if (s.isEmpty) return 'Enter a username';
                        if (!reg.hasMatch(s)) return 'Use letters, numbers, underscores; 3-30 chars';
                        return null;
                      },
                    ),
                  ],
                ),
                isActive: _currentStep == 0,
              ),
              Step(
                title: const Text('About'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Short bio',
                      controller: bioController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Finish',
                      onPressed: loading ? null : finishProfile,
                      loading: loading,
                      expand: true,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Skip for now',
                      variant: AppButtonVariant.ghost,
                      expand: true,
                      onPressed: loading
                          ? null
                          : () async {
                              // Allow user to skip finishing the profile for now.
                              setState(() => loading = true);
                              final user = FirebaseAuth.instance.currentUser!;
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                'profileCompleted': false,
                              }, SetOptions(merge: true));
                              setState(() => loading = false);
                              if (!mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const DashboardPage()),
                                (route) => false,
                              );
                            },
                    ),
                  ],
                ),
                isActive: _currentStep == 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
