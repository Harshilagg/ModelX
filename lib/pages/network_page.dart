import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_page.dart';
import 'chat_page.dart';
import 'comp_card_page.dart';
import 'network_directory_page.dart';
import '../services/connection_requests.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/network_cards.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

/// Network (style board 4c, on Slate Nude).
///
/// Five bands, in the order a model needs them: finish your card, the
/// people you already know, new faces on the board, models in your city,
/// and who is actually hiring right now.
///
/// Everything here is assembled from collections a model account can
/// genuinely read. `brands/` and `agency/` are owner-only under the
/// current rules, so the hiring band is derived from the live postings
/// themselves — which is the better signal anyway: it lists whoever is
/// hiring *today*, not whoever once registered.
class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  /// The fields a comp card prints. Kept identical to the profile's own
  /// readiness row so the two numbers can never disagree.
  static const _cardFields = [
    'height',
    'weight',
    'waist',
    'hips',
    'shoeSize',
    'eyeColor',
    'hairColor',
    'username',
  ];

  /// People with an outstanding request from this model. Held here
  /// rather than in a rail so every band agrees about who's been asked.
  final Set<String> _requested = {};
  bool _loadedPending = false;

  /// Created once, not per build.
  ///
  /// `.snapshots()` hands back a *new* Stream object on every call, and a
  /// StreamBuilder resubscribes whenever its stream identity changes —
  /// dropping back to "no data" each time. Building these inline meant
  /// every rebuild of this page (a follow, a snapshot, a tab switch) reset
  /// every band on it.
  Stream<DocumentSnapshot>? _meStream;
  Stream<QuerySnapshot>? _poolStream;

  @override
  void initState() {
    super.initState();
    final me = currentUser;
    if (me != null) {
      _meStream = FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .snapshots();
      _poolStream = FirebaseFirestore.instance
          .collection('users')
          .limit(60)
          .snapshots();
    }
    _loadPending();
  }

  Future<void> _loadPending() async {
    final me = currentUser;
    if (me == null) return;
    final pending = await ConnectionRequests.pendingFrom(me.uid);
    if (!mounted) return;
    setState(() {
      _requested.addAll(pending);
      _loadedPending = true;
    });
  }

  Future<void> _follow(String uid) async {
    final me = currentUser;
    if (me == null || _requested.contains(uid)) return;

    setState(() => _requested.add(uid));

    try {
      await ConnectionRequests.send(from: me.uid, to: uid);
    } catch (_) {
      if (!mounted) return;
      // Put the stud back rather than leaving a request that never landed
      // looking sent.
      setState(() => _requested.remove(uid));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request. Try again.')),
      );
    }
  }

  int _readiness(Map<String, dynamic> me) {
    final filled = _cardFields
        .where((k) => (me[k] ?? '').toString().trim().isNotEmpty)
        .length;
    return (filled / _cardFields.length * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    if (user == null) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Not signed in',
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _meStream,
      builder: (context, meSnap) {
        if (meSnap.hasError) {
          return const ErrorStateView(message: 'Could not load your network.');
        }
        if (!meSnap.hasData) return _skeleton();

        final me = meSnap.data!.data() as Map<String, dynamic>? ?? {};
        final connections = List<String>.from(me['connections'] ?? const []);
        final myLocation = (me['location'] ?? '').toString().trim();
        final readiness = _readiness(me);

        // One read of the directory, shared by both people rails, rather
        // than a stream per band over the same collection.
        return StreamBuilder<QuerySnapshot>(
          stream: _poolStream,
          builder: (context, poolSnap) {
            final exclude = {...connections, user.uid};
            final pool =
                (poolSnap.data?.docs ?? const <QueryDocumentSnapshot>[])
                    .where((d) => !exclude.contains(d.id))
                    .toList();

            final nearby = myLocation.isEmpty
                ? const <QueryDocumentSnapshot>[]
                : pool.where((d) {
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final loc = (data['location'] ?? '').toString().trim();
                    return loc.isNotEmpty &&
                        loc.toLowerCase() == myLocation.toLowerCase();
                  }).toList();

            // Nearby models are the more specific suggestion, so they
            // don't get repeated in the general discovery rail above.
            final nearbyIds = nearby.map((d) => d.id).toSet();
            final discover = pool
                .where((d) => !nearbyIds.contains(d.id))
                .toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  key: const ValueKey('title'),
                  child: BoardScreenTitle(
                    title: 'Network',
                    meta:
                        '${connections.length} CONNECTION${connections.length == 1 ? '' : 'S'}',
                  ),
                ),

                // ---- 1. Finish your card ----
                if (readiness < 70)
                  SliverToBoxAdapter(
                    key: const ValueKey('nudge'),
                    child: _CompCardNudge(readiness: readiness),
                  ),

                // ---- 2. Your connections ----
                if (connections.isEmpty)
                  const SliverToBoxAdapter(
                    key: ValueKey('connections-empty'),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No connections yet',
                        message: 'Every accepted request shows up here.',
                      ),
                    ),
                  )
                else ...[
                  const SliverToBoxAdapter(
                    key: ValueKey('connections-label'),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: BoardSectionLabel('Your connections'),
                    ),
                  ),
                  SliverPadding(
                    key: const ValueKey('connections'),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    sliver: SliverList.separated(
                      itemCount: connections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) =>
                          _ConnectionRow(uid: connections[i]),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(
                  key: ValueKey('gap'),
                  child: SizedBox(height: 18),
                ),

                // ---- 3. New faces ----
                if (!poolSnap.hasData)
                  const SliverToBoxAdapter(
                    key: ValueKey('pool-loading'),
                    child: SizedBox(height: 200, child: LoadingState()),
                  )
                else if (discover.isNotEmpty)
                  SliverToBoxAdapter(
                    key: const ValueKey('discover'),
                    child: _PeopleRail(
                      label: 'People on the board',
                      meta: 'ALL ${discover.length}',
                      people: discover.take(6).toList(),
                      requested: _requested,
                      enabled: _loadedPending,
                      onFollow: _follow,
                      onShowAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PeopleDirectoryPage(
                            title: 'People on the board',
                            excluding: exclude,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ---- 4. Models in your city ----
                if (nearby.isNotEmpty)
                  SliverToBoxAdapter(
                    key: const ValueKey('nearby'),
                    child: _NearbyRail(
                      location: myLocation,
                      people: nearby.take(10).toList(),
                      onShowAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PeopleDirectoryPage(
                            title: 'Models in $myLocation',
                            excluding: exclude,
                            location: myLocation,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ---- 5. Who is hiring ----
                const SliverToBoxAdapter(
                  key: ValueKey('hiring'),
                  child: _HiringRail(),
                ),

                const SliverToBoxAdapter(
                  key: ValueKey('bottom'),
                  child: SizedBox(height: 110),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _skeleton() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, __) => AppSkeleton.listTile(),
  );
}

/// ---------------------------------------------------------------------
/// 1 · Comp card nudge
/// ---------------------------------------------------------------------

/// Shown only while the card is thin. A model with a finished card has
/// no use for this band, and a permanent banner is how a prompt stops
/// being read at all.
class _CompCardNudge extends StatelessWidget {
  final int readiness;
  const _CompCardNudge({required this.readiness});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompCardPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BoardColors.ink,
            borderRadius: BorderRadius.circular(BoardRadius.panel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'YOUR COMP CARD',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.display(
                            fontSize: 24,
                            color: BoardColors.onInk,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Brands find models by their card. Yours is '
                          'missing a few of the numbers it prints.',
                          style: BoardType.body(
                            fontSize: 12.5,
                            color: BoardColors.onInk.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$readiness%',
                    style: BoardType.display(
                      fontSize: 30,
                      color: BoardColors.brass,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // A bar rather than a ring: it reads as "how far along",
              // which is the one thing this band is asking about.
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: readiness / 100,
                  minHeight: 4,
                  backgroundColor: BoardColors.onInkWell,
                  valueColor: const AlwaysStoppedAnimation(BoardColors.brass),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'FREE · NO WATERMARK',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.mono(
                        fontSize: 9.5,
                        color: BoardColors.onInkSoft,
                        letterSpacing: 0.95,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: BoardColors.brass,
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 14,
                      color: BoardColors.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// 2 · Connections
/// ---------------------------------------------------------------------

/// A connected person: circular portrait, name, handle or bio, Message.
class _ConnectionRow extends StatelessWidget {
  final String uid;
  const _ConnectionRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 0);
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};

        final name =
            (data['fullName'] ??
                    '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
                .toString()
                .trim();
        final username = (data['username'] ?? '').toString();
        final location = (data['location'] ?? '').toString();
        final bio = (data['bio'] ?? '').toString();

        // Prefer the handle line; fall back to the bio so the row is
        // never a bare name with dead space beside it.
        final meta = [
          if (username.isNotEmpty) '@$username',
          if (location.isNotEmpty) location.toUpperCase(),
        ].join(' · ');

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfilePage(uid: uid)),
          ),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: BoardColors.card,
              borderRadius: BorderRadius.circular(BoardRadius.card),
            ),
            child: Row(
              children: [
                // People you already know read as people — the cut card
                // is reserved for the rails below, where you actually are
                // judging a card.
                BoardAvatar(
                  url: (data['profileImage'] ?? '').toString(),
                  name: name,
                  size: 48,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (name.isEmpty ? 'User' : name).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.title(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: BoardColors.inkSoft,
                          ),
                        ),
                      ] else if (bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.body(
                            fontSize: 11,
                            color: BoardColors.inkSoft,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        peerId: uid,
                        peerName: name,
                        peerImage: (data['profileImage'] ?? '').toString(),
                      ),
                    ),
                  ),
                  child: const MonoChip(
                    'MESSAGE',
                    filled: true,
                    accent: BoardColors.ink,
                    fontSize: 9.5,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
/// Shared rail chrome
/// ---------------------------------------------------------------------

/// Header, horizontal list, progress dashes, rule. Every band on this
/// screen scrolls the same way, so they share one scaffold instead of
/// each re-implementing a scroll controller and an indicator.
class _BoardRail extends StatefulWidget {
  final String label;
  final String? meta;
  final double height;
  final int itemCount;
  final double gap;
  final IndexedWidgetBuilder itemBuilder;

  /// Opens the full listing. A rail is a prompt, not a browse — without
  /// this the six suggestions are a dead end.
  final VoidCallback? onShowAll;

  const _BoardRail({
    super.key,
    required this.label,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.meta,
    this.gap = 9,
    this.onShowAll,
  });

  @override
  State<_BoardRail> createState() => _BoardRailState();
}

class _BoardRailState extends State<_BoardRail> {
  final ScrollController _controller = ScrollController();
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final next = max <= 0 ? 0.0 : (_controller.offset / max).clamp(0.0, 1.0);
    if ((next - _progress).abs() > 0.005) setState(() => _progress = next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: BoardSectionLabel(
            widget.label,
            // The count and the way in are one control rather than two:
            // a bare count next to a separate "all" crowds a header that
            // already carries a long section name.
            trailing: widget.onShowAll == null
                ? (widget.meta == null
                      ? null
                      : Text(
                          widget.meta!,
                          style: BoardType.mono(
                            fontSize: 9.5,
                            color: BoardColors.inkSoft,
                            letterSpacing: 0.95,
                          ),
                        ))
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onShowAll,
                    child: MonoChip(
                      widget.meta ?? 'SHOW ALL',
                      filled: true,
                      accent: BoardColors.ink,
                      fontSize: 9.5,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(
          height: widget.height,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: widget.itemCount,
            separatorBuilder: (_, __) => SizedBox(width: widget.gap),
            itemBuilder: widget.itemBuilder,
          ),
        ),
        const SizedBox(height: 10),
        _ProgressDashes(progress: _progress, segments: 3),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(height: 1, color: BoardColors.inkLine),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// Three dashes tracking how far along a rail you are. Deliberately not
/// one dot per card: the count is not the point, the sense of "there is
/// more to the right" is.
class _ProgressDashes extends StatelessWidget {
  final double progress;
  final int segments;

  const _ProgressDashes({required this.progress, required this.segments});

  @override
  Widget build(BuildContext context) {
    final active = (progress * (segments - 1)).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (var i = 0; i < segments; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                color: i == active ? BoardColors.ink : BoardColors.inkLine,
              ),
            ),
            if (i != segments - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// 3 · People on the board
/// ---------------------------------------------------------------------

/// New faces, as comp-card crops — the shape you judge talent in.
class _PeopleRail extends StatelessWidget {
  final String label;
  final String? meta;
  final List<QueryDocumentSnapshot> people;
  final Set<String> requested;
  final bool enabled;
  final ValueChanged<String> onFollow;
  final VoidCallback onShowAll;

  static const _cardWidth = 132.0;
  static const _cropHeight = 168.0;

  const _PeopleRail({
    required this.label,
    required this.people,
    required this.requested,
    required this.enabled,
    required this.onFollow,
    required this.onShowAll,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return _BoardRail(
      key: ValueKey('rail-$label'),
      label: label,
      meta: meta,
      onShowAll: onShowAll,
      height: _cropHeight + PersonCropCard.captionHeight(context),
      itemCount: people.length,
      itemBuilder: (context, i) {
        final doc = people[i];
        return PersonCropCard(
          doc: doc,
          width: _cardWidth,
          cropHeight: _cropHeight,
          dark: i.isOdd,
          requested: requested.contains(doc.id),
          enabled: enabled,
          onFollow: () => onFollow(doc.id),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// 4 · Models in your city
/// ---------------------------------------------------------------------

/// Circular, and deliberately lighter than the crop rail above it.
///
/// The hook here is proximity, not portfolio — you are being told *who is
/// around*, which is an identity prompt. It also stops the screen being
/// three near-identical card rails in a row.
class _NearbyRail extends StatelessWidget {
  final String location;
  final List<QueryDocumentSnapshot> people;
  final VoidCallback onShowAll;

  const _NearbyRail({
    required this.location,
    required this.people,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final caption = 8 + scaler.scale(12) * 1.05 + 2 + scaler.scale(9) * 1.1 + 4;

    return _BoardRail(
      key: const ValueKey('rail-nearby'),
      label: 'Models in ${location.toUpperCase()}',
      meta: 'ALL ${people.length}',
      onShowAll: onShowAll,
      height: 64 + caption,
      gap: 14,
      itemCount: people.length,
      itemBuilder: (context, i) {
        final doc = people[i];
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name =
            (data['fullName'] ??
                    '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
                .toString()
                .trim();
        final username = (data['username'] ?? '').toString();

        return SizedBox(
          width: 72,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserProfilePage(uid: doc.id)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BoardAvatar(
                  url: (data['profileImage'] ?? '').toString(),
                  name: name,
                  size: 64,
                ),
                const SizedBox(height: 8),
                Text(
                  (name.isEmpty ? 'User' : name.split(' ').first).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: BoardType.title(fontSize: 12, letterSpacing: 0.35),
                ),
                if (username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: BoardType.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: BoardColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------
/// 5 · Who is hiring
/// ---------------------------------------------------------------------

/// Brands and agencies with live postings.
///
/// `brands/` and `agency/` are owner-only under the current rules, so
/// this is derived from the postings themselves — which is the more
/// useful list anyway: it shows who is hiring *today*, with a way in.
class _HiringRail extends StatefulWidget {
  const _HiringRail();

  @override
  State<_HiringRail> createState() => _HiringRailState();
}

class _HiringRailState extends State<_HiringRail> {
  // Unfiltered: a brand is only visible through what it has posted, so
  // filtering to open postings would hide every brand between campaigns.
  // The card says how many of their calls are currently open.
  late final Stream<QuerySnapshot> _gigs = FirebaseFirestore.instance
      .collection('gigs')
      .limit(200)
      .snapshots();

  late final Stream<QuerySnapshot> _castings = FirebaseFirestore.instance
      .collection('castings')
      .limit(200)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _gigs,
      builder: (context, gigSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _castings,
          builder: (context, castSnap) {
            // Wait for both to resolve — data or error — before folding.
            // Rendering on whichever arrives first is how a board full of
            // brands could show nothing but agencies: the gigs query had
            // simply not answered yet.
            final gigsSettled = gigSnap.hasData || gigSnap.hasError;
            final castingsSettled = castSnap.hasData || castSnap.hasError;

            // Never render nothing: an invisible section is
            // indistinguishable from one that was never built at all.
            if (!gigsSettled || !castingsSettled) {
              return const _RailNotice(
                label: 'Brands on the board',
                message: 'Loading…',
              );
            }

            // A failed query used to collapse to nothing, which is
            // indistinguishable from "nobody is hiring" — and left no way
            // to tell the two apart from the outside.
            if (gigSnap.hasError || castSnap.hasError) {
              debugPrint(
                '[hiring] gigs: ${gigSnap.error}  castings: ${castSnap.error}',
              );
              return const _RailNotice(
                label: 'Brands on the board',
                message: "Couldn't load the brands on the board.",
              );
            }

            final list = BoardPoster.collect(
              gigs: gigSnap.data?.docs ?? const [],
              castings: castSnap.data?.docs ?? const [],
            );

            if (list.isEmpty) {
              final postings =
                  (gigSnap.data?.docs.length ?? 0) +
                  (castSnap.data?.docs.length ?? 0);
              return _RailNotice(
                label: 'Brands on the board',
                message: postings == 0
                    ? 'No brands have posted yet.'
                    : "$postings posting${postings == 1 ? '' : 's'}, but none name a brand or agency.",
              );
            }

            return _BoardRail(
              key: const ValueKey('rail-hiring'),
              label: 'Brands on the board',
              meta: 'ALL ${list.length}',
              onShowAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HiringDirectoryPage()),
              ),
              height: PosterCard.heightFor(context),
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  PosterCard(poster: list[i], width: PosterCard.railWidth),
            );
          },
        );
      },
    );
  }
}

/// A section that can't show its cards, saying so.
///
/// Every band on this screen used to collapse to `SizedBox.shrink()` when
/// something went wrong, so a permission error, an empty collection and a
/// bug all looked identical: a gap. This keeps the heading and explains
/// the gap.
class _RailNotice extends StatelessWidget {
  final String label;
  final String message;

  const _RailNotice({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: BoardSectionLabel(label),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BoardColors.shell,
            borderRadius: BorderRadius.circular(BoardRadius.card),
          ),
          child: Text(
            message,
            style: BoardType.body(fontSize: 12.5, color: BoardColors.inkSoft),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
