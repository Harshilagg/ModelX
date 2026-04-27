// lib/models/agency_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum AgencyRole {
  owner,
  admin,
  booker,
  scout,
  member
}

class AgencyMember {
  final String uid;
  final String fullName;
  final String email;
  final AgencyRole role;
  final DateTime joinedAt;

  AgencyMember({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory AgencyMember.fromFirestore(Map<String, dynamic> data) {
    return AgencyMember(
      uid: data['uid'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      role: AgencyRole.values.firstWhere(
        (e) => e.toString().split('.').last == data['role'],
        orElse: () => AgencyRole.member,
      ),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role.toString().split('.').last,
      'joinedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AgencyInvite {
  final String id;
  final String email;
  final AgencyRole role;
  final String fromAgencyId;
  final String fromAgencyName;
  final String token;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status; // 'pending', 'accepted', 'expired'

  AgencyInvite({
    required this.id,
    required this.email,
    required this.role,
    required this.fromAgencyId,
    required this.fromAgencyName,
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  factory AgencyInvite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AgencyInvite(
      id: doc.id,
      email: data['email'] ?? '',
      role: AgencyRole.values.firstWhere(
        (e) => e.toString().split('.').last == data['role'],
        orElse: () => AgencyRole.member,
      ),
      fromAgencyId: data['fromAgencyId'] ?? '',
      fromAgencyName: data['fromAgencyName'] ?? '',
      token: data['token'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'role': role.toString().split('.').last,
      'fromAgencyId': fromAgencyId,
      'fromAgencyName': fromAgencyName,
      'token': token,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status,
    };
  }
}
