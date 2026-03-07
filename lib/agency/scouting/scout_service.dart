import 'package:cloud_firestore/cloud_firestore.dart';

class ScoutService {
  final _db = FirebaseFirestore.instance;

  Future<QuerySnapshot> searchModels({String query = '', Map<String, dynamic>? filters}) async {
    var col = _db.collection('models');
    Query q = col;
    if (query.isNotEmpty) {
      q = q.where('searchKeywords', arrayContains: query.toLowerCase());
    }
    if (filters != null) {
      if (filters['gender'] != null) q = q.where('gender', isEqualTo: filters['gender']);
      if (filters['minAge'] != null) q = q.where('age', isGreaterThanOrEqualTo: filters['minAge']);
      if (filters['maxAge'] != null) q = q.where('age', isLessThanOrEqualTo: filters['maxAge']);
    }
    return q.limit(50).get();
  }

  // Search the `users` collection (models stored under users).
  // Returns merged results from several prefix queries to emulate OR behavior
  // across `username` and `fullName` fields. All additional filters are
  // applied client-side by `ScoutPage` to avoid composite-index requirements.
  Future<List<Map<String, dynamic>>> searchUsers({String query = '', Map<String, dynamic>? filters}) async {
    final collection = _db.collection('users');

    // If empty query, fetch a reasonable page (limit) and let client filter.
    if (query.trim().isEmpty) {
      final snap = await collection.limit(200).get();
      return snap.docs.map((d) => {...d.data(), 'id': d.id}).cast<Map<String, dynamic>>().toList();
    }

    final normalized = query.trim();
    final lower = normalized.toLowerCase();

    // Run multiple prefix queries and merge results client-side.
    final futures = <Future<QuerySnapshot>>[
      collection.where('usernameLower', isGreaterThanOrEqualTo: lower).where('usernameLower', isLessThanOrEqualTo: '$lower\uf8ff').limit(50).get(),
      collection.where('username', isGreaterThanOrEqualTo: normalized).where('username', isLessThanOrEqualTo: '$normalized\uf8ff').limit(50).get(),
      collection.where('fullNameLower', isGreaterThanOrEqualTo: lower).where('fullNameLower', isLessThanOrEqualTo: '$lower\uf8ff').limit(50).get(),
      collection.where('fullName', isGreaterThanOrEqualTo: normalized).where('fullName', isLessThanOrEqualTo: '$normalized\uf8ff').limit(50).get(),
    ];

    final snaps = await Future.wait(futures);

    final Map<String, Map<String, dynamic>> merged = {};
    for (final s in snaps) {
      for (final d in s.docs) {
        final raw = d.data();
        final Map<String, dynamic> map = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
        merged.putIfAbsent(d.id, () => {...map, 'id': d.id});
      }
    }

    return merged.values.toList();
  }
}
