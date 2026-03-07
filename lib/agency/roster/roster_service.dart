import 'package:cloud_firestore/cloud_firestore.dart';

class RosterService {
  final _db = FirebaseFirestore.instance;

  Future<QuerySnapshot> fetchAgencyModels(String agencyId) async {
    return _db.collection('models').where('agencyId', isEqualTo: agencyId).orderBy('createdAt', descending: true).get();
  }

  Future<DocumentSnapshot> getModelById(String modelId) async {
    return _db.collection('models').doc(modelId).get();
  }

  Future<void> addModelToAgency(String modelId, String agencyId) async {
    await _db.collection('models').doc(modelId).update({'agencyId': agencyId});
  }

  Future<void> inviteModel(String agencyId, String email, Map<String, dynamic> inviteMeta) async {
    final doc = _db.collection('agencyInvites').doc();
    await doc.set({
      'agencyId': agencyId,
      'email': email,
      'meta': inviteMeta,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Future<void> unlinkModel(String modelId) async {
    await _db.collection('models').doc(modelId).update({'agencyId': FieldValue.delete()});
  }
}
