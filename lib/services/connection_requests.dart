import 'package:cloud_firestore/cloud_firestore.dart';

/// Sending and reading follow requests.
///
/// Both the Network rails and the full directories can follow somebody,
/// and each keeps its own local set of who's been asked — but the rules
/// for writing a request are the same in both places, so they live here
/// rather than being retyped per screen.
class ConnectionRequests {
  const ConnectionRequests._();

  /// Everyone [uid] has an outstanding request to. Used to seed a
  /// screen's buttons so a follow already sent doesn't show an inviting
  /// "+" that would create a duplicate.
  static Future<Set<String>> pendingFrom(String uid) async {
    try {
      final sent = await FirebaseFirestore.instance
          .collection('connection_requests')
          .where('senderId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();
      return sent.docs
          .map((d) => (d.data()['receiverId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      // Not being able to read past requests only costs the seeded
      // state; following still works.
      return <String>{};
    }
  }

  /// Creates a pending request. Throws on failure so the caller can put
  /// its button back rather than leaving a request that never landed
  /// looking sent.
  static Future<void> send({required String from, required String to}) async {
    final meDoc =
        await FirebaseFirestore.instance.collection('users').doc(from).get();
    await FirebaseFirestore.instance.collection('connection_requests').add({
      'senderId': from,
      'receiverId': to,
      'senderUsername': meDoc.data()?['username'] ?? '',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
