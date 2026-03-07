import 'package:cloud_firestore/cloud_firestore.dart';

class CastingService {
  final _db = FirebaseFirestore.instance;

  Future<DocumentReference> createCasting(Map<String, dynamic> data) async {
    final doc = await _db.collection('castings').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'status': data['status'] ?? 'open',
    });
    return doc;
  }

  Future<QuerySnapshot> fetchCastingsForAgency(String agencyId) async {
    // Default fetch: returns most recent castings for the agency.
    return _db.collection('castings').where('agencyId', isEqualTo: agencyId).orderBy('createdAt', descending: true).get();
  }

  /// Paginated fetch: provide optional [startAfter] document to page through results.
  Future<QuerySnapshot> fetchCastingsForAgencyPage(String agencyId, {DocumentSnapshot? startAfter, int limit = 20}) async {
    Query q = _db.collection('castings').where('agencyId', isEqualTo: agencyId).orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    return q.get();
  }

  Future<DocumentSnapshot> getCasting(String id) async {
    return _db.collection('castings').doc(id).get();
  }

  Future<void> applyToCasting(String castingId, Map<String, dynamic> applicant) async {
    final applicantsRef = _db.collection('castings').doc(castingId).collection('applicants');
    final modelId = (applicant['modelId'] as String?);

    if (modelId == null || modelId.isEmpty) {
      // fallback: add and increment count (no dedupe possible)
      await applicantsRef.add({
        ...applicant,
        'appliedAt': FieldValue.serverTimestamp(),
        'status': applicant['status'] ?? 'pending',
      });
      await _db.collection('castings').doc(castingId).update({'applicationsCount': FieldValue.increment(1)});
      return;
    }

    final docRef = applicantsRef.doc(modelId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) {
        return;
      }
      tx.set(docRef, {
        ...applicant,
        'appliedAt': FieldValue.serverTimestamp(),
        'status': applicant['status'] ?? 'pending',
      });
      final castingDoc = _db.collection('castings').doc(castingId);
      tx.update(castingDoc, {'applicationsCount': FieldValue.increment(1)});
    });
  }

  Future<QuerySnapshot> fetchApplicants(String castingId) async {
    return _db.collection('castings').doc(castingId).collection('applicants').orderBy('appliedAt', descending: true).get();
  }

  Future<void> updateApplicantStatus(String castingId, String applicantId, String status) async {
    await _db.collection('castings').doc(castingId).collection('applicants').doc(applicantId).update({'status': status});
  }
}
