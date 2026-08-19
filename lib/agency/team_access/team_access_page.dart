import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/agency_models.dart';
import '../../services/agency_service.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/state_views.dart';

class TeamAccessPage extends StatefulWidget {
  const TeamAccessPage({super.key});

  @override
  State<TeamAccessPage> createState() => _TeamAccessPageState();
}

class _TeamAccessPageState extends State<TeamAccessPage> {
  final AgencyService _agencyService = AgencyService();
  String? _agencyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgencyId();
  }

  Future<void> _loadAgencyId() async {
    final id = await _agencyService.getOperatingAgencyId();
    if (mounted) {
      setState(() {
        _agencyId = id;
        _isLoading = false;
      });
    }
  }

  void _showInviteDialog() {
    if (_agencyId == null) return;

    final emailController = TextEditingController();
    AgencyRole selectedRole = AgencyRole.booker;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite Team Member', style: AppTypography.subheading),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Email Address',
                  hint: 'colleague@agency.com',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                Text('Role', style: AppTypography.label.copyWith(color: AppColors.inkSoft, letterSpacing: 0.08)),
                const SizedBox(height: 7),
                DropdownButtonFormField<AgencyRole>(
                  value: selectedRole,
                  items: AgencyRole.values.where((r) => r != AgencyRole.owner).map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.toString().split('.').last.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Send Invite',
                        onPressed: () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) return;

                          try {
                            await _agencyService.createInvite(
                              email: email,
                              role: selectedRole,
                              fromAgencyId: _agencyId!,
                              fromAgencyName: 'Your Agency', // Ideally fetch from agency profile
                            );
                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) {
                              showAppToast(context, 'Invitation sent to $email');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showAppToast(context, 'Error: $e', isError: true);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: LoadingState());
    if (_agencyId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.error_outline_rounded, title: 'Agency not found'));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Team Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Members'),
              Tab(text: 'Pending Invites'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showInviteDialog,
          backgroundColor: AppColors.ink,
          icon: const Icon(Icons.person_add, color: AppColors.paper),
          label: Text('Invite Member', style: AppTypography.bodyEmphasized.copyWith(color: AppColors.paper, fontWeight: FontWeight.w600)),
        ),
        body: TabBarView(
          children: [
            _buildMemberList(),
            _buildInviteList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList() {
    return StreamBuilder<List<AgencyMember>>(
      stream: _agencyService.getAgencyMembers(_agencyId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorStateView(message: 'Error: ${snapshot.error}');
        if (!snapshot.hasData) return const LoadingState();

        final members = snapshot.data!;
        if (members.isEmpty) {
          return const EmptyState(
            icon: Icons.groups_outlined,
            title: 'No team members yet',
            message: 'Invite colleagues to help manage this agency.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final member = members[index];
            final isSelf = member.uid == FirebaseAuth.instance.currentUser?.uid;

            return AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.paperRaised,
                    child: Text(
                      member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                      style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.fullName, style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          '${member.role.toString().split('.').last.toUpperCase()} • ${member.email}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  if (isSelf)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.goldBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('YOU', style: AppTypography.label.copyWith(color: AppColors.gold)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: AppColors.inkFaint),
                      onPressed: () => _showMemberOptions(member),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInviteList() {
    return StreamBuilder<List<AgencyInvite>>(
      stream: _agencyService.getPendingInvites(_agencyId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorStateView(message: 'Error: ${snapshot.error}');
        if (!snapshot.hasData) return const LoadingState();

        final invites = snapshot.data!;
        if (invites.isEmpty) {
          return const EmptyState(
            icon: Icons.mail_outline_rounded,
            title: 'No pending invitations',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: invites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final invite = invites[index];
            return AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invite.email, style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          'Role: ${invite.role.toString().split('.').last.toUpperCase()} • Expires: ${invite.expiresAt.day}/${invite.expiresAt.month}',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _agencyService.revokeInvite(invite.id, _agencyId!),
                    style: TextButton.styleFrom(foregroundColor: AppColors.select),
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMemberOptions(AgencyMember member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: AppColors.select),
              title: Text('Remove from Team', style: AppTypography.bodyEmphasized.copyWith(color: AppColors.select, fontWeight: FontWeight.w600)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: AppColors.paper,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remove Member', style: AppTypography.subheading),
                          const SizedBox(height: 12),
                          Text(
                            'Are you sure you want to remove ${member.fullName}? They will lose access immediately.',
                            style: AppTypography.body.copyWith(color: AppColors.inkSoft),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'Cancel',
                                  variant: AppButtonVariant.ghost,
                                  onPressed: () => Navigator.pop(context, false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppButton(
                                  label: 'Remove',
                                  variant: AppButtonVariant.destructive,
                                  onPressed: () => Navigator.pop(context, true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (confirm == true) {
                  await _agencyService.removeMember(_agencyId!, member.uid);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
