import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/connection_requests.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/network_cards.dart';
import '../widgets/state_views.dart';

/// The full listing behind a Network rail.
///
/// A rail is a prompt — six suggestions, sized to be glanced at. These
/// are the same cards without the cap, for when somebody actually wants
/// to browse rather than be shown.

/// Shared chrome: back arrow, oversized condensed title, live count.
class _DirectoryScaffold extends StatelessWidget {
  final String title;
  final String? meta;
  final Widget child;

  const _DirectoryScaffold({required this.title, required this.child, this.meta});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back, size: 18, color: BoardColors.ink),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: BoardScreenTitle(title: title, meta: meta),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// People
/// ---------------------------------------------------------------------

/// Every model on the board, or every model in one city. Same card as
/// the rail, in a two-column grid.
class PeopleDirectoryPage extends StatefulWidget {
  final String title;

  /// People already connected, plus yourself.
  final Set<String> excluding;

  /// When set, only people whose `location` matches are shown.
  final String? location;

  const PeopleDirectoryPage({
    super.key,
    required this.title,
    required this.excluding,
    this.location,
  });

  @override
  State<PeopleDirectoryPage> createState() => _PeopleDirectoryPageState();
}

class _PeopleDirectoryPageState extends State<PeopleDirectoryPage> {
  final Set<String> _requested = {};
  bool _loaded = false;

  /// Created once rather than per build — see the note in NetworkPage.
  /// Following somebody calls setState, and an inline stream would
  /// resubscribe and blank the grid on every tap.
  late final Stream<QuerySnapshot> _people =
      FirebaseFirestore.instance.collection('users').limit(200).snapshots();

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final pending = await ConnectionRequests.pendingFrom(me.uid);
    if (!mounted) return;
    setState(() {
      _requested.addAll(pending);
      _loaded = true;
    });
  }

  Future<void> _follow(String uid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || _requested.contains(uid)) return;

    setState(() => _requested.add(uid));
    try {
      await ConnectionRequests.send(from: me.uid, to: uid);
    } catch (_) {
      if (!mounted) return;
      setState(() => _requested.remove(uid));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Capped rather than paged: the directory is a browse, not a feed,
      // and an unbounded listen over `users` would grow without limit.
      // Paging belongs here once the board is big enough to need it.
      stream: _people,
      builder: (context, snap) {
        if (snap.hasError) {
          return _DirectoryScaffold(
            title: widget.title,
            child: const ErrorStateView(message: 'Could not load the board.'),
          );
        }
        if (!snap.hasData) {
          return _DirectoryScaffold(
            title: widget.title,
            child: const LoadingState(),
          );
        }

        final target = widget.location?.trim().toLowerCase();
        final people = snap.data!.docs.where((d) {
          if (widget.excluding.contains(d.id)) return false;
          if (target == null || target.isEmpty) return true;
          final data = d.data() as Map<String, dynamic>? ?? {};
          return (data['location'] ?? '').toString().trim().toLowerCase() == target;
        }).toList();

        if (people.isEmpty) {
          return _DirectoryScaffold(
            title: widget.title,
            meta: 'NOBODY YET',
            child: const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'Nobody here yet',
              message: 'New people show up as they join the board.',
            ),
          );
        }

        return _DirectoryScaffold(
          title: widget.title,
          meta: '${people.length} ${people.length == 1 ? 'PERSON' : 'PEOPLE'}',
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gutter = 14.0;
              const gap = 9.0;
              final cellWidth = (constraints.maxWidth - gutter * 2 - gap) / 2;
              // Keep the rail's crop proportions so a face is the same
              // shape in both places.
              final cropHeight = cellWidth * (168 / 132);

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, 28),
                itemCount: people.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: 16,
                  mainAxisExtent: cropHeight + PersonCropCard.captionHeight(context),
                ),
                itemBuilder: (context, i) {
                  final doc = people[i];
                  return PersonCropCard(
                    doc: doc,
                    cropHeight: cropHeight,
                    dark: i.isOdd,
                    requested: _requested.contains(doc.id),
                    enabled: _loaded,
                    onFollow: () => _follow(doc.id),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// Hiring
/// ---------------------------------------------------------------------

/// Every brand and agency with an open call, full width.
class HiringDirectoryPage extends StatefulWidget {
  const HiringDirectoryPage({super.key});

  @override
  State<HiringDirectoryPage> createState() => _HiringDirectoryPageState();
}

class _HiringDirectoryPageState extends State<HiringDirectoryPage> {
  // Unfiltered, to match the rail: every brand on the board, with its
  // open-call count on the card.
  late final Stream<QuerySnapshot> _gigs =
      FirebaseFirestore.instance.collection('gigs').limit(200).snapshots();

  late final Stream<QuerySnapshot> _castings =
      FirebaseFirestore.instance.collection('castings').limit(200).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _gigs,
      builder: (context, gigSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _castings,
          builder: (context, castSnap) {
            // Both settle before folding, so a slow query can't render a
            // half-list that looks like missing data.
            final settled = (gigSnap.hasData || gigSnap.hasError) &&
                (castSnap.hasData || castSnap.hasError);
            if (!settled) {
              return const _DirectoryScaffold(
                title: 'Brands',
                child: LoadingState(),
              );
            }

            final posters = BoardPoster.collect(
              gigs: gigSnap.data?.docs ?? const [],
              castings: castSnap.data?.docs ?? const [],
            );

            if (posters.isEmpty) {
              return const _DirectoryScaffold(
                title: 'Brands',
                meta: 'NOBODY YET',
                child: EmptyState(
                  icon: Icons.work_outline_rounded,
                  title: 'No brands yet',
                  message: 'Brands and agencies show up here as they post.',
                ),
              );
            }

            final open = posters.fold<int>(0, (total, p) => total + p.openCount);

            return _DirectoryScaffold(
              title: 'Brands',
              meta: '${posters.length} ON THE BOARD · $open OPEN',
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                itemCount: posters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, i) => PosterCard(poster: posters[i]),
              ),
            );
          },
        );
      },
    );
  }
}
