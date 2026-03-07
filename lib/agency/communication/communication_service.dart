import 'package:cloud_firestore/cloud_firestore.dart';

class CommunicationService {
  final _db = FirebaseFirestore.instance;

  Future<QuerySnapshot> fetchConversations(String agencyId) async {
    return _db.collection('conversations').where('participants', arrayContains: agencyId).get();
  }

  Future<void> sendMessage(String convoId, Map<String, dynamic> message) async {
    await _db.collection('conversations').doc(convoId).collection('messages').add(message);
    await _db.collection('conversations').doc(convoId).update({'lastMessageAt': FieldValue.serverTimestamp()});
  }
}
