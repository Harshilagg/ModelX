import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/portfolio_masonry.dart';
import '../widgets/profile_photo_viewer.dart';
import '../widgets/shot_carousel.dart';
import '../widgets/state_views.dart';

/// A profile as other people see it (style board 7d).
///
/// Structured like the model's own profile — hero, tab rail, spec sheets
/// — rather than the long scroll it used to be, so a booker sizing
/// somebody up gets the numbers first and the prose only if they ask.
/// Periwinkle carries it, because this is the community side of the app.
///
/// Read-only: no field on the viewed profile is written from here. The
/// only writes are the connection request this page has always made.
class UserProfilePage extends StatefulWidget {
  final String uid;
  const UserProfilePage({super.key, required this.uid});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? userData;
  bool loading = true;
  bool isRequestSent = false;
  bool isConnected = false;
  bool isOwnProfile = false;
  int _tab = 0;

  /// Held in a field, not rebuilt inline. `.snapshots()` returns a new
  /// Stream each call and a StreamBuilder resubscribes when its stream
  /// identity changes, so an inline stream blanks itself on every parent
  /// rebuild — a tab switch, a filter tap, a setState.
  late final Stream<QuerySnapshot> _portfolio = FirebaseFirestore.instance
      .collection('portfolio')
      .where('uid', isEqualTo: widget.uid)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();

    if (!doc.exists) {
      if (mounted) setState(() => loading = false);
      return;
    }

    userData = doc.data()!;
    isOwnProfile = widget.uid == currentUser?.uid;

    if (!isOwnProfile) {
      await _checkConnectionStatus();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _checkConnectionStatus() async {
    final me = currentUser;
    if (me == null) return;
    final otherUserId = widget.uid;

    final meDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .get();

    final connections = meDoc.data()?['connections'] ?? [];
    if (connections.contains(otherUserId)) {
      if (mounted) setState(() => isConnected = true);
      return;
    }

    final req = await FirebaseFirestore.instance
        .collection('connection_requests')
        .where('senderId', isEqualTo: me.uid)
        .where('receiverId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (req.docs.isNotEmpty && mounted) {
      setState(() => isRequestSent = true);
    }
  }

  Future<void> sendConnectionRequest() async {
    final me = currentUser;
    if (me == null) return;

    final meDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(me.uid)
        .get();

    await FirebaseFirestore.instance.collection('connection_requests').add({
      'senderId': me.uid,
      'receiverId': widget.uid,
      'senderUsername': meDoc.data()?['username'] ?? '',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) setState(() => isRequestSent = true);
  }

  // ---- helpers ------------------------------------------------------

  String _v(String key, [String fallback = '—']) {
    final raw = (userData?[key] ?? '').toString().trim();
    return raw.isEmpty ? fallback : raw;
  }

  String _statValue(dynamic raw, [String suffix = '']) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '—';
    return suffix.trim().isEmpty ? value : '$value ${suffix.toUpperCase()}';
  }

  /// Joins whatever of a sheet's values exist into one preview line.
  String _summary(List<String> parts) {
    final kept = parts
        .map((p) => p.replaceAll('\n', ' · ').trim())
        .where((p) => p.isNotEmpty && p != '—')
        .toList();
    if (kept.isEmpty) return 'NOT SET';
    return kept.join(' · ').toUpperCase();
  }

  String _listValue(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).join(' · ');
    return (v ?? '').toString();
  }

