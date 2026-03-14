import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/crypto_service.dart';
import '../widgets/model_x_copilot.dart';

class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerImage;
  final String? chatId;

  const ChatPage({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerImage,
    this.chatId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String chatId;

  @override
  void initState() {
    super.initState();

    // Use provided chatId if present (created by ChatService), otherwise fall back
    // to legacy derived chat id for direct peer-to-peer chats. Use lexicographic
    // ordering of UIDs (stable across runs) instead of hashCode to ensure both
    // participants compute the same id. After computing a candidate id, try to
    // resolve to an existing negotiation chat (chats collection) and prefer
    // that canonical doc if found.
    // Use provided chatId if present (created by ChatService), otherwise fall back
    // to stable derived chat id for direct peer-to-peer chats. Use lexicographic
    // ordering of UIDs (stable across runs) to ensure both participants compute 
    // the same id.
    if (widget.chatId != null) {
      chatId = widget.chatId!;
    } else {
      final list = [currentUser.uid, widget.peerId]..sort();
      chatId = list.join('--');
    }

    // Resolve to existing negotiation chat if one exists between these users
    _resolveCanonicalChatId();
  }

  Future<void> _resolveCanonicalChatId() async {
    try {
      final db = FirebaseFirestore.instance;
      // Check for a chat where currentUser is agency and peer is model
      final q1 = await db.collection('chats').where('agencyId', isEqualTo: currentUser.uid).where('modelId', isEqualTo: widget.peerId).limit(1).get();
      if (q1.docs.isNotEmpty) {
        setState(() => chatId = q1.docs.first.id);
        return;
      }

      // Check the reverse (currentUser is model and peer is agency)
      final q2 = await db.collection('chats').where('agencyId', isEqualTo: widget.peerId).where('modelId', isEqualTo: currentUser.uid).limit(1).get();
      if (q2.docs.isNotEmpty) {
        setState(() => chatId = q2.docs.first.id);
        return;
      }
    } catch (_) {
      // ignore resolution errors; we'll fall back to candidate id
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    // Helper to write legacy plaintext messages and update inboxes
    Future<void> _writeLegacy(String messageText) async {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};

      final messageData = {
        'senderId': currentUser.uid,
        'senderName': userData['fullName'] ?? '',
        'senderUsername': userData['username'] ?? '',
        'senderImage': userData['profileImage'] ?? '',
        'receiverId': widget.peerId,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add(messageData);

      await FirebaseFirestore.instance.collection('user_chats').doc(currentUser.uid).collection('chats').doc(chatId).set({
        'peerId': widget.peerId,
        'peerName': widget.peerName,
        'peerUsername': '',
        'peerImage': widget.peerImage,
        'lastMessage': messageText,
        'lastTimestamp': Timestamp.now(),
        'unreadCount': 0,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('user_chats').doc(widget.peerId).collection('chats').doc(chatId).set({
        'peerId': currentUser.uid,
        'peerName': userData['fullName'] ?? '',
        'peerUsername': userData['username'] ?? '',
        'peerImage': userData['profileImage'] ?? '',
        'lastMessage': messageText,
        'lastTimestamp': Timestamp.now(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    // Decide whether this chatId refers to a negotiation chat in `chats/`.
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    final isNegotiationChat = chatDoc.exists && chatDoc.data()?['castingId'] != null;

    if (isNegotiationChat) {
      try {
        await ChatService().sendMessage(chatId, text, 'text');
        messageController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Encrypted send failed, sending unencrypted: $e')));
        await _writeLegacy(text);
        messageController.clear();
      }
    } else {
      await _writeLegacy(text);
      messageController.clear();
    }

    if (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
 

  @override
  Widget build(BuildContext context) {
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.peerImage.isNotEmpty
                  ? NetworkImage(widget.peerImage)
                  : const AssetImage('assets/avatar.jpg') as ImageProvider,
            ),
            const SizedBox(width: 10),
            Text(widget.peerName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe = (msg['senderId'] ?? '') == currentUser.uid;
                    final encrypted = msg['encryptedContent'] as String?;

                    Widget bubbleChild;
                    if (encrypted != null) {
                      bubbleChild = FutureBuilder<String>(
                        future: CryptoService.decrypt(encrypted),
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) return const SizedBox(width: 120, height: 20, child: LinearProgressIndicator());
                          final text = snap.data ?? '[unable to decrypt]';
                          return Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87));
                        },
                      );
                    } else {
                      bubbleChild = Text(msg['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87));
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: isMe ? Colors.blueAccent : Colors.grey[300], borderRadius: BorderRadius.circular(14)),
                        child: bubbleChild,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // INPUT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // Shift above message input bar
        child: ModelXCopilot(
          pageContext: {
            'page': 'chat',
            'role': 'user',
            'chatId': chatId,
            'peerName': widget.peerName,
          },
        ),
      ),
    );
  }
}
