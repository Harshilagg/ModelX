import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_profile_page.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

/// Home -- the feed.
///
/// It opened on a card summarising what needed a decision. That is the
/// Jobs tab's job, and two answers to the same question stacked above
/// the feed made the screen busy rather than useful, so the feed starts
/// at the top now.
///
/// Everything on the board is assembled from data the app already
/// stores: open gigs/castings plus this model's own application document
/// under each. There is no per-model "bookings" collection, and the
/// security rules forbid a collection-group query over applications, so
/// the board reads the same way [JobsPage] does rather than inventing a
/// new backend shape.
class HomePage extends StatefulWidget {
  /// Switches the shell to the Jobs tab. That exit belongs on the Jobs
  /// destination, not on a pushed duplicate of it, so the shell hands
  /// Home a way to move the selection.
  final VoidCallback? onOpenJobs;

  const HomePage({super.key, this.onOpenJobs});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _feedFilter = 0; // 0 All · 1 Shots · 2 Notes

  /// Last time this device saw the feed. Stored locally rather than on
  /// the user document so counting "new" posts costs no schema change.
  DateTime? _lastSeen;

  /// Held in a field, not rebuilt inline. `.snapshots()` returns a new
  /// Stream each call and a StreamBuilder resubscribes when its stream
  /// identity changes, so an inline stream blanks itself on every parent
  /// rebuild — a tab switch, a filter tap, a setState.
  late final Stream<QuerySnapshot> _posts = FirebaseFirestore.instance
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('feed_last_seen');
    if (!mounted) return;
    setState(() {
      _lastSeen = millis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis);
    });
    // Mark seen after the current frame so the count the user just saw
    // doesn't vanish underneath them mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await prefs.setInt(
        'feed_last_seen',
        DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          key: const ValueKey('feed-header'),
          child: _feedHeader(),
        ),
        _feedBody(),
      ],
    );
  }

  Widget _feedHeader() {
    const labels = ['All', 'Shots', 'Notes'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(labels.length, (i) {
                final active = i == _feedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _feedFilter = i),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: active
                                ? BoardColors.brass
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        labels[i],
                        style: BoardType.title(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: active ? BoardColors.ink : BoardColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          _NewPostsTile(since: _lastSeen),
        ],
      ),
    );
  }

  Widget _feedBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: _posts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SliverFillRemaining(
            key: ValueKey('feed-error'),
            hasScrollBody: false,
            child: ErrorStateView(
              message: 'Could not load the feed. Please try again.',
            ),
          );
        }

        if (!snapshot.hasData) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
            sliver: SliverList.builder(
              itemCount: 3,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppSkeleton.card(height: 220),
              ),
            ),
          );
        }

        final all = snapshot.data!.docs;
        final posts = all.where((d) {
          if (_feedFilter == 0) return true;
          final data = d.data() as Map<String, dynamic>;
          final hasImage = (data['imageUrl'] ?? '').toString().isNotEmpty;
          return _feedFilter == 1 ? hasImage : !hasImage;
        }).toList();

        if (posts.isEmpty) {
          return const SliverFillRemaining(
            key: ValueKey('feed-empty'),
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.photo_camera_outlined,
              title: 'Nothing on the wire',
              message: 'Shots and notes from people you follow show up here.',
            ),
          );
        }

        // Two-column masonry. Posts alternate columns so a tall shot in
        // one column doesn't push the other column's content down with
        // it — which is exactly what a uniform GridView would do, and
        // why text-only notes currently read as broken photo posts.
        //
        // This builds every card up front. True masonry can't be lazy
        // without a custom sliver, and the underlying query is unbounded
        // anyway, so the fix when the feed grows is to page the query —
        // see the note on the stream above.
        final left = <Widget>[];
        final right = <Widget>[];
        for (var i = 0; i < posts.length; i++) {
          final doc = posts[i];
          final card = Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FeedCard(
              postId: doc.id,
              postData: doc.data() as Map<String, dynamic>,
              noteRecipe: i,
            ),
          );
          (i.isEven ? left : right).add(card);
        }

        return SliverPadding(
          key: const ValueKey('feed'),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: left),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// The feed
