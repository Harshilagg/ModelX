import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/board_theme.dart';
import '../widgets/board_widgets.dart';
import '../widgets/state_views.dart';
import 'gig_full_detail_page.dart';
import 'casting_full_detail_page.dart';

/// Jobs — filter chips, a shooting-soon rail, and expanding rows
/// (style board 3a), on the same floating pill bar as every other
/// board screen.
///
/// Gigs (brand-posted) and castings (agency-posted) are equalised into
/// one feed: a model doesn't care which collection a call came out of,
/// only when it shoots and whether they're in. Each row carries the
/// model's own application status, read one document at a time because
/// the rules don't grant `list` over applications.
class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

enum _JobFilter { all, open, applied, shortlisted }

class _JobsPageState extends State<JobsPage> {
  _JobFilter _filter = _JobFilter.all;
  String? _expandedId;

  // Bumping this key forces the StreamBuilders below to re-subscribe,
  // giving pull-to-refresh a visible effect even though the underlying
  // data is already live-streamed.
  int _refreshTick = 0;

  /// Held in fields so a filter tap or a card opening doesn't recreate
  /// them. `.snapshots()` returns a new Stream each call, and a
  /// StreamBuilder resubscribes whenever its stream identity changes — so
  /// building them inline reset the whole feed on every interaction.
  /// Re-assigned only on pull-to-refresh, which is when a resubscribe is
  /// the point.
  late Stream<QuerySnapshot> _gigs;
  late Stream<QuerySnapshot> _castings;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _gigs = FirebaseFirestore.instance
        .collection('gigs')
        .where('status', isEqualTo: 'open')
        .snapshots();
    _castings = FirebaseFirestore.instance
        .collection('castings')
        .where('status', isEqualTo: 'open')
        .snapshots();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshTick++;
      _subscribe();
    });
    // Give the new subscriptions a brief beat to receive their first
    // snapshot so the refresh indicator doesn't vanish instantly.
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final modelId = FirebaseAuth.instance.currentUser?.uid;
    if (modelId == null) {
      return const EmptyState(icon: Icons.work_outline_rounded, title: 'Not signed in');
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: BoardColors.ink,
      backgroundColor: BoardColors.paper,
      child: StreamBuilder<QuerySnapshot>(
        key: ValueKey('gigs_$_refreshTick'),
        stream: _gigs,
        builder: (context, gigSnap) {
          if (gigSnap.hasError) return _errorList();

          return StreamBuilder<QuerySnapshot>(
            key: ValueKey('castings_$_refreshTick'),
            stream: _castings,
            builder: (context, castingsSnap) {
              if (castingsSnap.hasError) return _errorList();
              if (!gigSnap.hasData || !castingsSnap.hasData) {
                return const LoadingState();
              }

              // Merge both collections into one feed, newest first,
              // regardless of source.
              final items = <_FeedItem>[
                ...gigSnap.data!.docs.map((d) => _FeedItem.gig(d, d.data() as Map<String, dynamic>)),
                ...castingsSnap.data!.docs
                    .map((d) => _FeedItem.casting(d, d.data() as Map<String, dynamic>)),
              ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return _JobsBody(
                items: items,
                modelId: modelId,
                filter: _filter,
                expandedId: _expandedId,
                onFilter: (f) => setState(() => _filter = f),
                onExpand: (id) => setState(() => _expandedId = _expandedId == id ? null : id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _errorList() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ErrorStateView(
            message: 'Could not load jobs. Pull down or try again.',
            onRetry: () => setState(() => _refreshTick++),
          ),
        ),
      ),
    );
  }
}

/// Resolves each posting's application status, then lays out the screen.
///
/// Statuses are resolved once here rather than inside each card so the
/// filter chips can actually filter on them — a card that streams its own
/// status can't tell the list above it what it found.
class _JobsBody extends StatelessWidget {
  final List<_FeedItem> items;
  final String modelId;
  final _JobFilter filter;
  final String? expandedId;
  final ValueChanged<_JobFilter> onFilter;
  final ValueChanged<String> onExpand;

  const _JobsBody({
    required this.items,
    required this.modelId,
    required this.filter,
    required this.expandedId,
    required this.onFilter,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _statuses(),
      builder: (context, snap) {
        final statuses = snap.data ?? const <String, String>{};

        final filtered = items.where((it) {
          final status = statuses[it.doc.id];
          switch (filter) {
            case _JobFilter.all:
              return true;
            case _JobFilter.open:
              return status == null;
            case _JobFilter.applied:
              return status != null;
            case _JobFilter.shortlisted:
              final s = status?.toLowerCase() ?? '';
              return s.isNotEmpty && s != 'applied' && s != 'pending';
          }
        }).toList();

        // The rail shows what shoots soonest, which is the only deadline
        // the data actually carries — there is no "applications close"
        // field on either collection.
        final soon = items
            .where((it) => it.shootingStart != null && it.shootingStart!.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.shootingStart!.compareTo(b.shootingStart!));

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              key: const ValueKey('title'),
              child: BoardScreenTitle(
                title: 'Jobs',
                meta: '${items.length} POSTING${items.length == 1 ? '' : 'S'}',
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              ),
            ),
            SliverToBoxAdapter(key: const ValueKey('chips'), child: _chips()),
            if (soon.isNotEmpty)
              SliverToBoxAdapter(key: const ValueKey('rail'), child: _rail(context, soon)),
            if (filtered.isEmpty)
              const SliverToBoxAdapter(
                key: ValueKey('empty'),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: EmptyState(
                    icon: Icons.work_outline_rounded,
                    title: 'Nothing here',
                    message: 'New gigs and castings show up as soon as they go live.',
                  ),
                ),
              )
            else
              SliverPadding(
                key: const ValueKey('list'),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return _JobRow(
                      item: item,
                      status: statuses[item.doc.id],
                      selected: expandedId == item.doc.id,
                      onToggle: () => onExpand(item.doc.id),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  /// Reads this model's own application under each posting. Denied or
  /// absent documents simply mean "not applied".
  Future<Map<String, String>> _statuses() async {
    final out = <String, String>{};
    await Future.wait(items.map((it) async {
      try {
        final ref = it.isGig
            ? it.doc.reference.collection('applications').doc(modelId)
            : it.doc.reference.collection('applicants').doc(modelId);
        final snap = await ref.get();
        if (snap.exists) {
          out[it.doc.id] = (snap.data()?['status'] ?? 'applied').toString();
        }
      } catch (_) {}
    }));
    return out;
  }

  Widget _chips() {
    const labels = {
      _JobFilter.all: 'ALL',
      _JobFilter.open: 'OPEN',
      _JobFilter.applied: 'APPLIED',
      _JobFilter.shortlisted: 'SHORTLISTED',
    };

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final entry in labels.entries) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onFilter(entry.key),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: filter == entry.key ? BoardColors.brass : BoardColors.shell,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: BoardType.mono(
                      fontSize: 10,
                      color: filter == entry.key ? BoardColors.ink : BoardColors.inkSoft,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rail(BuildContext context, List<_FeedItem> soon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: BoardSectionLabel('Shooting soon — swipe'),
          ),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const PageScrollPhysics(),
              itemCount: soon.length.clamp(0, 8),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final it = soon[i];
                final days = it.shootingStart!.difference(DateTime.now()).inDays;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => it.open(context),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: BoardColors.slate,
                      borderRadius: BorderRadius.circular(BoardRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          days <= 0 ? 'SHOOTS TODAY' : 'SHOOTS IN ${days}D',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.mono(
                            fontSize: 9.5,
                            // On slate, brass has to be the tint.
                            color: BoardColors.brassText,
                            letterSpacing: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            it.title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.title(
                              fontSize: 16,
                              color: BoardColors.onInk,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          it.moneyLine.isEmpty ? it.posterName.toUpperCase() : it.moneyLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: BoardColors.onInk.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One posting. Collapsed it shows the facts a model scans for; tapping
/// it opens the description and the single action for its state.
class _JobRow extends StatelessWidget {
  final _FeedItem item;
  final String? status;

  /// The card the model has open. Being open and being the dark card are
  /// the same state: the posting you are reading is the one the screen
  /// should be about.
  final bool selected;

  final VoidCallback onToggle;

  const _JobRow({
    required this.item,
    required this.status,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // The open card takes ink; every other posting stays slate. Anchoring
    // the dark surface to what the model tapped — rather than to
    // whichever posting happened to be newest — means the emphasis
    // follows their attention instead of fighting it.
    //
    // Money is the only coloured word on either surface, and on slate it
    // has to drop to the brass tint: at full strength the two share a
    // lightness band and the figure sinks into the panel.
    final bg = selected ? BoardColors.ink : BoardColors.slate;
    final fg = BoardColors.onInk;
    final line = BoardColors.onInkLine;
    final meta = BoardColors.onInkSoft;
    final money = selected ? BoardColors.brass : BoardColors.brassText;

    final initial = item.posterName.isNotEmpty ? item.posterName[0].toUpperCase() : '·';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        // Animated so the surface crossfades slate to ink alongside the
        // card opening, rather than snapping a beat before it.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(BoardRadius.panel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- poster + status ----
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BoardColors.brass,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      initial,
                      style: BoardType.mono(fontSize: 10, color: BoardColors.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.posterName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BoardType.mono(fontSize: 10.5, color: fg, letterSpacing: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FlapTile.status(status ?? 'open'),
                ],
              ),
              const SizedBox(height: 10),

              // ---- title ----
              Text(
                item.title.toUpperCase(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: BoardType.display(fontSize: 26, color: fg, height: 0.93),
              ),
              const SizedBox(height: 10),

              // ---- money · location ----
              Container(
                padding: const EdgeInsets.only(top: 9),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: line))),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        style: BoardType.mono(fontSize: 10.5, color: money),
                        child: Text(
                          item.moneyLine.isEmpty ? '—' : item.moneyLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          item.location.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: BoardType.mono(fontSize: 10.5, color: fg),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ---- requirement chips ----
              if (item.chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final c in item.chips.take(4)) MonoChip(c, neutral: true),
                  ],
                ),
              ],

              // ---- expanded body ----
              if (selected) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: line))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.description.isNotEmpty) ...[
                        Text(
                          item.description,
                          style: BoardType.body(fontSize: 12.5, color: fg.withValues(alpha: 0.88)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.applicationLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: BoardType.mono(fontSize: 9, color: meta, letterSpacing: 0.6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => item.open(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                              decoration: BoxDecoration(
                                color: BoardColors.brass,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status == null ? 'APPLY' : 'VIEW',
                                style: BoardType.title(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.35,
                                  color: BoardColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.applicationLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BoardType.mono(fontSize: 9, color: meta, letterSpacing: 0.6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: BoardColors.brass,
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: BoardColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small internal wrapper that lets the merged feed sort gigs and
/// castings together without changing either collection's document
/// shape, and exposes the handful of facts a row renders.
class _FeedItem {
  final bool isGig;
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  _FeedItem._(this.isGig, this.doc, this.data, this.createdAt);

  factory _FeedItem.gig(QueryDocumentSnapshot doc, Map<String, dynamic> data) =>
      _FeedItem._(true, doc, data, _date(data['createdAt']) ?? DateTime.now());

  factory _FeedItem.casting(QueryDocumentSnapshot doc, Map<String, dynamic> data) =>
      _FeedItem._(false, doc, data, _date(data['createdAt']) ?? DateTime.now());

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  String get title =>
      (isGig ? data['projectTitle'] : (data['title'] ?? data['projectTitle']) ?? '').toString();

  String get posterName => (isGig
          ? data['brandName']
          : (data['agencyName'] ?? data['agency'] ?? data['posterName']) ?? '')
      .toString();

  String get description => (data['description'] ?? '').toString();

  /// Castings store `location`; gigs store `city` and a `jobLocations`
  /// list. Reading only the first left every brand-posted row with a
  /// blank city.
  String get location {
    for (final key in ['location', 'city']) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    final locations = data['jobLocations'];
    if (locations is List && locations.isNotEmpty) {
      return locations.first.toString().trim();
    }
    return '';
  }

  DateTime? get shootingStart => _date(data['shootingStart']);

  /// The compensation line, assembled from whichever of the two
  /// collections' money fields are present.
  String get moneyLine {
    final min = (data['compensationMin'] ?? '').toString();
    final max = (data['compensationMax'] ?? '').toString();
    if (min.isNotEmpty || max.isNotEmpty) {
      return '₹${min.isEmpty ? '—' : min} – ₹${max.isEmpty ? '—' : max}';
    }
    final type = (data['budgetType'] ?? '').toString();
    final amount = (data['budgetAmount'] ?? '').toString();
    if (amount.isNotEmpty) {
      return type.isEmpty ? '₹$amount' : '${type.toUpperCase()} · ₹$amount';
    }
    final hours = (data['durationHours'] ?? '').toString();
    if (hours.isNotEmpty) return '$hours HRS';
    return '';
  }

  /// The requirement chips shown on a collapsed row, drawn only from
  /// fields the two collections actually carry.
  List<String> get chips {
    final out = <String>[];

    if (isGig) {
      final role = data['roleRequirements'] as Map<String, dynamic>? ?? {};
      final physical = role['physicalAttributes'] as Map<String, dynamic>? ?? {};
      for (final key in ['eyeColor', 'hairColor', 'skinComplexion']) {
        final v = physical[key];
        if (v is List && v.isNotEmpty) out.add(v.first.toString());
      }
      final timeline = (data['timeline'] ?? '').toString();
      if (timeline.isNotEmpty) out.add(timeline);
    } else {
      final talent = data['talentRequirements'];
      if (talent is Map) {
        final t = Map<String, dynamic>.from(talent);
        final minAge = t['minAge'], maxAge = t['maxAge'];
        if (minAge != null || maxAge != null) out.add('${minAge ?? '—'}–${maxAge ?? '—'}');
        final looks = t['looks'];
        if (looks is List && looks.isNotEmpty) out.add(looks.first.toString());
        if (looks is String && looks.isNotEmpty) out.add(looks);
        final skills = t['skills'];
        if (skills is List && skills.isNotEmpty) out.add(skills.first.toString());
      }
      final outfit = (data['outfitRequirements'] ?? '').toString();
      if (outfit.isNotEmpty) out.add(outfit);
    }

    return out.where((s) => s.trim().isNotEmpty).toList();
  }

  String get applicationLine {
    final count = data['applicationsCount'] ?? data['applicantsCount'] ?? 0;
    final diff = DateTime.now().difference(createdAt);
    final ago = diff.inDays > 0 ? '${diff.inDays}D AGO' : '${diff.inHours}H AGO';
    return '$count APPLICATION${count == 1 ? '' : 'S'} · $ago';
  }

  void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isGig
            ? GigFullDetailPage(gigId: doc.id, data: data, brandName: posterName)
            : CastingFullDetailPage(castingId: doc.id, data: data, posterName: posterName),
      ),
    );
  }
}
