// lib/agency/team_access/invite_acceptance_page.dart

import 'package:flutter/material.dart';
import '../../services/agency_service.dart';
import '../../models/agency_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/login_page.dart';

class InviteAcceptancePage extends StatefulWidget {
  final String token;
  const InviteAcceptancePage({super.key, required this.token});

  @override
  State<InviteAcceptancePage> createState() => _InviteAcceptancePageState();
}

class _InviteAcceptancePageState extends State<InviteAcceptancePage> {
  final AgencyService _agencyService = AgencyService();
  bool _isLoading = true;
  String? _error;
  AgencyInvite? _invite;

  @override
  void initState() {
    super.initState();
    _validateInvite();
  }

  Future<void> _validateInvite() async {
    try {
      final invite = await _agencyService.validateInviteToken(widget.token);
      if (mounted) {
        setState(() {
          _invite = invite;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptInvite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Prompt login if not authenticated
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _agencyService.acceptInvite(widget.token, user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the team!'))
        );
        // Navigate to dashboard
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Acceptance failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Team')),
      body: Center(
        child: _isLoading 
          ? const CircularProgressIndicator()
          : _error != null
            ? _buildErrorView()
            : _buildInviteView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_add_outlined, size: 64, color: Color(0xFF0F172A)),
          const SizedBox(height: 24),
          Text(
            'Invitation from ${_invite?.fromAgencyName}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You have been invited to join as a ${_invite?.role.toString().split('.').last.toUpperCase()}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _acceptInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Accept and Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
