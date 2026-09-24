import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/gig_full_detail_page.dart';
import '../pages/casting_full_detail_page.dart';
import '../widgets/kit/app_status_badge.dart';

/// A posting someone has applied to, plus the live status of that
/// application.
///
/// Home and Notifications both need this, so it is assembled once.
class Application {
  final String id;
  final bool isGig;
  final Map<String, dynamic> data;
  final String title;
  final String subtitle;
  final String status;
  final DateTime? start;
  final DateTime? appliedAt;
  final String posterName;

  Application({
    required this.id,
    required this.isGig,
    required this.data,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.start,
    required this.appliedAt,
    required this.posterName,
  });

  /// True once a posting has moved past the initial application -- the
  /// thing worth telling someone about on Notifications.
  bool get hasMoved => AppStatus.parse(status).hasMoved;

  AppStatus get state => AppStatus.parse(status);

  /// Whether this belongs in the "needs your attention" slot.
  ///
  /// A booking whose shoot date has passed is finished work, not
  /// something up next -- leaving it at the top would make the card
  /// look stuck for weeks after the job was done.
  bool get isUpNext {
    if (!state.needsAttention) return false;
    if (state == AppStatus.booked && start != null) {
      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);
      if (start!.isBefore(midnight)) return false;
    }
    return true;
  }

  void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isGig
            ? GigFullDetailPage(gigId: id, data: data, brandName: posterName)
            : CastingFullDetailPage(
                castingId: id,
                data: data,
                posterName: posterName,
              ),
      ),
    );
  }
}

/// Collects a model's applications across open gigs and castings.
///
/// The security rules only permit reading `applications/{myUid}` (and
/// `applicants/{myUid}`) one document at a time — neither subcollection
/// grants `list` to a model, so a collection-group query is refused. This
/// therefore walks the publicly readable open postings and asks for its
/// own application under each, the same access pattern the Jobs feed
/// already uses. No new collection, field or index is involved.
class ApplicationFeed extends StatefulWidget {
  final String uid;
  final Widget Function(List<Application> applications, bool loading) builder;

  const ApplicationFeed({super.key, required this.uid, required this.builder});

  @override
  State<ApplicationFeed> createState() => _ApplicationFeedState();

  static Future<List<Application>> collect({
    required String uid,
    required List<QueryDocumentSnapshot> gigs,
    required List<QueryDocumentSnapshot> castings,
  }) async {
    final out = <Application>[];

    Future<void> addGig(QueryDocumentSnapshot doc) async {
      try {
        final app = await doc.reference
            .collection('applications')
            .doc(uid)
            .get();
        if (!app.exists) return;
        final data = doc.data() as Map<String, dynamic>;
        final appData = app.data() ?? {};
        out.add(
          Application(
            id: doc.id,
            isGig: true,
            data: data,
            title: (data['projectTitle'] ?? '').toString(),
            subtitle: (data['location'] ?? data['timeline'] ?? '').toString(),
            status: (appData['status'] ?? 'applied').toString(),
            start: asDate(data['shootingStart']) ?? asDate(data['createdAt']),
            appliedAt: asDate(appData['appliedAt']),
            posterName: (data['brandName'] ?? '').toString(),
          ),
        );
      } catch (_) {
        // A denied or missing application simply isn't on the board.
      }
    }

    Future<void> addCasting(QueryDocumentSnapshot doc) async {
      try {
        final app = await doc.reference.collection('applicants').doc(uid).get();
        if (!app.exists) return;
        final data = doc.data() as Map<String, dynamic>;
        final appData = app.data() ?? {};
        out.add(
          Application(
            id: doc.id,
            isGig: false,
            data: data,
            title: (data['title'] ?? data['projectTitle'] ?? '').toString(),
            subtitle: (data['location'] ?? '').toString(),
            status: (appData['status'] ?? 'applied').toString(),
            start: asDate(data['shootingStart']) ?? asDate(data['createdAt']),
            appliedAt: asDate(appData['appliedAt']),
            posterName:
                (data['agencyName'] ??
                        data['agency'] ??
                        data['posterName'] ??
                        '')
                    .toString(),
          ),
        );
      } catch (_) {}
    }

    await Future.wait([...gigs.map(addGig), ...castings.map(addCasting)]);

    out.sort((a, b) {
      final ad = a.start, bd = b.start;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return out;
  }

  static DateTime? asDate(dynamic v) => v is Timestamp ? v.toDate() : null;
}

class _ApplicationFeedState extends State<ApplicationFeed> {
  /// Created once. `.snapshots()` returns a new Stream on every call, and
  /// a StreamBuilder resubscribes — resetting to "no data" — whenever its
  /// stream identity changes. Built inline, the board emptied itself every
  /// time its parent rebuilt, which on Home is every collapse and expand.
  late final Stream<QuerySnapshot> _gigs = FirebaseFirestore.instance
      .collection('gigs')
      .where('status', isEqualTo: 'open')
      .snapshots();

  late final Stream<QuerySnapshot> _castings = FirebaseFirestore.instance
      .collection('castings')
      .where('status', isEqualTo: 'open')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _gigs,
      builder: (context, gigSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _castings,
          builder: (context, castSnap) {
            // Both have to settle before folding, or a slow query silently
            // drops half the board.
            final settled =
                (gigSnap.hasData || gigSnap.hasError) &&
                (castSnap.hasData || castSnap.hasError);
            if (!settled) {
              return widget.builder(const [], true);
            }

            return FutureBuilder<List<Application>>(
              future: ApplicationFeed.collect(
                uid: widget.uid,
                gigs: gigSnap.data?.docs ?? const [],
                castings: castSnap.data?.docs ?? const [],
              ),
              builder: (context, snap) => widget.builder(
                snap.data ?? const [],
                snap.connectionState == ConnectionState.waiting,
              ),
            );
          },
        );
      },
    );
  }
}

/// A timestamp in plain English.
///
/// Replaces the departure-board stamp, which rendered `2D`, `YEST` and
/// -- once a posting was old enough -- `193D`, a number nobody can read
/// as "about six months ago".
///
/// Future dates read forwards, because a shoot date is as often ahead
/// as behind.
String relativeTime(DateTime? when) {
  if (when == null) return '--';

  final diff = DateTime.now().difference(when);
  final ahead = diff.isNegative;

  // A date three days away is a few microseconds short of 72 hours by
  // the time this runs, so flooring it would report "in 2 days". The
  // cushion is exactly that measurement lag and cannot change a real
  // value. Past durations need no such help: something 25 hours ago is
  // "yesterday", which is what flooring already gives.
  final d = diff.abs() + (ahead ? const Duration(seconds: 1) : Duration.zero);

  String phrase(int value, String unit) {
    final plural = value == 1 ? unit : '${unit}s';
    return ahead ? 'in $value $plural' : '$value $plural ago';
  }

  if (d.inMinutes < 1) return ahead ? 'in a moment' : 'just now';
  if (d.inHours < 1) return phrase(d.inMinutes, 'minute');
  if (d.inDays < 1) return phrase(d.inHours, 'hour');
  if (d.inDays == 1) return ahead ? 'tomorrow' : 'yesterday';
  if (d.inDays < 7) return phrase(d.inDays, 'day');
  if (d.inDays < 30) return phrase(d.inDays ~/ 7, 'week');
  if (d.inDays < 365) return phrase(d.inDays ~/ 30, 'month');
  return phrase(d.inDays ~/ 365, 'year');
}
