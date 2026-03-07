import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search users prioritizing username prefix matches, then fullName prefix matches.
  /// Returns unique user documents (maps) with username/fullName/profileImage etc.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Normalize input and prepare a lowercase variant. Also strip leading '@'.
    final normalized = q.replaceFirst(RegExp(r'^@'), '');
    final lower = normalized.toLowerCase();

    // Firestore can't do OR across different fields in a single query, so run
    // multiple prefix queries and merge results client-side. We query both the
    // original fields and lowercase helper fields (`usernameLower` / `fullNameLower`) to
    // support case-insensitive searches while remaining backward compatible.

    final usernameLowerQuery = await _firestore
        .collection('users')
        .where('usernameLower', isGreaterThanOrEqualTo: lower)
        .where('usernameLower', isLessThanOrEqualTo: '$lower\uf8ff')
        .get();

    final usernameQuery = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: normalized)
        .where('username', isLessThanOrEqualTo: '$normalized\uf8ff')
        .get();

    final fullNameLowerQuery = await _firestore
        .collection('users')
        .where('fullNameLower', isGreaterThanOrEqualTo: lower)
        .where('fullNameLower', isLessThanOrEqualTo: '$lower\uf8ff')
        .get();

    final fullNameQuery = await _firestore
        .collection('users')
        .where('fullName', isGreaterThanOrEqualTo: normalized)
        .where('fullName', isLessThanOrEqualTo: '$normalized\uf8ff')
        .get();

    final allDocs = <String, Map<String, dynamic>>{};

    for (final doc in usernameLowerQuery.docs) {
      allDocs.putIfAbsent(doc.id, () => {...doc.data(), 'uid': doc.id});
      
    }
    for (final doc in usernameQuery.docs) {
      allDocs.putIfAbsent(doc.id, () => {...doc.data(), 'uid': doc.id});
    }
    for (final doc in fullNameLowerQuery.docs) {
      allDocs.putIfAbsent(doc.id, () => {...doc.data(), 'uid': doc.id});
      
    }
    for (final doc in fullNameQuery.docs) {
      allDocs.putIfAbsent(doc.id, () => {...doc.data(), 'uid': doc.id});
    }

    return allDocs.values.toList();
  }
}
