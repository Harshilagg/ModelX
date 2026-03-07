import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              'No posts yet',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final data = post.data() as Map<String, dynamic>;

            return _PostCard(
              postId: post.id,
              postData: data,
              );
          },
        );
      },
    );
  }
}
/////////////////////////LIKE////////////////////////////////
class _LikeButton extends StatelessWidget {
  final String postId;
  final List<String> likes;

  const _LikeButton({
    required this.postId,
    required this.likes,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final isLiked = likes.contains(userId);

    return GestureDetector(
      onTap: () async {
        final postRef =
            FirebaseFirestore.instance.collection('posts').doc(postId);

        if (isLiked) {
          await postRef.update({
            'likes': FieldValue.arrayRemove([userId]),
            'likeCount': FieldValue.increment(-1),
          });
        } else {
          await postRef.update({
            'likes': FieldValue.arrayUnion([userId]),
            'likeCount': FieldValue.increment(1),
          });
        }
      },
      child: Row(
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            likes.length.toString(),
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
/////////////////////////COMMENT////////////////////////////////
class _CommentButton extends StatelessWidget {
  final String postId;

  const _CommentButton({required this.postId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _CommentsSheet(postId: postId),
        );
      },
      child: Row(
        children: const [
          Icon(Icons.mode_comment_outlined, color: Colors.grey),
          SizedBox(width: 6),
          Text(
            "Comment",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
/////////////////////////COMMENTS SHEET////////////////////////////////
class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _addComment() async {
  final user = FirebaseAuth.instance.currentUser!;
  final text = _controller.text.trim();
  if (text.isEmpty) return;

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  final userData = userDoc.data() ?? {};

  await FirebaseFirestore.instance
      .collection('posts')
      .doc(widget.postId)
      .collection('comments')
      .add({
    'uid': user.uid,
    'username': userData['username'] ?? '',
    'profileImage': userData['profileImage'] ?? '',
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
  });

  _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text(
            "Comments",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const Divider(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!.docs;

                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      "No comments yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data =
                        comments[index].data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),

                      leading: CircleAvatar(
                        radius: 16, // 👈 smaller than post header
                        backgroundImage:
                            (data['profileImage'] != null && data['profileImage'].toString().isNotEmpty)
                                ? NetworkImage(data['profileImage'])
                                : null,
                        child: (data['profileImage'] == null ||
                                data['profileImage'].toString().isEmpty)
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),

                      title: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                      builder: (_) => UserProfilePage(uid: data['uid']),
                                    ),
                          );
                        },
                        child: Text(
                          data['username'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      subtitle: Text(
                        data['text'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),

                      onTap: () {
                        // optional: tap anywhere to open profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                                      builder: (_) => UserProfilePage(uid: data['uid']),
                                    ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
//////////////////////////POST CARD STYLE OF POST////////////////////////////////
class _PostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  const _PostCard({
    required this.postId,
    required this.postData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== POST HEADER =====
          ListTile(
            leading: CircleAvatar(
              backgroundImage: postData['userImage'] != null
                  ? NetworkImage(postData['userImage'])
                  : null,
            ),
            title: Text(
              postData['username'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(uid: postData['uid']),
                ),
              );

            },
          ),

          // ===== POST IMAGE =====
          if (postData['imageUrl'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                postData['imageUrl'],
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
              ),
            ),

          // ===== CAPTION =====
          if (postData['caption'] != null &&
              postData['caption'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                postData['caption'],
                style: const TextStyle(fontSize: 14),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _LikeButton(
                  postId: postId,
                  likes: List<String>.from(postData['likes'] ?? []),
                ),
                const SizedBox(width: 20),
                _CommentButton(postId: postId),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
