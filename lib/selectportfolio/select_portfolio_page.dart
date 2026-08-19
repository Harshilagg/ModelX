import 'package:flutter/material.dart';
import '../pages/signup_page.dart';
import '../brand/brand_signup_page.dart';
import '../agency/agency_signup_page.dart';
import '../ui/app_theme.dart';

class SelectPortfolioPage extends StatelessWidget {
  final String? inviteToken;

  const SelectPortfolioPage({super.key, this.inviteToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text("Who are you?"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            _optionCard(
              context,
              title: "I'm a Model",
              subtitle:
                  "Create your professional profile, showcase your portfolio and get discovered.",
              icon: Icons.person_outline,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => SignupPage(userType: 'Model', inviteToken: inviteToken)),
                );
              },
            ),

            const SizedBox(height: 20),

            _optionCard(
              context,
              title: "I'm a Brand",
              subtitle:
                  "Hire talent, post projects, and collaborate with professionals.",
              icon: Icons.business_outlined,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BrandSignupPage()),
                );
              },
            ),
            const SizedBox(height: 20),

            _optionCard(
              context,
              title: "I'm an Agency",
              subtitle: "Register your agency, manage talent and castings.",
              icon: Icons.apartment_outlined,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AgencySignupPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.goldBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: AppIconSize.lg, color: AppColors.gold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.subheading),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: AppTypography.body.copyWith(color: AppColors.inkSoft, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
