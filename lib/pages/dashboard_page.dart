import 'package:flutter/material.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import 'network_page.dart';
import 'jobs_page.dart';
import 'profile_page.dart';
import 'chat_inbox_page.dart';
import 'search_service_impl.dart';
import 'user_profile_page.dart';
import 'search_results_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../services/copilot_conversation.dart';
import '../widgets/kit/kit.dart';

/// The app shell for the model side.
///
/// Five destinations on the floating pill bar — Home, Notifications,
/// Network, Jobs, Profile. Profile used to be a pushed route reached from
/// the avatar; the board design gives it a slot on the bar instead, so
/// "me" is always one tap away rather than buried behind a header icon.
///
/// The search field, the unread-message count and the nav bar live here
/// so the four board screens don't each re-implement them.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// The bar's four destinations, in order.
  ///
  /// Notifications used to be the second of five. The redesigned bar
  /// holds four -- a fifth does not fit once the selected one expands
  /// to carry its label -- and notifications is the one people reach
  /// from a badge rather than by browsing, so it moved to the top bar.
  static const _tabHome = 0;
  static const _tabJobs = 1;
  static const _tabProfile = 3;

  int _selectedIndex = _tabHome;

  /// Set when Home's Up next counts open Jobs, so the list arrives
  /// already narrowed to whatever was tapped. Cleared as soon as the
  /// user picks another tab, or the filter would stick on every later
  /// visit.
  String? _jobsStatus;
  DateTime? _lastBackPress;

  final SearchService _searchService = SearchService();
  List<Map<String, dynamic>> searchResults = [];
  bool searching = false;
  String _userType = 'User';
  String _avatarUrl = '';
  String _displayName = '';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<String> recentSearches = [];
  bool showRecent = false;
  static const int _suggestionLimit = 5;

  /// Slate Nude carries a single accent. The old board ran a different
  /// hue per destination; this palette gives brass to money and the comp
  /// card, and reserves green/amber/red for status alone — so a screen is
  /// now told apart by its content, not by being tinted.
  static const _accent = BoardColors.brass;

  /// One per destination, in the bar's order.
  static const _searchHints = [
    'Search users or @username',
    'Search jobs, brands, cities',
    'Search users or @username',
    'Search users or @username',
  ];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && mounted) {
        setState(() => showRecent = false);
      }
    });
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _userType = data['userType'] ?? 'User';
          _avatarUrl = (data['profileImage'] ?? '').toString();
          _displayName = (data['fullName'] ?? data['username'] ?? '')
              .toString();
        });
      }
    }
  }

  void onSearchChanged(String query) async {
    final q = query.trim();
    // Normalize common username input: strip leading '@' so we search stored usernames
    final normalized = q.replaceFirst(RegExp(r'^@'), '');
    if (normalized.isEmpty) {
      setState(() {
        searchResults = [];
        showRecent = _searchFocus.hasFocus;
      });
      return;
    }

    setState(() {
      searching = true;
      showRecent = false;
    });

    final results = await _runSearch(normalized);
    if (!mounted) return;

    setState(() {
      searchResults = results.take(_suggestionLimit).toList();
      searching = false;
    });
  }

  // wrapper to call search service and handle exceptions
  Future<List<Map<String, dynamic>>> _runSearch(String q) async {
    try {
      return await _searchService.searchUsers(q);
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    if (!mounted) return;
    setState(() => recentSearches = list);
  }

  Future<void> _addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > 10) list.removeRange(10, list.length);
    await prefs.setStringList('recent_searches', list);
    if (!mounted) return;
    setState(() => recentSearches = list);
  }

  void _dismissSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      searchResults = [];
      showRecent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = _accent;
    final navBottom = MediaQuery.of(context).padding.bottom + 14;
    // Profile carries its own header, so the shared search bar would be
    // a second one competing with it. This read `!= 4` against the old
    // five-tab order and quietly started showing once Profile moved to
    // index three.
    final showTopBar = _selectedIndex != _tabProfile;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Back goes to Home first, and only leaves the app from there.
        if (_selectedIndex != _tabHome) {
          setState(() => _selectedIndex = _tabHome);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return;
        }
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: BoardColors.paper,
        body: Stack(
          children: [
            Column(
              children: [
                if (showTopBar)
                  SafeArea(
                    bottom: false,
                    child: _UnreadCount(
                      builder: (unread) => BoardTopBar(
                        avatarUrl: _avatarUrl,
                        initial: _displayName.isNotEmpty
                            ? _displayName[0]
                            : '?',
                        hint: _searchHints[_selectedIndex],
                        unread: unread,
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: onSearchChanged,
                        onAvatar: () {
                          _dismissSearch();
                          setState(() => _selectedIndex = _tabProfile);
                        },
                        onSearch: () {
                          if (_searchController.text.trim().isEmpty) {
                            _loadRecentSearches();
                            setState(() => showRecent = true);
                          }
                        },
                        onNotifications: () {
                          _dismissSearch();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                        },
                        onMessages: () {
                          _dismissSearch();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatInboxPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Expanded(
                  // Inset the page area by the system's bottom padding so
                  // each screen's own bottom padding is measured from
                  // above the home indicator. The floating bar needs
                  // `inset + 14 + 68` of clearance; the screens pad a flat
                  // 110, which only covers that once the inset is taken
                  // out here.
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _dismissSearch,
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          HomePage(
                            onOpenJobs: () =>
                                setState(() => _selectedIndex = _tabJobs),
                            // The counts on the Up next card open Jobs
                            // already narrowed to what was counted.
                            onOpenJobsFiltered: (status) => setState(() {
                              _jobsStatus = status;
                              _selectedIndex = _tabJobs;
                            }),
                          ),
                          JobsPage(initialStatus: _jobsStatus),
                          const NetworkPage(),
                          const ProfilePage(embedded: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Tap-catcher behind the suggestion overlay.
            if (showRecent || searchResults.isNotEmpty)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _dismissSearch,
                  child: const SizedBox.expand(),
                ),
              ),

            if (showTopBar && (showRecent || searchResults.isNotEmpty))
              _searchOverlay(),

            // The assistant, docked or open.
            //
            // Rendered in the shell's own Stack rather than pushed as a
            // route or a modal sheet: the aperture has to stay visible
            // and tappable while it works, which is what its states are
            // for, and a modal would cover it with the thing it opened.
            if (_copilot == CopilotStage.docked)
              Positioned(
                left: 14,
                right: 14,
                bottom: navBottom + AppNavBar.height + 12,
                child: AnimatedBuilder(
                  animation: CopilotConversation.instance,
                  builder: (context, _) => CopilotDock(
                    conversation: CopilotConversation.instance,
                    pageContext: _copilotContext,
                    suggestions: _copilotOpeners,
                    onExpand: () =>
                        setState(() => _copilot = CopilotStage.open),
                    onDismiss: () =>
                        setState(() => _copilot = CopilotStage.closed),
                  ),
                ),
              ),

            if (_copilot == CopilotStage.open)
              Positioned.fill(
                child: Stack(
                  children: [
                    // Tapping away puts it back down rather than
                    // closing it, so the thread is still there.
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _copilot = CopilotStage.docked),
                        behavior: HitTestBehavior.opaque,
                        child: ColoredBox(
                          color: BoardColors.ink.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.82,
                        child: CopilotPanel(
                          conversation: CopilotConversation.instance,
                          pageContext: _copilotContext,
                          suggestions: _copilotOpeners,
                          onCollapse: () =>
                              setState(() => _copilot = CopilotStage.closed),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // The floating pill bar rides above the content rather than
            // taking a row of its own, which is why every board screen
            // pads its scroll view clear of it at the bottom.
            Positioned(
              left: 14,
              right: 14,
              bottom: navBottom,
              // The assistant rides beside the bar rather than floating
              // over the content. It used to sit above it, which meant
              // it covered whatever was underneath on every screen.
              child: Row(
                children: [
                  Expanded(
                    child: AppNavBar(
                      currentIndex: _selectedIndex,
                      accent: accent,
                      destinations: const [
                        NavDestination(label: 'Home', glyph: NavGlyph.home),
                        NavDestination(label: 'Jobs', glyph: NavGlyph.jobs),
                        NavDestination(
                          label: 'Network',
                          glyph: NavGlyph.network,
                        ),
                        NavDestination(
                          label: 'Profile',
                          glyph: NavGlyph.profile,
                        ),
                      ],
                      onTap: (i) {
                        // Picking a tab by hand clears any filter Home
                        // asked for, or Jobs would stay narrowed on
                        // every later visit with nothing on screen
                        // explaining why.
                        if (i != _tabJobs) _jobsStatus = null;
                        _dismissSearch();
                        setState(() => _selectedIndex = i);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _assistant(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The assistant, on the light disc the design gives it.
  ///
  /// Dark blades on a pale ground here rather than the reverse: the
  /// button sits against a dark bar, and it is the one thing on the row
  /// that is not a destination.
  /// Where the assistant is: shut, docked over the bar, or open.
  CopilotStage _copilot = CopilotStage.closed;

  Map<String, dynamic> get _copilotContext => {
    'page': 'home',
    'role': _userType,
    'tab': const ['Home', 'Jobs', 'Network', 'Profile'][_selectedIndex],
  };

  /// Openers for the destination underneath, so the first tap is a
  /// question rather than a blank field.
  List<String> get _copilotOpeners {
    final model = _userType != 'Brand' && _userType != 'Agency';
    return switch (_selectedIndex) {
      _tabJobs =>
        model
            ? const ['Which of these fit me?', 'How do I stand out?']
            : const ['How do I post a gig?', 'Who should I shortlist?'],
      _tabProfile =>
        model
            ? const ['Analyze my bio', 'Portfolio tips']
            : const ['Company profile tips', 'View my postings'],
      _ =>
        model
            ? const ['How do I get hired?', 'Portfolio tips']
            : const ['How do I scout models?', 'Hiring tips'],
    };
  }

  void _openAssistant() {
    _dismissSearch();
    setState(() {
      // Tapping it again puts it away, since the button stays on screen
      // rather than being covered by what it opened.
      _copilot = _copilot == CopilotStage.closed
          ? CopilotStage.docked
          : CopilotStage.closed;
    });
  }

  /// The button reflects what the assistant is doing, which is the
  /// reason it has states and the reason it stays visible.
  ApertureState get _apertureState {
    if (_copilot == CopilotStage.closed) return ApertureState.idle;
    if (CopilotConversation.instance.sending) return ApertureState.thinking;
    return ApertureState.listening;
  }

  /// The assistant: the mark on its own, no disc behind it.
  ///
  /// Which means it keeps the palette it was designed in -- pale blades
  /// on a dark ground -- rather than being inverted to read against a
  /// light circle. Sized to the bar so the row lines up.
  Widget _assistant() {
    return ApertureButton(
      state: _apertureState,
      size: AppNavBar.height,
      // Ink, not the reference's grey. With no disc behind it the ring
      // sits straight on the page, where grey-on-paper barely reads --
      // the reference drew it on near-black.
      ringColor: BoardColors.ink,
      onPressed: _openAssistant,
    );
  }

  Widget _searchOverlay() {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.of(context).padding.top + 52,
      child: Material(
        color: BoardColors.card,
        borderRadius: BorderRadius.circular(BoardRadius.card),
        elevation: 6,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: Builder(
            builder: (context) {
              if (showRecent && _searchController.text.trim().isEmpty) {
                if (recentSearches.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No recent searches',
                      style: BoardType.mono(color: BoardColors.inkSoft),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: recentSearches.length,
                  itemBuilder: (_, i) {
                    final q = recentSearches[i];
                    return ListTile(
                      dense: true,
                      title: Text(q, style: BoardType.body(fontSize: 13)),
                      onTap: () {
                        _searchController.text = q;
                        onSearchChanged(q);
                        _addRecentSearch(q);
                      },
                    );
                  },
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: searchResults.length + 1,
                itemBuilder: (_, index) {
                  if (index < searchResults.length) {
                    final user = searchResults[index];
                    final name =
                        (user['fullName'] ??
                                '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}')
                            .toString()
                            .trim();
                    final sub =
                        (user['username'] != null &&
                            user['username'].toString().isNotEmpty)
                        ? '@${user['username']}'
                        : (user['bio'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 34,
                        height: 40,
                        child: BoardMedia(
                          url: user['profileImage']?.toString(),
                          cut: 9,
                        ),
                      ),
                      title: Text(
                        name.isEmpty ? 'User' : name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.title(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.mono(
                          fontSize: 10,
                          color: BoardColors.inkSoft,
                        ),
                      ),
                      onTap: () async {
                        final uid = user['uid'];
                        FocusScope.of(context).unfocus();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfilePage(uid: uid),
                          ),
                        );
                        if (!mounted) return;
                        _addRecentSearch(_searchController.text.trim());
                        setState(() {
                          searchResults.clear();
                          showRecent = false;
                        });
                      },
                    );
                  }

                  return ListTile(
                    dense: true,
                    title: Text(
                      'See all results',
                      style: BoardType.mono(fontSize: 10.5),
                    ),
                    onTap: () {
                      final q = _searchController.text.trim();
                      if (q.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchResultsPage(query: q),
                        ),
                      );
                      _addRecentSearch(q);
                      setState(() {
                        searchResults = [];
                        showRecent = false;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}

/// Totals unread messages across every chat and hands the count to the
/// top bar. Kept as its own widget so a snapshot only rebuilds the bar,
/// not the whole shell (and therefore not the visible page).
class _UnreadCount extends StatefulWidget {
  final Widget Function(int unread) builder;
  const _UnreadCount({required this.builder});

  @override
  State<_UnreadCount> createState() => _UnreadCountState();
}

class _UnreadCountState extends State<_UnreadCount> {
  /// Held in a field, not rebuilt inline. `.snapshots()` returns a new
  /// Stream each call and a StreamBuilder resubscribes when its stream
  /// identity changes, so an inline stream blanks itself on every parent
  /// rebuild — a tab switch, a filter tap, a setState.
  Stream<QuerySnapshot>? _chats;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _chats = FirebaseFirestore.instance
          .collection('user_chats')
          .doc(uid)
          .collection('chats')
          .where('unreadCount', isGreaterThan: 0)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chats == null) return widget.builder(0);

    return StreamBuilder<QuerySnapshot>(
      stream: _chats,
      builder: (context, snapshot) {
        var total = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            final raw = data?['unreadCount'];
            if (raw is int) total += raw;
          }
        }
        return widget.builder(total);
      },
    );
  }
}
