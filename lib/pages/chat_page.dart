import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerImage;

  const ChatPage({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerImage,
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

    chatId = currentUser.uid.hashCode <= widget.peerId.hashCode
        ? '${currentUser.uid}-${widget.peerId}'
        : '${widget.peerId}-${currentUser.uid}';
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final userData = userDoc.data() ?? {};

    final messageData = {
      'senderId': currentUser.uid,
      'senderName': userData['fullName'] ?? '',
      'senderUsername': userData['username'] ?? '',
      'senderImage': userData['profileImage'] ?? '',
      'receiverId': widget.peerId,
      'message': text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 🔹 Add message
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // 🔹 Update sender inbox
    await FirebaseFirestore.instance
        .collection('user_chats')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(chatId)
        .set({
      'peerId': widget.peerId,
      'peerName': widget.peerName,
      'peerUsername': '',
      'peerImage': widget.peerImage,
      'lastMessage': text,
      'lastTimestamp': Timestamp.now(),
      'unreadCount': 0,
    }, SetOptions(merge: true));

    // 🔹 Update receiver inbox
    await FirebaseFirestore.instance
        .collection('user_chats')
        .doc(widget.peerId)
        .collection('chats')
        .doc(chatId)
        .set({
      'peerId': currentUser.uid,
      'peerName': userData['fullName'] ?? '',
      'peerUsername': userData['username'] ?? '',
      'peerImage': userData['profileImage'] ?? '',
      'lastMessage': text,
      'lastTimestamp': Timestamp.now(),
      'unreadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    messageController.clear();

    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
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
                    final isMe = msg['senderId'] == currentUser.uid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              isMe ? Colors.blueAccent : Colors.grey[300],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          msg['message'] ?? '',
                          style: TextStyle(
                            color:
                                isMe ? Colors.white : Colors.black87,
                          ),
                        ),
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
    );
  }
}
