// lib/agency/team_access/invite_acceptance_page.dart

import 'package:flutter/material.dart';
import '../../services/agency_service.dart';
import '../../models/agency_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/login_page.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/state_views.dart';

class InviteAcceptancePage extends StatefulWidget {
  final String token;
  final bool autoAcceptOnLoad;

  const InviteAcceptancePage({
    super.key,
    required this.token,
    this.autoAcceptOnLoad = false,
  });

  @override
  State<InviteAcceptancePage> createState() => _InviteAcceptancePageState();
}

class _InviteAcceptancePageState extends State<InviteAcceptancePage> {
  final AgencyService _agencyService = AgencyService();
  bool _isLoading = true;
  bool _acceptInProgress = false;
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
      if (widget.autoAcceptOnLoad && FirebaseAuth.instance.currentUser != null) {
        await _acceptInvite();
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
    if (_acceptInProgress) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Prompt login if not authenticated
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginPage(inviteToken: widget.token)),
      );
      return;
    }

    setState(() {
      _acceptInProgress = true;
      _isLoading = true;
      _error = null;
    });
    try {
      await _agencyService.acceptInvite(widget.token, user.uid);
      if (mounted) {
        showAppToast(context, 'Successfully joined the team!');
        // Navigate to dashboard
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Acceptance failed: $e';
          _isLoading = false;
          _acceptInProgress = false;
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
            ? const LoadingState()
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
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.paperRaised, shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, size: 30, color: AppColors.select),
          ),
          const SizedBox(height: 20),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Go Back',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
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
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: AppColors.goldBg, shape: BoxShape.circle),
            child: const Icon(Icons.group_add_outlined, size: 40, color: AppColors.gold),
          ),
          const SizedBox(height: 28),
          Text(
            'Invitation from ${_invite?.fromAgencyName}',
            textAlign: TextAlign.center,
            style: AppTypography.heading,
          ),
          const SizedBox(height: 8),
          Text(
            'You have been invited to join as a ${_invite?.role.toString().split('.').last.toUpperCase()}.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 48),
          AppButton(
            label: 'Accept and Join',
            expand: true,
            loading: _acceptInProgress,
            onPressed: _acceptInvite,
          ),
        ],
      ),
    );
  }
}
