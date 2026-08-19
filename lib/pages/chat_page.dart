import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/crypto_service.dart';
import '../widgets/model_x_copilot.dart';
import '../ui/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

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
      // The caller already knows exactly which chat this is (e.g. it just
      // called ChatService.createChat/createGigChat, or the user tapped a
      // specific conversation in their inbox) — trust it as-is and don't
      // run reconciliation, which could otherwise redirect a brand-new
      // negotiation thread into an older, unrelated conversation with the
      // same person.
      chatId = widget.chatId!;
    } else {
      final list = [currentUser.uid, widget.peerId]..sort();
      chatId = list.join('--');

      // Only reconcile when we had to guess the chatId ourselves — this is
      // exactly the case that can miss an existing conversation (e.g. one
      // started under an older chatId scheme).
      _resolveCanonicalChatId();
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveCanonicalChatId() async {
    try {
      final db = FirebaseFirestore.instance;

      // Primary check: does MY OWN inbox already have a conversation with
      // this peer? This is the most reliable signal there is — it reflects
      // whatever chatId was actually used the last time these two people
      // talked, regardless of which chatId-generation scheme was live at
      // the time (an earlier version of this app derived chatId from
      // hashCode, which isn't guaranteed to match between the two
      // participants; the current version sorts+joins the UIDs, which is —
      // but conversations that started under the old scheme won't match a
      // freshly recomputed id). Checking the inbox directly sidesteps that
      // entirely, and covers plain peer-to-peer chats too, not just
      // negotiation chats.
      final inboxMatch = await db
          .collection('user_chats')
          .doc(currentUser.uid)
          .collection('chats')
          .where('peerId', isEqualTo: widget.peerId)
          .limit(1)
          .get();
      if (inboxMatch.docs.isNotEmpty) {
        if (mounted) setState(() => chatId = inboxMatch.docs.first.id);
        return;
      }

      // Fallback checks below cover the case where a `chats/` negotiation
      // doc exists but an inbox entry doesn't yet (e.g. it was created by
      // the other participant and this user hasn't opened it before).
      // Check for a casting chat where currentUser is agency and peer is model
      final q1 = await db.collection('chats').where('agencyId', isEqualTo: currentUser.uid).where('modelId', isEqualTo: widget.peerId).limit(1).get();
      if (q1.docs.isNotEmpty) {
        if (mounted) setState(() => chatId = q1.docs.first.id);
        return;
      }

      // Check the reverse (currentUser is model and peer is agency)
      final q2 = await db.collection('chats').where('agencyId', isEqualTo: widget.peerId).where('modelId', isEqualTo: currentUser.uid).limit(1).get();
      if (q2.docs.isNotEmpty) {
        if (mounted) setState(() => chatId = q2.docs.first.id);
        return;
      }

      // Same two checks for gig chats, which store `brandId` instead of `agencyId`.
      final q3 = await db.collection('chats').where('brandId', isEqualTo: currentUser.uid).where('modelId', isEqualTo: widget.peerId).limit(1).get();
      if (q3.docs.isNotEmpty) {
        if (mounted) setState(() => chatId = q3.docs.first.id);
        return;
      }

      final q4 = await db.collection('chats').where('brandId', isEqualTo: widget.peerId).where('modelId', isEqualTo: currentUser.uid).limit(1).get();
      if (q4.docs.isNotEmpty) {
        if (mounted) setState(() => chatId = q4.docs.first.id);
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
      final peerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.peerId).get();
      final peerUsername = peerDoc.data()?['username'] ?? '';

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
        'peerUsername': peerUsername,
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
    // Casting chats store `castingId`, gig chats store `gigId` — either one
    // means this is a service-created chat that should be encrypted.
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    final chatDocData = chatDoc.data();
    final isNegotiationChat = chatDoc.exists &&
        (chatDocData?['castingId'] != null || chatDocData?['gigId'] != null);

    if (isNegotiationChat) {
      try {
        await ChatService().sendMessage(chatId, text, 'text');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Encrypted send failed, sending unencrypted: $e')));
        await _writeLegacy(text);
      }
    } else {
      await _writeLegacy(text);
    }

    if (!mounted) return;
    messageController.clear();

    if (_scrollController.hasClients) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
 

  /// A single bubble-shaped placeholder, matching the geometry of a real
  /// message bubble — used while the message stream's first snapshot is
  /// still pending, instead of a bare centered spinner.
  Widget _bubbleSkeleton({required bool isMe, required double width}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
        child: AppSkeleton(
          width: width,
          height: 38,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
      ),
    );
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
            ProfileAvatar(imageUrl: widget.peerImage, name: widget.peerName, size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.peerName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    children: [
                      _bubbleSkeleton(isMe: false, width: 190),
                      _bubbleSkeleton(isMe: false, width: 130),
                      _bubbleSkeleton(isMe: true, width: 210),
                      _bubbleSkeleton(isMe: false, width: 160),
                      _bubbleSkeleton(isMe: true, width: 120),
                    ],
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Say hello',
                    message: 'Send a message to start the conversation.',
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe = (msg['senderId'] ?? '') == currentUser.uid;
                    final encrypted = msg['encryptedContent'] as String?;
                    final bubbleTextStyle = AppTypography.body.copyWith(
                      color: isMe ? AppColors.paper : AppColors.ink,
                      height: 1.35,
                    );

                    Widget bubbleChild;
                    if (encrypted != null) {
                      bubbleChild = FutureBuilder<String>(
                        future: CryptoService.decrypt(encrypted),
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return SizedBox(
                              width: 120,
                              height: 20,
                              child: LinearProgressIndicator(
                                color: isMe ? AppColors.paper : AppColors.ink,
                                backgroundColor: isMe ? AppColors.inkSoft : AppColors.line,
                              ),
                            );
                          }
                          final text = snap.data ?? '[unable to decrypt]';
                          return Text(text, style: bubbleTextStyle);
                        },
                      );
                    } else {
                      bubbleChild = Text(msg['message'] ?? '', style: bubbleTextStyle);
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.ink : AppColors.paperRaised,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                        ),
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
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Material(
                      color: AppColors.ink,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.paper, size: 20),
                        onPressed: sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
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
