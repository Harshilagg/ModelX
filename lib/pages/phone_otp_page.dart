import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_profile_page.dart';

class PhoneOtpPage extends StatefulWidget {
  final String phoneNumber;

  const PhoneOtpPage({super.key, required this.phoneNumber});

  @override
  State<PhoneOtpPage> createState() => _PhoneOtpPageState();
}

class _PhoneOtpPageState extends State<PhoneOtpPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController otpController = TextEditingController();

  String? verificationId;
  bool loading = false;
  bool codeSent = false;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  // ------------------ SEND OTP ------------------
  Future<void> _sendOtp() async {
    setState(() => loading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto verification (Android only)
        await _linkPhoneCredential(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'OTP failed')),
        );
      },

      codeSent: (String verId, int? resendToken) {
        setState(() {
          verificationId = verId;
          loading = false;
          codeSent = true;
        });
      },

      codeAutoRetrievalTimeout: (String verId) {
        verificationId = verId;
      },
    );
  }

  // ------------------ VERIFY OTP ------------------
  Future<void> _verifyOtp() async {
    if (verificationId == null || otpController.text.length < 6) return;

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.text.trim(),
      );

      await _linkPhoneCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Invalid OTP')),
      );
    }
  }

  // ------------------ LINK PHONE TO USER ------------------
  Future<void> _linkPhoneCredential(PhoneAuthCredential credential) async {
    final user = _auth.currentUser!;

    await user.linkWithCredential(credential);

    // Mark phone verified in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'phoneVerified': true,
    });

    // After verification, redirect to Create Profile so users finish setup
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CreateProfilePage()),
      (_) => false,
    );
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone Number')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Text(
              'Enter the OTP sent to',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.phoneNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 32),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify & Continue'),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: loading ? null : _sendOtp,
              child: const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
