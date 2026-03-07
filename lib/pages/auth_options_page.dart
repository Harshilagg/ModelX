import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'login_page.dart';

class AuthOptionsPage extends StatelessWidget {
  const AuthOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Create your account',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how you want to get started',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            // Google
            _authButton(
              context,
              icon: Icons.g_mobiledata,
              label: 'Continue with Google',
              onTap: () {
                // Step 2: Google auth (we’ll implement next)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Google signup coming next')),
                );
              },
            ),

            const SizedBox(height: 16),

            // Phone
            _authButton(
              context,
              icon: Icons.phone,
              label: 'Continue with Phone',
              onTap: () {
                // Step 3: Phone OTP
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone signup coming next')),
                );
              },
            ),

            const SizedBox(height: 16),

            // Email
            _authButton(
              context,
              icon: Icons.email,
              label: 'Sign up',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupPage(userType: 'model',)),
                );
              },
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(color: Colors.grey),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _authButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
