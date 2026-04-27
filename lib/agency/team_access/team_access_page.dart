import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/agency_models.dart';
import '../../services/agency_service.dart';

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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite Team Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address', hintText: 'colleague@agency.com'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AgencyRole>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
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
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invitation sent to $email'))
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_agencyId == null) return const Scaffold(body: Center(child: Text('Error: Agency not found')));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Team Management', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Members'),
              Tab(text: 'Pending Invites'),
            ],
            indicatorColor: Color(0xFF0F172A),
            labelColor: Color(0xFF0F172A),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showInviteDialog,
          backgroundColor: const Color(0xFF0F172A),
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text('Invite Member', style: TextStyle(color: Colors.white)),
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
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final members = snapshot.data!;
        if (members.isEmpty) return const Center(child: Text('No team members yet.'));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final member = members[index];
            final isSelf = member.uid == FirebaseAuth.instance.currentUser?.uid;
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Text(member.fullName.isNotEmpty ? member.fullName[0] : '?'),
              ),
              title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${member.role.toString().split('.').last.toUpperCase()} • ${member.email}'),
              trailing: isSelf ? const Chip(label: Text('YOU')) : IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showMemberOptions(member),
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
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final invites = snapshot.data!;
        if (invites.isEmpty) return const Center(child: Text('No pending invitations.'));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: invites.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final invite = invites[index];
            return ListTile(
              title: Text(invite.email),
              subtitle: Text('Role: ${invite.role.toString().split('.').last.toUpperCase()} • Expires: ${invite.expiresAt.day}/${invite.expiresAt.month}'),
              trailing: TextButton(
                onPressed: () => _agencyService.revokeInvite(invite.id, _agencyId!),
                child: const Text('Revoke', style: TextStyle(color: Colors.red)),
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const Text('Remove from Team', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Member'),
                    content: Text('Are you sure you want to remove ${member.fullName}? They will lose access immediately.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                    ],
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
