import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_page.dart';
import '../services/application_feed.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

/// Notifications, read as board updates (style board 4b).
///
/// Two kinds of thing land here, and both come from data the app already
/// keeps: a posting this model applied to has moved (the status on their
/// own application document), and somebody has asked to connect
/// (`connection_requests`). There is no notifications collection, so
/// nothing here is fabricated to fill the layout — the panel simply
/// shows whichever of the two exist.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  /// Held in a field, not rebuilt inline. `.snapshots()` returns a new
  /// Stream each call and a StreamBuilder resubscribes when its stream
  /// identity changes, so an inline stream blanks itself on every parent
  /// rebuild — a tab switch, a filter tap, a setState.
  Stream<QuerySnapshot>? _requests;

  @override
  void initState() {
    super.initState();
    final me = currentUser;
    if (me != null) {
      _requests = FirebaseFirestore.instance
          .collection('connection_requests')
          .where('receiverId', isEqualTo: me.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    }
  }

  Future<void> _respondToRequest(
    String docId,
    String senderId,
    bool accepted,
  ) async {
    final user = currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final requestRef = firestore.collection('connection_requests').doc(docId);
    final meRef = firestore.collection('users').doc(user.uid);
    final senderRef = firestore.collection('users').doc(senderId);

    // Update request status
    batch.update(requestRef, {'status': accepted ? 'accepted' : 'rejected'});

    if (accepted) {
      // ADD CONNECTIONS (both sides)
      batch.update(meRef, {
        'connections': FieldValue.arrayUnion([senderId]),
        'followers': FieldValue.arrayUnion([senderId]),
        'following': FieldValue.arrayUnion([senderId]),
      });

      batch.update(senderRef, {
        'connections': FieldValue.arrayUnion([user.uid]),
        'followers': FieldValue.arrayUnion([user.uid]),
        'following': FieldValue.arrayUnion([user.uid]),
      });
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    if (user == null) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Not signed in',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _requests,
      builder: (context, requestSnap) {
        if (requestSnap.hasError) {
          return const ErrorStateView(message: 'Could not load notifications.');
        }

        final requests =
            requestSnap.data?.docs ?? const <QueryDocumentSnapshot>[];

        return ApplicationFeed(
          uid: user.uid,
          builder: (departures, loading) {
            final updates = departures.where((d) => d.hasMoved).toList();
            final total = updates.length + requests.length;

            if (!requestSnap.hasData && loading) {
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, __) => AppSkeleton.listTile(),
              );
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  key: const ValueKey('title'),
                  child: BoardScreenTitle(
                    title: 'Board Updates',
                    meta: total == 0 ? 'All clear' : '$total NEW',
                  ),
                ),
                if (total == 0)
                  const SliverFillRemaining(
                    key: ValueKey('empty'),
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'Nothing new on the board',
                      message:
                          'Status changes on jobs you applied to, and\nconnection requests, arrive here.',
                    ),
                  )
                else
                  SliverPadding(
                    key: const ValueKey('panel'),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                    sliver: SliverToBoxAdapter(
                      child: _panel(updates, requests),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// The ink table. Rows share one three-column rhythm — time, what
  /// happened, and the thing you can act on — whether the row is a job
  /// moving or a person knocking.
  Widget _panel(
    List<Application> updates,
    List<QueryDocumentSnapshot> requests,
  ) {
    final rows = <Widget>[];

    for (var i = 0; i < updates.length; i++) {
      rows.add(
        _updateRow(
          updates[i],
          last: i == updates.length - 1 && requests.isEmpty,
        ),
      );
    }
    for (var i = 0; i < requests.length; i++) {
      rows.add(_requestRow(requests[i], last: i == requests.length - 1));
    }

    return Container(
      decoration: BoxDecoration(
        color: BoardColors.ink,
        borderRadius: BorderRadius.circular(BoardRadius.panel),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: BoardColors.onInkLine)),
            ),
            child: Row(
              children: [
                SizedBox(width: 56, child: _head('TIME')),
                const SizedBox(width: 8),
                Expanded(child: _head('UPDATE')),
                const SizedBox(width: 8),
                SizedBox(width: 84, child: _head('STATUS')),
              ],
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _head(String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: BoardType.mono(
      fontSize: 9.5,
      color: BoardColors.onInkFaint,
      letterSpacing: 1.15,
    ),
  );

  Widget _rowShell({
    required List<Widget> children,
    required bool last,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: last
                  ? Colors.transparent
                  : BoardColors.onInk.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget _updateRow(Application d, {required bool last}) {
    return _rowShell(
      last: last,
      onTap: () => d.open(context),
      children: [
        SizedBox(
          width: 56,
          child: FlapTile(
            text: relativeTime(d.start),
            fontSize: 11,
            background: BoardColors.slate,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                [d.posterName, d.title].where((s) => s.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BoardType.title(
                  fontSize: 15,
                  color: BoardColors.onInk,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'MOVED TO ${d.status}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BoardType.mono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w400,
                  color: BoardColors.onInkFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 84, child: FlapTile.status(d.status)),
      ],
    );
  }

  Widget _requestRow(QueryDocumentSnapshot req, {required bool last}) {
    final data = req.data() as Map<String, dynamic>? ?? {};
    final senderId = (data['senderId'] ?? '').toString();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get(),
      builder: (context, senderSnap) {
        final senderData =
            senderSnap.data?.data() as Map<String, dynamic>? ?? {};
        final name =
            (senderData['fullName'] ??
                    senderData['username'] ??
                    data['senderUsername'] ??
                    'User')
                .toString();

        return _rowShell(
          last: last,
          onTap: senderId.isEmpty
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(uid: senderId),
                  ),
                ),
          children: [
            SizedBox(
              width: 56,
              child: FlapTile(
                text: relativeTime(ApplicationFeed.asDate(data['timestamp'])),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.title(
                      fontSize: 15,
                      color: BoardColors.onInk,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sent a connection request',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                      color: BoardColors.onInkFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 84,
              child: Row(
                children: [
                  Expanded(
                    child: _answer(
                      'OK',
                      background: BoardColors.onInk,
                      foreground: BoardColors.ink,
                      onTap: () => _respondToRequest(req.id, senderId, true),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _answer(
                      'NO',
                      background: BoardColors.onInkWell,
                      foreground: BoardColors.onInk,
                      onTap: () => _respondToRequest(req.id, senderId, false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _answer(
    String label, {
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(BoardRadius.tile),
        ),
        child: Text(
          label,
          style: BoardType.mono(fontSize: 9, color: foreground),
        ),
      ),
    );
  }
}