  // ---- build --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: BoardColors.paper,
        body: Center(child: CircularProgressIndicator(color: BoardColors.ink)),
      );
    }

    if (userData == null) {
      return Scaffold(
        backgroundColor: BoardColors.paper,
        appBar: AppBar(backgroundColor: BoardColors.paper, elevation: 0),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile not found',
        ),
      );
    }

    return Scaffold(
      backgroundColor: BoardColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _hero(),
          _quadStats(),
          BoardTabRail(
            tabs: const ['Details', 'Portfolio'],
            index: _tab,
            onTap: (i) => setState(() => _tab = i),
            accent: BoardColors.brass,
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [_detailsTab(), _portfolioTab()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isOwnProfile ? null : _actionBar(),
    );
  }

  Widget _hero() {
    final fullName = (userData?['fullName'] ?? '').toString().trim();
    final username = (userData?['username'] ?? '').toString().trim();
    final age = (userData?['age'] ?? '').toString().trim();
    final availability = (userData?['availability'] ?? '').toString().trim();

    return Container(
      color: BoardColors.ink,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: BoardColors.onInk,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (fullName.isEmpty ? 'Profile' : fullName).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.title(
                        fontSize: 14,
                        letterSpacing: 1.6,
                        color: BoardColors.onInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: 'modelx://profile/${widget.uid}'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile link copied')),
                      );
                    },
                    child: Text(
                      'SHARE',
                      style: BoardType.mono(
                        fontSize: 9.5,
                        color: BoardColors.brass,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular: an identity, not a portfolio tile. Their
                  // work keeps the comp-card cut, in Latest shots and the
                  // Portfolio tab below.
                  //
                  // Tappable — somebody else's profile photo had no way
                  // to be opened at all.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showProfilePhoto(
                      context,
                      url: (userData?['profileImage'] ?? '').toString(),
                      name: fullName.isEmpty ? 'Profile' : fullName,
                    ),
                    child: BoardAvatar(
                      url: (userData?['profileImage'] ?? '').toString(),
                      name: fullName,
                      size: 96,
                      onDark: true,
                      ring: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (fullName.isEmpty ? 'Profile' : fullName)
                              .toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.display(
                            fontSize: 30,
                            color: BoardColors.onInk,
                            height: 0.9,
                          ),
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.mono(
                              fontSize: 10,
                              color: BoardColors.onInkSoft,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (age.isNotEmpty)
                              Flexible(
                                child: BoardStatWell(label: 'Age', value: age),
                              ),
                            if (age.isNotEmpty && availability.isNotEmpty)
                              const SizedBox(width: 6),
                            if (availability.isNotEmpty)
                              Flexible(
                                child: MonoChip(
                                  availability,
                                  filled: true,
                                  accent: BoardColors.brass,
                                  fontSize: 9.5,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quadStats() {
    final cells = [
      (
        'Height',
        _statValue(
          userData?['height'],
          (userData?['heightUnit'] ?? '').toString(),
        ),
      ),
      ('Measure', _statValue(userData?['measurements'])),
      ('Weight', _statValue(userData?['weight'])),
      ('Gender', _statValue(userData?['gender'])),
    ];

    return Container(
      color: BoardColors.inkLine,
      // IntrinsicHeight: this Row sits in a scroll view, so its height is
      // unbounded, and a bare `stretch` would hand the cells an infinite
      // height constraint. This measures the tallest cell, then squares
      // the rest to it so the hairline dividers run the full height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              Expanded(
                child: Container(
                  color: BoardColors.paper,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cells[i].$1.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.mono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w400,
                          color: BoardColors.inkSoft,
                          letterSpacing: 0.55,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cells[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.mono(
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i != cells.length - 1) const SizedBox(width: 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailsTab() {
    final bio = (userData?['bio'] ?? '').toString().trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        const BoardSectionLabel('About'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          color: BoardColors.card,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(
            bio.isEmpty ? 'No bio yet.' : bio,
            style: BoardType.body(
              fontSize: 13,
              color: bio.isEmpty ? BoardColors.inkSoft : BoardColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 14),

        const BoardSectionLabel('Spec sheet — tap to open'),
        const SizedBox(height: 6),
        _specRow(
          'Appearance',
          _summary([
            _v('skinColor', ''),
            _v('eyeColor', ''),
            _v('hairColor', ''),
          ]),
          _openAppearance,
        ),
        const SizedBox(height: 6),
        _specRow(
          'Professional',
          _summary([
            _v('skills', ''),
            _v('preferredWork', ''),
            _v('availability', ''),
          ]),
          _openProfessional,
        ),
        const SizedBox(height: 6),
        _specRow(
          'Career History',
          _summary([
            _listValue(userData?['projects']),
            _listValue(userData?['agencies']),
          ]),
          _openCareer,
        ),
        const SizedBox(height: 14),

        _latestShots(),
      ],
    );
  }

  Widget _latestShots() {
    return StreamBuilder<QuerySnapshot>(
      stream: _portfolio,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
        if (docs.isEmpty) return const SizedBox.shrink();

        final urls = docs
            .map(
              (d) => ((d.data() as Map<String, dynamic>)['mediaUrl'] ?? '')
                  .toString(),
            )
            .where((u) => u.isNotEmpty)
            .toList();
        if (urls.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            BoardSectionLabel(
              'Latest shots',
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = 1),
                child: MonoChip(
                  'ALL ${urls.length}',
                  filled: true,
                  accent: BoardColors.brass,
                  fontSize: 9.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ShotCarousel(
              urls: urls,
              accent: BoardColors.brass,
              onTap: (i) => _openShot(urls, i),
            ),
          ],
        );
      },
    );
  }

  /// Opens a shot full-bleed, and lets the viewer keep swiping the rest
  /// of the book from there rather than backing out between frames.
  void _openShot(List<String> urls, int index) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        final controller = PageController(initialPage: index);
        return Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: urls.length,
              itemBuilder: (_, i) => Center(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image_outlined,
                      color: BoardColors.onInkFaint,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(dialogContext).padding.top + 12,
              right: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'CLOSE',
                  style: BoardType.mono(fontSize: 11, color: BoardColors.brass),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _portfolioTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _portfolio,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingState(),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No portfolio yet',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            BoardSectionLabel(
              'Portfolio · ${docs.length} shot${docs.length == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 9),
            PortfolioMasonry(
              itemCount: docs.length,
              itemBuilder: (context, i, height) {
                final data = docs[i].data() as Map<String, dynamic>;
                final urls = [
                  for (final d in docs)
                    ((d.data() as Map<String, dynamic>)['mediaUrl'] ?? '')
                        .toString(),
                ];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openShot(urls, i),
                  child: BoardMedia(
                    url: (data['mediaUrl'] ?? '').toString(),
                    dark: i.isOdd,
                    cut: 20,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// A tap-to-open row in the spec sheet: the section's name, a one-line
  /// preview of what's inside, and the arrow that lifts the sheet.
  Widget _specRow(String title, String detail, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: BoardColors.card,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.title(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 10,
                      color: BoardColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: BoardColors.ink,
              ),
              child: const Icon(
                Icons.arrow_outward_rounded,
                size: 14,
                color: BoardColors.brass,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- sheets -------------------------------------------------------

  void _openAppearance() {
    showBoardSheet(
      context,
      title: 'Appearance',
      accent: BoardColors.brass,
      children: [
        SpecRow(label: 'Skin tone', value: _v('skinColor'), onDark: true),
        SpecRow(label: 'Eye color', value: _v('eyeColor'), onDark: true),
        SpecRow(label: 'Hair color', value: _v('hairColor'), onDark: true),
        SpecRow(label: 'Tattoos', value: _v('tattoos'), onDark: true),
        SpecRow(
          label: 'Piercing',
          value: _v('piercing'),
          onDark: true,
          bottomBorder: true,
        ),
      ],
    );
  }

  void _openProfessional() {
    showBoardSheet(
      context,
      title: 'Professional',
      accent: BoardColors.brass,
      children: [
        SpecRow(label: 'Skills', value: _v('skills'), onDark: true),
        SpecRow(
          label: 'Preferred work',
          value: _v('preferredWork'),
          onDark: true,
        ),
        SpecRow(label: 'Availability', value: _v('availability'), onDark: true),
        SpecRow(label: 'Experience', value: _v('experience'), onDark: true),
        SpecRow(
          label: 'Achievements',
          value: _v('achievements'),
          onDark: true,
          bottomBorder: true,
        ),
      ],
    );
  }

  void _openCareer() {
    final projects = _listValue(userData?['projects']);
    final agencies = _listValue(userData?['agencies']);
    showBoardSheet(
      context,
      title: 'Career History',
      accent: BoardColors.brass,
      children: [
        SpecRow(
          label: 'Projects',
          value: projects.trim().isEmpty ? '—' : projects,
          onDark: true,
        ),
        SpecRow(
          label: 'Agency associations',
          value: agencies.trim().isEmpty ? 'NONE' : agencies,
          onDark: true,
          bottomBorder: true,
        ),
      ],
    );
  }

  // ---- action bar ---------------------------------------------------

  Widget _actionBar() {
    final String label;
    final VoidCallback? onTap;

    if (isConnected) {
      label = 'Message';
      onTap = () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            peerId: widget.uid,
            peerName: (userData?['fullName'] ?? '').toString(),
            peerImage: (userData?['profileImage'] ?? '').toString(),
          ),
        ),
      );
    } else if (isRequestSent) {
      label = 'Request Sent';
      onTap = null;
    } else {
      label = 'Follow';
      onTap = sendConnectionRequest;
    }

    return Container(
      color: BoardColors.paper,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: BoardButton(label: label, onTap: onTap),
      ),
    );
  }
}
