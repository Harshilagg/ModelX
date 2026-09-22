import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/gig_full_detail_page.dart';
import '../pages/casting_full_detail_page.dart';

/// One line on a model's board: a posting they have applied to, plus the
/// live status of that application.
///
/// Both Home (the board) and Notifications (board updates) need this, so
/// it lives here rather than being assembled twice.
class Departure {
  final String id;
  final bool isGig;
  final Map<String, dynamic> data;
  final String title;
  final String subtitle;
  final String status;
  final DateTime? start;
  final DateTime? appliedAt;
  final String posterName;

  Departure({
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

  /// True once a posting has moved past the model's initial application —
  /// the thing worth telling them about on Notifications.
  bool get hasMoved {
    final s = status.trim().toLowerCase();
    return s.isNotEmpty && s != 'applied' && s != 'pending';
  }

  String get timeLabel {
    if (start == null) return '--:--';
    final h = start!.hour.toString().padLeft(2, '0');
    final m = start!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isGig
            ? GigFullDetailPage(gigId: id, data: data, brandName: posterName)
            : CastingFullDetailPage(castingId: id, data: data, posterName: posterName),
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
class BoardDepartures extends StatefulWidget {
  final String uid;
  final Widget Function(List<Departure> departures, bool loading) builder;

  const BoardDepartures({super.key, required this.uid, required this.builder});

  @override
  State<BoardDepartures> createState() => _BoardDeparturesState();

  static Future<List<Departure>> collect({
    required String uid,
    required List<QueryDocumentSnapshot> gigs,
    required List<QueryDocumentSnapshot> castings,
  }) async {
    final out = <Departure>[];

    Future<void> addGig(QueryDocumentSnapshot doc) async {
      try {
        final app = await doc.reference.collection('applications').doc(uid).get();
        if (!app.exists) return;
        final data = doc.data() as Map<String, dynamic>;
        final appData = app.data() ?? {};
        out.add(Departure(
          id: doc.id,
          isGig: true,
          data: data,
          title: (data['projectTitle'] ?? '').toString(),
          subtitle: (data['location'] ?? data['timeline'] ?? '').toString(),
          status: (appData['status'] ?? 'applied').toString(),
          start: asDate(data['shootingStart']) ?? asDate(data['createdAt']),
          appliedAt: asDate(appData['appliedAt']),
          posterName: (data['brandName'] ?? '').toString(),
        ));
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
        out.add(Departure(
          id: doc.id,
          isGig: false,
          data: data,
          title: (data['title'] ?? data['projectTitle'] ?? '').toString(),
          subtitle: (data['location'] ?? '').toString(),
          status: (appData['status'] ?? 'applied').toString(),
          start: asDate(data['shootingStart']) ?? asDate(data['createdAt']),
          appliedAt: asDate(appData['appliedAt']),
          posterName:
              (data['agencyName'] ?? data['agency'] ?? data['posterName'] ?? '').toString(),
        ));
      } catch (_) {}
    }

    await Future.wait([
      ...gigs.map(addGig),
      ...castings.map(addCasting),
    ]);

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

class _BoardDeparturesState extends State<BoardDepartures> {
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
            final settled = (gigSnap.hasData || gigSnap.hasError) &&
                (castSnap.hasData || castSnap.hasError);
            if (!settled) {
              return widget.builder(const [], true);
            }

            return FutureBuilder<List<Departure>>(
              future: BoardDepartures.collect(
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


/// A compact relative stamp for board rows — `2D`, `4H`, `YEST`.
String boardAgo(DateTime? when) {
  if (when == null) return '--';
  final diff = DateTime.now().difference(when);
  if (diff.inDays >= 2) return '${diff.inDays}D';
  if (diff.inDays == 1) return 'YEST';
  if (diff.inHours > 0) return '${diff.inHours}H';
  if (diff.inMinutes > 0) return '${diff.inMinutes}M';
  return 'NOW';
}
