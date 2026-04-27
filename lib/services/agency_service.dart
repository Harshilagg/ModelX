// lib/services/agency_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/agency_models.dart';
import 'email_service.dart';
import 'dart:math';

class AgencyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EmailService _emailService = EmailService();

  // Cache for the current agency ID the user is operating under
  String? _currentAgencyId;

  // Collection References
  CollectionReference get _agenciesRef => _db.collection('agency');
  CollectionReference get _invitesRef => _db.collection('agencyInvites');

  /// Gets the agency ID the current user belongs to.
  /// If the user is an owner, it returns their UID.
  /// If the user is a member, it returns the owner's UID from their linked profile.
  Future<String?> getOperatingAgencyId() async {
    if (_currentAgencyId != null) return _currentAgencyId;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _agenciesRef.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('ownerId')) {
        // Linked profile - return the actual owner's ID
        _currentAgencyId = data['ownerId'] as String;
      } else {
        // Owner profile - return their own UID
        _currentAgencyId = uid;
      }
      return _currentAgencyId;
    }
    return null;
  }

  /// Fetch all members of an agency
  Stream<List<AgencyMember>> getAgencyMembers(String agencyId) {
    return _agenciesRef
        .doc(agencyId)
        .collection('members')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AgencyMember.fromFirestore(doc.data()))
            .toList());
  }

  /// Create a new invitation (Additive - creates doc in agencyInvites)
  Future<void> createInvite({
    required String email,
    required AgencyRole role,
    required String fromAgencyId,
    required String fromAgencyName,
  }) async {
    final token = _generateRandomToken(32);
    final invite = AgencyInvite(
      id: '', 
      email: email,
      role: role,
      fromAgencyId: fromAgencyId,
      fromAgencyName: fromAgencyName,
      token: token,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
      status: 'pending',
    );

    // Using the collection name from firestore.rules
    await _invitesRef.add(invite.toFirestore());
    
    // Send Email
    final inviteLink = 'https://modelx-invite.onrender.com?token=$token'; // Hosted redirect URL
    await _emailService.sendInvitationEmail(
      recipientEmail: email,
      agencyName: fromAgencyName,
      role: role.toString().split('.').last,
      inviteLink: inviteLink,
    );
    
    await logActivity(fromAgencyId, 'Invited $email as ${role.toString().split('.').last}');
  }

  /// Fetch pending invites for an agency
  Stream<List<AgencyInvite>> getPendingInvites(String agencyId) {
    return _invitesRef
        .where('fromAgencyId', isEqualTo: agencyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AgencyInvite.fromFirestore(doc))
            .toList());
  }

  /// Revoke an invite
  Future<void> revokeInvite(String inviteId, String agencyId) async {
    await _invitesRef.doc(inviteId).update({'status': 'revoked'});
    await logActivity(agencyId, 'Revoked an invitation');
  }

  /// Remove a member
  Future<void> removeMember(String agencyId, String memberUid) async {
    // 1. Remove from agency members collection
    await _agenciesRef.doc(agencyId).collection('members').doc(memberUid).delete();
    // 2. Remove the linked agency profile for this user
    await _agenciesRef.doc(memberUid).delete();
    
    await logActivity(agencyId, 'Removed member $memberUid');
  }

  /// Helper: Generate a secure-ish random token
  String _generateRandomToken(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  /// Validate an invitation token
  Future<AgencyInvite> validateInviteToken(String token) async {
    final query = await _invitesRef
        .where('token', isEqualTo: token)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid or expired invitation');
    }

    final invite = AgencyInvite.fromFirestore(query.docs.first);
    if (invite.expiresAt.isBefore(DateTime.now())) {
      await _invitesRef.doc(invite.id).update({'status': 'expired'});
      throw Exception('Invitation has expired');
    }

    return invite;
  }

  /// Accept an invitation
  Future<void> acceptInvite(String token, String userUid) async {
    final invite = await validateInviteToken(token);

    final userDoc = await _db.collection('users').doc(userUid).get();
    if (!userDoc.exists) throw Exception('User profile not found');
    final userData = userDoc.data()!;

    await _db.runTransaction((transaction) async {
      // 1. Mark invite as accepted
      transaction.update(_invitesRef.doc(invite.id), {'status': 'accepted'});

      // 2. Create linked agency profile (if doesn't exist)
      // This ensures the user is routed to AgencyDashboardPage in AuthGate
      transaction.set(_agenciesRef.doc(userUid), {
        'ownerId': invite.fromAgencyId,
        'role': invite.role.toString().split('.').last,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 3. Add to agency members list
      transaction.set(_agenciesRef.doc(invite.fromAgencyId).collection('members').doc(userUid), {
        'uid': userUid,
        'fullName': userData['fullName'] ?? 'Team Member',
        'email': userData['email'] ?? '',
        'role': invite.role.toString().split('.').last,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      
      // 4. Update user document with agency association
      transaction.update(_db.collection('users').doc(userUid), {
        'activeAgencyId': invite.fromAgencyId,
        'agencyRole': invite.role.toString().split('.').last,
      });
    });

    await logActivity(invite.fromAgencyId, 'Member ${userData['fullName']} joined via invitation');
  }

  /// Log activity (Phase 6 requirement)
  Future<void> logActivity(String agencyId, String message) async {
    await _agenciesRef.doc(agencyId).collection('activity').add({
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'performedBy': _auth.currentUser?.uid,
    });
  }
}