/// ---------------------------------------------------------------------

/// Counts posts newer than this device's last visit, shown as a flap
/// tile rather than a banner so the feed never gets pushed down.
class _NewPostsTile extends StatelessWidget {
  final DateTime? since;
  const _NewPostsTile({required this.since});

  @override
  Widget build(BuildContext context) {
    if (since == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since!))
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return FlapTile(
          text: '$count NEW',
          background: BoardColors.ink,
          foreground: BoardColors.brass,
          fontSize: 9,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        );
      },
    );
  }
}

/// A post in the masonry — a shot (photo) or a note (text only). Notes
/// get a filled dark block so they stop reading as a photo post that
/// failed to load.
class _FeedCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final int noteRecipe;

  const _FeedCard({
    required this.postId,
    required this.postData,
    required this.noteRecipe,
  });

  static String _timeAgo(dynamic createdAt) {
    if (createdAt is! Timestamp) return '';
    final diff = DateTime.now().difference(createdAt.toDate());
    if (diff.inDays > 0) return '${diff.inDays}D';
    if (diff.inHours > 0) return '${diff.inHours}H';
    if (diff.inMinutes > 0) return '${diff.inMinutes}M';
    return 'NOW';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (postData['imageUrl'] ?? '').toString();
    final caption = (postData['caption'] ?? '').toString();
    final username = (postData['username'] ?? '').toString();
    final time = _timeAgo(postData['createdAt']);
    final likes = List<String>.from(postData['likes'] ?? const []);

    if (imageUrl.isEmpty) {
      return _note(context, caption, username, time, likes);
    }
    return _shot(context, imageUrl, caption, username, time, likes);
  }

  Widget _shot(
    BuildContext context,
    String imageUrl,
    String caption,
    String username,
    String time,
    List<String> likes,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: BoardColors.card,
        borderRadius: BorderRadius.circular(BoardRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _author(context, username, time, dark: false),
          // A fixed pixel height would crop tall portraits and letterbox
          // wide ones; a ratio lets the masonry column find its own
          // height instead.
          AspectRatio(aspectRatio: 0.82, child: BoardMedia(url: imageUrl)),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _actions(context, likes, onDark: false),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.body(fontSize: 12, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(
    BuildContext context,
    String caption,
    String username,
    String time,
    List<String> likes,
  ) {
    // Notes alternate between the two dark panels so a run of text posts
    // doesn't become a wall of one colour. Neither is brass: this palette
    // spends brass on money and the comp card, and a text post wearing it
    // would outrank the job cards it scrolls past.
    final onSlate = noteRecipe.isEven;
    final bg = onSlate ? BoardColors.slate : BoardColors.ink;
    const onDark = true;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BoardRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _author(context, username, time, dark: onDark, flat: true),
          const SizedBox(height: 8),
          Text(
            caption.isEmpty ? '—' : caption,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: BoardType.body(
              fontSize: 12.5,
              height: 1.4,
              color: BoardColors.onInk.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          // A liked heart is the one coloured mark on a note, so on slate
          // it takes the brass tint rather than sinking into the panel.
          _actions(
            context,
            likes,
            onDark: onDark,
            accent: onSlate ? BoardColors.brassText : BoardColors.brass,
          ),
        ],
      ),
    );
  }

  Widget _author(
    BuildContext context,
    String username,
    String time, {
    required bool dark,
    bool flat = false,
  }) {
    final fg = dark ? BoardColors.onInk : BoardColors.ink;
    final meta = dark ? BoardColors.onInkFaint : BoardColors.inkSoft;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final uid = postData['uid'];
        if (uid == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
        );
      },
      child: Padding(
        padding: flat ? EdgeInsets.zero : const EdgeInsets.fromLTRB(9, 8, 9, 7),
        child: Row(
          children: [
            SizedBox(
              width: flat ? 18 : 20,
              height: flat ? 18 : 20,
              child: ClipOval(
                child: BoardMedia(
                  url: (postData['userImage'] ?? '').toString(),
                  dark: dark,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BoardType.title(
                  fontSize: flat ? 11.5 : 12,
                  color: fg,
                  letterSpacing: 0.35,
                ),
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                time,
                style: BoardType.mono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w400,
                  color: meta,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    List<String> likes, {
    required bool onDark,
    Color accent = BoardColors.brass,
  }) {
    final fg = onDark ? BoardColors.onInk : BoardColors.ink;
    final meta = onDark ? BoardColors.onInkFaint : BoardColors.inkSoft;

    return Row(
      children: [
        _LikeButton(
          postId: postId,
          likes: likes,
          foreground: fg,
          accent: accent,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showCommentsSheet(context, postId),
            child: Text(
              'Comment',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.mono(
                fontSize: 9.5,
                color: meta,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------
/// Like + comments
/// ---------------------------------------------------------------------

class _LikeButton extends StatefulWidget {
  final String postId;
  final List<String> likes;
  final Color foreground;
  final Color accent;

  const _LikeButton({
    required this.postId,
    required this.likes,
    required this.foreground,
    required this.accent,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
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
        tween: Tween(
          begin: 1.0,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
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

    final postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId);

    // Run as a transaction so rapid double-taps read the latest server
    // state instead of racing off this widget's (possibly stale) `likes`
    // prop — avoids the count drifting out of sync with the array.
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
              color: isLiked
                  ? widget.accent
                  : widget.foreground.withValues(alpha: 0.72),
              size: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            widget.likes.length.toString(),
            style: BoardType.mono(fontSize: 10, color: widget.foreground),
          ),
        ],
      ),
    );
  }
}

/// Opens the comments for a post. Exposed so the profile's own post list
/// can lift the same sheet rather than duplicating it.
void showCommentsSheet(BuildContext context, String postId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: BoardColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(BoardRadius.sheet),
      ),
    ),
    builder: (_) => _CommentsSheet(postId: postId),
  );
}

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not post comment: $e')));
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
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: BoardColors.inkLineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Comments',
                        style: BoardType.display(fontSize: 24, height: 1),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: BoardColors.inkLine),
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
                    if (!snapshot.hasData) return const LoadingState();

                    final comments = snapshot.data!.docs;
                    if (comments.isEmpty) {
                      return const EmptyState(
                        icon: Icons.mode_comment_outlined,
                        title: 'No comments yet',
                        message: 'Be the first to say something.',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final data =
                            comments[index].data() as Map<String, dynamic>;
                        return InkWell(
                          onTap: () {
                            if (data['uid'] == null) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UserProfilePage(uid: data['uid']),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 30,
                                  height: 34,
                                  child: BoardMedia(
                                    url: (data['profileImage'] ?? '')
                                        .toString(),
                                    cut: 8,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (data['username'] ?? '').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: BoardType.title(
                                          fontSize: 14,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        (data['text'] ?? '').toString(),
                                        style: BoardType.body(
                                          fontSize: 13,
                                          color: BoardColors.inkSoft,
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
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        style: BoardType.body(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Add a comment…',
                          hintStyle: BoardType.body(
                            fontSize: 13,
                            color: BoardColors.inkSoft,
                          ),
                          filled: true,
                          fillColor: BoardColors.shell,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              BoardRadius.pill,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              BoardRadius.pill,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              BoardRadius.pill,
                            ),
                            borderSide: const BorderSide(
                              color: BoardColors.ink,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addComment,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: BoardColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: BoardColors.onInk,
                          size: 19,
                        ),
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
