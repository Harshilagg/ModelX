import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import 'crypto_service.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  // Stable chatId based on participant UIDs (sorted lexicographically) to avoid duplicates
  String _chatIdFor(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return list.join('--');
  }

  Future<String> createChat(String castingId, String modelId, String agencyId) async {
    final chatId = _chatIdFor(modelId, agencyId);

    final docRef = _db.collection('chats').doc(chatId);
    final doc = await docRef.get();

    final now = Timestamp.now();
    final chatData = {
      'castingId': castingId,
      'modelId': modelId,
      'agencyId': agencyId,
      'status': 'NEGOTIATING',
      'lastUpdated': now,
      'lastMessage': null,
    };

    if (!doc.exists) {
      chatData['createdAt'] = now;
    }

    // Fetch user display data for inbox entries
    final modelUserDoc = await _db.collection('users').doc(modelId).get();
    final agencyUserDoc = await _db.collection('users').doc(agencyId).get();
    final modelName = modelUserDoc.data()?['fullName'] ?? modelUserDoc.data()?['displayName'] ?? '';
    final modelUsername = modelUserDoc.data()?['username'] ?? '';
    final modelImage = modelUserDoc.data()?['profileImage'] ?? modelUserDoc.data()?['avatarUrl'] ?? '';
    final agencyName = agencyUserDoc.data()?['fullName'] ?? agencyUserDoc.data()?['displayName'] ?? '';
    final agencyUsername = agencyUserDoc.data()?['username'] ?? '';
    final agencyImage = agencyUserDoc.data()?['profileImage'] ?? agencyUserDoc.data()?['avatarUrl'] ?? '';

    final batch = _db.batch();
    batch.set(docRef, chatData, SetOptions(merge: true));

    final applicantRef = _db.collection('castings').doc(castingId).collection('applicants').doc(modelId);
    batch.update(applicantRef, {'status': 'NEGOTIATING'});

    final agencyInboxRef = _db.collection('user_chats').doc(agencyId).collection('chats').doc(chatId);
    final modelInboxRef = _db.collection('user_chats').doc(modelId).collection('chats').doc(chatId);
    batch.set(agencyInboxRef, {
      'peerId': modelId,
      'peerName': modelName,
      'peerUsername': modelUsername,
      'peerImage': modelImage,
      'lastTimestamp': now,
    }, SetOptions(merge: true));
    batch.set(modelInboxRef, {
      'peerId': agencyId,
      'peerName': agencyName,
      'peerUsername': agencyUsername,
      'peerImage': agencyImage,
      'lastTimestamp': now,
    }, SetOptions(merge: true));

    await batch.commit();
    return chatId;
  }

  Future<String> createGigChat(String gigId, String modelId, String brandId) async {
    final chatId = _chatIdFor(modelId, brandId);

    final docRef = _db.collection('chats').doc(chatId);
    final doc = await docRef.get();

    final now = Timestamp.now();
    final chatData = {
      'gigId': gigId,
      'modelId': modelId,
      'brandId': brandId,
      'status': 'NEGOTIATING',
      'lastUpdated': now,
      'lastMessage': null,
    };

    if (!doc.exists) {
      chatData['createdAt'] = now;
    }

    final modelUserDoc = await _db.collection('users').doc(modelId).get();
    final brandUserDoc = await _db.collection('users').doc(brandId).get();
    final modelName = modelUserDoc.data()?['fullName'] ?? modelUserDoc.data()?['displayName'] ?? '';
    final modelUsername = modelUserDoc.data()?['username'] ?? '';
    final modelImage = modelUserDoc.data()?['profileImage'] ?? modelUserDoc.data()?['avatarUrl'] ?? '';
    final brandName = brandUserDoc.data()?['fullName'] ?? brandUserDoc.data()?['displayName'] ?? '';
    final brandUsername = brandUserDoc.data()?['username'] ?? '';
    final brandImage = brandUserDoc.data()?['profileImage'] ?? brandUserDoc.data()?['avatarUrl'] ?? '';

    final batch = _db.batch();
    batch.set(docRef, chatData, SetOptions(merge: true));

    final applicantRef = _db.collection('gigs').doc(gigId).collection('applications').doc(modelId);
    batch.update(applicantRef, {'status': 'NEGOTIATING'});

    final brandInboxRef = _db.collection('user_chats').doc(brandId).collection('chats').doc(chatId);
    final modelInboxRef = _db.collection('user_chats').doc(modelId).collection('chats').doc(chatId);
    batch.set(brandInboxRef, {
      'peerId': modelId,
      'peerName': modelName,
      'peerUsername': modelUsername,
      'peerImage': modelImage,
      'lastTimestamp': now,
    }, SetOptions(merge: true));
    batch.set(modelInboxRef, {
      'peerId': brandId,
      'peerName': brandName,
      'peerUsername': brandUsername,
      'peerImage': brandImage,
      'lastTimestamp': now,
    }, SetOptions(merge: true));

    await batch.commit();
    return chatId;
  }

  Future<void> sendMessage(String chatId, String content, String type, {Map<String, dynamic>? metadata}) async {
    final user = FirebaseAuth.instance.currentUser!;
    var chatDoc = await _db.collection('chats').doc(chatId).get();
    Map<String, dynamic>? chat;

    // If the provided chatId doesn't exist (legacy id), try to find a negotiation
    // chat document between the two participants and use its canonical id.
    if (!chatDoc.exists) {
      final modelCandidate = await _db.collection('users').doc(user.uid).get();
      // determine receiver id by attempting to parse legacy chatId or via caller metadata
      // Fallback: try to find a chat where either (agencyId == user.uid AND modelId == <peer>)
      // or (agencyId == <peer> AND modelId == user.uid). We'll query broadly for any chat
      // involving the user and pick the first match.
      final q1 = await _db.collection('chats').where('agencyId', isEqualTo: user.uid).limit(20).get();
      final q2 = await _db.collection('chats').where('modelId', isEqualTo: user.uid).limit(20).get();
      DocumentSnapshot? found;
      for (var d in q1.docs) {
        final data = d.data() as Map<String, dynamic>;
        if (data['modelId'] != null && chatId.contains(data['modelId'])) {
          found = d;
          break;
        }
      }
      if (found == null) {
        for (var d in q2.docs) {
          final data = d.data() as Map<String, dynamic>;
          if (data['agencyId'] != null && chatId.contains(data['agencyId'])) {
            found = d;
            break;
          }
        }
      }
      if (found == null) {
        // As a robust fallback, try to find any chat that links the two user ids encoded
        // in the legacy chatId pattern 'uid1-uid2'.
        if (chatId.contains('-')) {
          final parts = chatId.split('-');
          if (parts.length == 2) {
            final a = parts[0];
            final b = parts[1];
            final qA = await _db.collection('chats').where('agencyId', isEqualTo: a).where('modelId', isEqualTo: b).limit(1).get();
            if (qA.docs.isNotEmpty) found = qA.docs.first;
            final qB = await _db.collection('chats').where('agencyId', isEqualTo: b).where('modelId', isEqualTo: a).limit(1).get();
            if (found == null && qB.docs.isNotEmpty) found = qB.docs.first;
          }
        }
      }

      if (found != null) {
        chatDoc = await _db.collection('chats').doc(found.id).get();
        chatId = found.id;
      } else {
        throw Exception('Chat not found');
      }
    }
    chat = chatDoc.data()! as Map<String, dynamic>;

    // determine receiver id — casting chats store `agencyId`, gig chats store
    // `brandId`; a chat doc only ever has one of the two.
    final modelId = chat['modelId'] as String;
    final counterpartyId = (chat['agencyId'] ?? chat['brandId']) as String?;
    if (counterpartyId == null) {
      throw Exception('Chat is missing a counterparty (agencyId/brandId)');
    }
    final receiverId = user.uid == counterpartyId ? modelId : counterpartyId;

    // fetch receiver public key and profile info
    final recvDoc = await _db.collection('users').doc(receiverId).get();
    final recvData = recvDoc.data() ?? {};
    final recvPub = recvData['publicKey'] as String?;
    if (recvPub == null) throw Exception('Receiver public key missing');

    final encrypted = await CryptoService.encryptFor(recvPub, content);

    final messagesRef = _db.collection('chats').doc(chatId).collection('messages');

    final msgRef = messagesRef.doc();
    final msg = {
      'senderId': user.uid,
      'encryptedContent': encrypted,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'metadata': metadata,
    };

    final batch = _db.batch();
    batch.set(msgRef, msg);
    // update chat last message
    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': type == 'text' ? content : '[${type.toUpperCase()}]',
      'lastUpdated': Timestamp.now(),
    });

    // update user inboxes for sender and receiver (populate peer name/image from profiles)
    final senderDoc = await _db.collection('users').doc(user.uid).get();
    final senderData = senderDoc.data() ?? {};
    final senderInbox = _db.collection('user_chats').doc(user.uid).collection('chats').doc(chatId);
    final receiverInbox = _db.collection('user_chats').doc(receiverId).collection('chats').doc(chatId);
    batch.set(senderInbox, {
      'peerId': receiverId,
      'peerName': recvData['fullName'] ?? recvData['displayName'] ?? '',
      'peerUsername': recvData['username'] ?? '',
      'peerImage': recvData['profileImage'] ?? recvData['avatarUrl'] ?? '',
      'lastMessage': type == 'text' ? content : '[${type.toUpperCase()}]',
      'lastTimestamp': Timestamp.now(),
      'unreadCount': 0,
    }, SetOptions(merge: true));
    batch.set(receiverInbox, {
      'peerId': user.uid,
      'peerName': senderData['fullName'] ?? senderData['displayName'] ?? '',
      'peerUsername': senderData['username'] ?? '',
      'peerImage': senderData['profileImage'] ?? senderData['avatarUrl'] ?? '',
      'lastMessage': type == 'text' ? content : '[${type.toUpperCase()}]',
      'lastTimestamp': Timestamp.now(),
      'unreadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // Decrypt helper for a received message
  Future<String> decryptMessage(String encryptedPayload) async {
    return await CryptoService.decrypt(encryptedPayload);
  }

  // Stream of ChatMessage objects ordered by timestamp
  Stream<List<ChatMessage>> subscribeToMessages(String chatId) {
    final ref = _db.collection('chats').doc(chatId).collection('messages').orderBy('timestamp', descending: false);
    return ref.snapshots().map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(d)).toList());
  }

  // Send structured offer; stored as encrypted content with metadata.offer
  Future<void> sendOffer(String chatId, Map<String, dynamic> offerData) async {
    final content = jsonEncode(offerData);
    await sendMessage(chatId, content, 'offer', metadata: {'offer': offerData, 'status': 'pending'});
  }

  // Accept an offer: mark applicant accepted, update offer message metadata and post system message
  Future<void> acceptOffer(String chatId, String offerMessageId) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) throw Exception('Chat not found');
    final chat = chatDoc.data()!;
    final castingId = chat['castingId'] as String;
    final modelId = chat['modelId'] as String;

    // update applicant status
    final applicantRef = _db.collection('castings').doc(castingId).collection('applicants').doc(modelId);
    // update offer message metadata
    final offerRef = chatRef.collection('messages').doc(offerMessageId);

    final batch = _db.batch();
    batch.update(applicantRef, {'status': 'ACCEPTED'});
    batch.update(offerRef, {'metadata.status': 'accepted'});
    // add system message
    final sysRef = chatRef.collection('messages').doc();
    batch.set(sysRef, {
      'senderId': 'system',
      'encryptedContent': await _systemEncryptedPayload(chatRef.id, 'Offer accepted'),
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
      'metadata': {'note': 'offer_accepted'},
    });
    batch.update(chatRef, {'lastMessage': 'Offer accepted', 'lastUpdated': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  Future<String> _systemEncryptedPayload(String chatId, String text) async {
    // system messages are stored encrypted for both participants by encrypting with each receiver's pub
    // but for simplicity store plaintext marker wrapped (non-sensitive)
    return base64Encode(utf8.encode(jsonEncode({'system': true, 'text': text})));
  }

  // Confirm booking: create bookings doc and mark applicant BOOKED
  Future<void> confirmBooking(String chatId, Map<String, dynamic> bookingData) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) throw Exception('Chat not found');
    final chat = chatDoc.data()!;
    final castingId = chat['castingId'] as String;
    final modelId = chat['modelId'] as String;
    final agencyId = chat['agencyId'] as String;

    final booking = {
      'castingId': castingId,
      'modelId': modelId,
      'agencyId': agencyId,
      'finalPay': bookingData['finalPay'],
      'dates': bookingData['dates'],
      'location': bookingData['location'],
      'usageRights': bookingData['usageRights'],
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    final bookingsRef = _db.collection('bookings').doc();
    batch.set(bookingsRef, booking);
    final applicantRef = _db.collection('castings').doc(castingId).collection('applicants').doc(modelId);
    batch.update(applicantRef, {'status': 'BOOKED'});
    batch.update(chatRef, {'status': 'BOOKED', 'lastUpdated': FieldValue.serverTimestamp(), 'lastMessage': 'Booking confirmed'});
    await batch.commit();
  }
}
