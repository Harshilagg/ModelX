import 'package:flutter/material.dart';
import 'login_page.dart';
import '../selectportfolio/select_portfolio_page.dart';
import '../ui/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  final Future<void> Function()? onFinish;

  const OnboardingPage({super.key, this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int index = 0;
  bool _isProcessing = false;

  final List<Map<String, String>> content = [
    {
      'title': 'WELCOME TO MODELX',
      'subtitle': 'A simple, private and meaningful way to connect and grow.',
    },
    {
      'title': 'Built for Real People',
      'subtitle': 'Authentic profiles, real conversations, and trusted connections.',
    },
    {
      'title': 'Designed for the Future',
      'subtitle': 'A platform built to empower individuals and organizations.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.backstageRaised, AppColors.backstage],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: content.length,
                  onPageChanged: (i) => setState(() => index = i),
                  itemBuilder: (_, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            content[i]['title']!,
                            textAlign: TextAlign.center,
                            style: AppTypography.display.copyWith(
                              fontSize: 30,
                              color: AppColors.onBackstage,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            content[i]['subtitle']!,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              fontSize: 16,
                              color: AppColors.onBackstageSoft,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  content.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.all(4),
                    height: 8,
                    width: index == i ? 22 : 8,
                    decoration: BoxDecoration(
                      color: index == i
                          ? AppColors.onBackstage
                          : AppColors.onBackstage.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // GET STARTED → SIGNUP
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.onBackstage,
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (widget.onFinish != null) {
                            setState(() => _isProcessing = true);
                            var success = false;
                            try {
                              await widget.onFinish!();
                              success = true;
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isProcessing = false);
                            }

                            if (success && mounted) {
                              // Replace onboarding with signup so Back does not return to onboarding
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SelectPortfolioPage(),
                                ),
                              );
                            }
                          } else {
                            // No parent callback provided — still replace onboarding route
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SelectPortfolioPage(),
                              ),
                            );
                          }
                        },
                  child: _isProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Please wait...',
                              style: AppTypography.bodyEmphasized.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Sign up / Login',
                          style: AppTypography.bodyEmphasized.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // LOGIN LINK
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.onBackstageSoft,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Replace onboarding with login so the user cannot navigate back to onboarding
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Login',
                      style: AppTypography.bodyEmphasized.copyWith(
                        color: AppColors.onBackstage,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
