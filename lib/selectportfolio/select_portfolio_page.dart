import 'package:flutter/material.dart';
import '../pages/signup_page.dart';
import '../brand/brand_signup_page.dart';
import '../agency/agency_signup_page.dart';

class SelectPortfolioPage extends StatelessWidget {
  const SelectPortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Who are you?",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                  MaterialPageRoute(builder: (_) => const SignupPage(userType: 'Model')),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
