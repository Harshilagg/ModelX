import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_page.dart';
import '../ui/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

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
        if (snapshot.hasError) {
          return const ErrorStateView(
            message: 'Could not load the feed. Please try again.',
          );
        }

        if (!snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: 3,
            itemBuilder: (_, __) => AppSkeleton.card(height: 250),
          );
        }

        final posts = snapshot.data!.docs;

        if (posts.isEmpty) {
          return const EmptyState(
            icon: Icons.photo_camera_outlined,
            title: 'No posts yet',
            message: 'When people you follow share something,\nit will show up here.',
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
class _LikeButton extends StatefulWidget {
  final String postId;
  final List<String> likes;

  const _LikeButton({
    required this.postId,
    required this.likes,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (!MediaQuery.of(context).disableAnimations) {
      _controller.forward(from: 0);
    }

    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    // Run as a transaction so rapid double-taps read the latest
    // server state instead of racing off this widget's (possibly
    // stale) `likes` prop — avoids the like count drifting out of
    // sync with the `likes` array.
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      final data = snap.data() ?? {};
      final currentLikes = List<String>.from(data['likes'] ?? []);
      if (currentLikes.contains(userId)) {
        tx.update(postRef, {
          'likes': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        tx.update(postRef, {
          'likes': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = userId != null && widget.likes.contains(userId);

    return GestureDetector(
      onTap: userId == null ? null : _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? AppColors.select : AppColors.inkFaint,
              size: 24,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.likes.length.toString(),
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
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
          backgroundColor: AppColors.paper,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          builder: (_) => _CommentsSheet(postId: postId),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mode_comment_outlined, color: AppColors.inkFaint, size: 22),
          SizedBox(width: 6),
          Text(
            "Comment",
            style: TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
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

      if (!mounted) return;
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Comments",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const ErrorStateView(
                        message: 'Could not load comments.',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const LoadingState();
                    }

                    final comments = snapshot.data!.docs;

                    if (comments.isEmpty) {
                      return const EmptyState(
                        icon: Icons.mode_comment_outlined,
                        title: "No comments yet",
                        message: "Be the first to share your thoughts.",
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final data =
                            comments[index].data() as Map<String, dynamic>;
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfilePage(uid: data['uid']),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProfileAvatar(
                                  imageUrl: data['profileImage'],
                                  name: data['username'],
                                  size: 32,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['username'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        data['text'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.inkSoft,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Material(
                      color: AppColors.ink,
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.paper, size: 20),
                        onPressed: _addComment,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  String _timeAgo(dynamic createdAt) {
    if (createdAt is! Timestamp) return '';
    final diff = DateTime.now().difference(createdAt.toDate());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = postData['imageUrl'] != null &&
        postData['imageUrl'].toString().isNotEmpty;
    final hasCaption = postData['caption'] != null &&
        postData['caption'].toString().isNotEmpty;
    final timeAgo = _timeAgo(postData['createdAt']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== POST HEADER =====
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(uid: postData['uid']),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm + 2,
                AppSpacing.md,
                AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    imageUrl: postData['userImage'],
                    name: postData['username'],
                    size: 42,
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      postData['username'] ?? '',
                      style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (timeAgo.isNotEmpty)
                    Text(timeAgo, style: AppTypography.metadata),
                ],
              ),
            ),
          ),

          // ===== POST IMAGE =====
          if (hasImage)
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                postData['imageUrl'],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.paperRaised,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.inkFaint,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.paperRaised,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.inkFaint,
                      size: 32,
                    ),
                  );
                },
              ),
            ),

          // ===== LIKE / COMMENT ROW =====
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm + 4,
              AppSpacing.md,
              0,
            ),
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

          // ===== CAPTION =====
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm + 2,
                AppSpacing.md,
                AppSpacing.sm + 4,
              ),
              child: Text(
                postData['caption'],
                style: AppTypography.body,
              ),
            )
          else
            const SizedBox(height: AppSpacing.sm + 4),
        ],
      ),
    );
  }
}
