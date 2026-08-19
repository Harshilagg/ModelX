import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_theme.dart';
import '../widgets/gig_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/state_views.dart';
import '../widgets/app_grid_layout.dart';
import '../agency/widgets/casting_card.dart';
import 'gig_full_detail_page.dart';
import 'casting_full_detail_page.dart';

class _JobCardWrapper extends StatelessWidget {
  final String gigId;
  final String modelId;
  final String brandName;
  final Map<String, dynamic> gigData;
  final Map<String, dynamic> physical;

  const _JobCardWrapper({
    required this.gigId,
    required this.modelId,
    required this.brandName,
    required this.gigData,
    required this.physical,
  });

  @override
  Widget build(BuildContext context) {
    final appRef = FirebaseFirestore.instance
        .collection('gigs')
        .doc(gigId)
        .collection('applications')
        .doc(modelId);

    return StreamBuilder<DocumentSnapshot>(
      stream: appRef.snapshots(),
      builder: (context, snapshot) {
        final appDoc = snapshot.data;
        final hasApplied = appDoc?.exists ?? false;

        String appStatus = 'Apply';
        if (hasApplied) {
          final appData = appDoc?.data() as Map<String, dynamic>?;
          appStatus = appData?['status'] ?? 'Applied';
        }

        return GigCard(
          showBrandHeader: true,
          brandName: brandName,
          actionWidget: hasApplied ? StatusPill(status: appStatus) : _applyButton(hasApplied, () => _applyToGig(context)),
          projectTitle: gigData['projectTitle'],
          description: gigData['description'],
          physicalAttributes: physical,
          eyeColors: List<String>.from(physical['eyeColor'] ?? []),
          hairColors: List<String>.from(physical['hairColor'] ?? []),
          skinComplexion: List<String>.from(physical['skinComplexion'] ?? []),
          timeline: gigData['timeline'],
          durationHours: gigData['durationHours'],
          budgetType: gigData['budgetType'],
          budgetAmount: gigData['budgetAmount'],
          applications: gigData['applicationsCount'] ?? 0,
          status: gigData['status'],
          createdAt: (gigData['createdAt'] as Timestamp).toDate(),
        );
      },
    );
  }

  Widget _applyButton(bool applied, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: applied ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: applied ? AppColors.paperRaised : AppColors.ink,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          applied ? 'Applied' : 'Apply',
          style: TextStyle(
            color: applied ? AppColors.inkFaint : AppColors.paper,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _applyToGig(BuildContext context) async {
    final gigRef = FirebaseFirestore.instance.collection('gigs').doc(gigId);
    final appRef = gigRef.collection('applications').doc(modelId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final appSnap = await tx.get(appRef);

        // ⛔ Already applied → do nothing
        if (appSnap.exists) {
          return;
        }

        // ✅ First-time apply
        tx.set(appRef, {
          'modelId': modelId,
          'gigId': gigId,
          'brandName': brandName,
          'projectTitle': gigData['projectTitle'],
          'status': 'applied',
          'appliedAt': FieldValue.serverTimestamp(),
        });

        tx.update(gigRef, {
          'applicationsCount': FieldValue.increment(1),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied successfully')),
      );
    } catch (e) {
      debugPrint('🔥 Apply failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to apply. Try again.')),
      );
    }
  }
}

/// A compact mosaic-tile rendering of a gig, used for every item in the
/// feed except the featured one — `GigCard` is too tall/detailed (chips,
/// full description, meta row) to fit a grid cell, so this shows the same
/// core facts (title, brand, live application status) at a smaller size
/// instead of dropping them. Reuses the exact same applications stream
/// `_JobCardWrapper` uses, so status tracking is identical.
class _GigTile extends StatelessWidget {
  final String gigId;
  final String modelId;
  final String brandName;
  final Map<String, dynamic> gigData;
  final int recipe;

  const _GigTile({
    required this.gigId,
    required this.modelId,
    required this.brandName,
    required this.gigData,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    final appRef = FirebaseFirestore.instance.collection('gigs').doc(gigId).collection('applications').doc(modelId);

    return StreamBuilder<DocumentSnapshot>(
      stream: appRef.snapshots(),
      builder: (context, snapshot) {
        final appDoc = snapshot.data;
        final hasApplied = appDoc?.exists ?? false;
        String? appStatus;
        if (hasApplied) {
          final appData = appDoc?.data() as Map<String, dynamic>?;
          appStatus = appData?['status'] ?? 'Applied';
        }
        return _MosaicTile(
          title: gigData['projectTitle'] ?? '',
          subtitle: brandName,
          statusLabel: appStatus,
          recipe: recipe,
        );
      },
    );
  }
}

/// The casting equivalent of [_GigTile] — same idea, wraps the applicants
/// lookup `CastingCard` already uses.
class _CastingTile extends StatelessWidget {
  final String castingId;
  final String modelId;
  final String posterName;
  final Map<String, dynamic> data;
  final int recipe;

  const _CastingTile({
    required this.castingId,
    required this.modelId,
    required this.posterName,
    required this.data,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('castings').doc(castingId).collection('applicants').doc(modelId).get(),
      builder: (context, appSnap) {
        final appDoc = appSnap.data;
        final hasApplied = appDoc?.exists ?? false;
        String? appStatus;
        if (hasApplied) {
          final appData = appDoc?.data() as Map<String, dynamic>?;
          appStatus = appData?['status'] ?? 'Applied';
        }
        return _MosaicTile(
          title: data['title'] ?? data['projectTitle'] ?? '',
          subtitle: posterName,
          statusLabel: appStatus,
          recipe: recipe,
        );
      },
    );
  }
}

/// The shared compact-tile look — a duotone gradient panel (standing in
/// for imagery, since gigs/castings don't carry photos) with title/poster
/// bottom-anchored, matching the mosaic treatment already approved for
/// this screen's featured-item-plus-grid direction.
class _MosaicTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? statusLabel;
  final int recipe;

  const _MosaicTile({required this.title, required this.subtitle, required this.statusLabel, required this.recipe});

  static const _gradients = [
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF17150F), Color(0xFFB08A4C)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB08A4C), Color(0xFF17150F)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A3A34), Color(0xFF0A0A0A)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A0A0A), Color(0xFFC6273A)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: _gradients[recipe % _gradients.length],
      ),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.onBackstage, fontSize: 13, fontWeight: FontWeight.w700, height: 1.15),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.onBackstageSoft, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          if (statusLabel != null)
            Positioned(top: 0, right: 0, child: StatusPill(status: statusLabel!)),
        ],
      ),
    );
  }
}

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  // Bumping this key forces the StreamBuilders below to re-subscribe,
  // giving pull-to-refresh a visible effect even though the underlying
  // data is already live-streamed.
  int _refreshTick = 0;

  Future<void> _handleRefresh() async {
    setState(() => _refreshTick++);
    // Give the new subscriptions a brief beat to receive their first
    // snapshot so the refresh indicator doesn't vanish instantly.
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final modelId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Jobs')),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.ink,
        child: StreamBuilder<QuerySnapshot>(
          key: ValueKey('gigs_$_refreshTick'),
          stream: FirebaseFirestore.instance
              .collection('gigs')
              .where('status', isEqualTo: 'open')
              .snapshots(),
          builder: (context, gigSnap) {
            if (gigSnap.hasError) {
              return _errorList(() => setState(() => _refreshTick++));
            }
            if (!gigSnap.hasData) {
              return const LoadingState();
            }

            final gigs = gigSnap.data!.docs;

            return StreamBuilder<QuerySnapshot>(
              key: ValueKey('castings_$_refreshTick'),
              stream: FirebaseFirestore.instance
                  .collection('castings')
                  .where('status', isEqualTo: 'open')
                  .snapshots(),
              builder: (context, castingsSnap) {
                if (castingsSnap.hasError) {
                  return _errorList(() => setState(() => _refreshTick++));
                }
                if (!castingsSnap.hasData) {
                  return const LoadingState();
                }

                final castings = castingsSnap.data!.docs;

                // Merge both collections into a single feed sorted by
                // createdAt descending, newest first regardless of source.
                final items = <_FeedItem>[
                  ...gigs.map((d) => _FeedItem.gig(d, (d.data() as Map<String, dynamic>))),
                  ...castings.map((d) => _FeedItem.casting(d, (d.data() as Map<String, dynamic>))),
                ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (items.isEmpty) {
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const EmptyState(
                          icon: Icons.work_outline_rounded,
                          title: 'No jobs available',
                          message: 'New gigs and castings will show up here as soon as they go live.',
                        ),
                      ),
                    ),
                  );
                }

                final featuredItem = items.first;
                final restItems = items.skip(1).toList();

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppFeaturedGrid(
                    featured: _buildFullCard(context, featuredItem, modelId),
                    tiles: [
                      for (var i = 0; i < restItems.length; i++)
                        _buildTile(restItems[i], modelId, i),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullCard(BuildContext context, _FeedItem item, String modelId) {
    if (item.isGig) {
      final data = item.data;
      final roleReq = data['roleRequirements'] as Map<String, dynamic>? ?? {};
      final physical = roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};
      final brandName = data['brandName'] ?? '';

      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GigFullDetailPage(gigId: item.doc.id, data: data, brandName: brandName)),
        ),
        child: _JobCardWrapper(
          gigId: item.doc.id,
          modelId: modelId,
          brandName: brandName,
          gigData: data,
          physical: physical,
        ),
      );
    }

    final data = item.data;
    final applicants = data['applicationsCount'] ?? data['applicantsCount'] ?? 0;
    final posterName = data['agencyName'] ?? data['agency'] ?? data['posterName'] ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('castings').doc(item.doc.id).collection('applicants').doc(modelId).get(),
      builder: (context, appSnap) {
        final appDoc = appSnap.data;
        final hasApplied = appDoc?.exists ?? false;

        String appStatus = 'Apply';
        if (hasApplied) {
          final appData = appDoc?.data() as Map<String, dynamic>?;
          appStatus = appData?['status'] ?? 'Applied';
        }

        return CastingCard(
          id: item.doc.id,
          title: data['title'] ?? data['projectTitle'] ?? '',
          description: data['description'] ?? '',
          posterName: posterName,
          location: data['location'] ?? '',
          timeline: data['timeline'] ?? '',
          budgetType: data['budgetType'] ?? '',
          budgetAmount: data['budgetAmount']?.toString() ?? '',
          media: List<String>.from(data['media'] ?? []),
          applicants: applicants,
          status: data['status'] ?? 'open',
          createdAt: item.createdAt,
          compensationMin: data['compensationMin']?.toString(),
          compensationMax: data['compensationMax']?.toString(),
          shootingStart: (data['shootingStart'] is Timestamp) ? (data['shootingStart'] as Timestamp).toDate() : null,
          shootingEnd: (data['shootingEnd'] is Timestamp) ? (data['shootingEnd'] as Timestamp).toDate() : null,
          talentRequirements: (data['talentRequirements'] is Map) ? Map<String, dynamic>.from(data['talentRequirements'] as Map) : null,
          showApply: !hasApplied,
          actionWidget: hasApplied ? StatusPill(status: appStatus) : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CastingFullDetailPage(castingId: item.doc.id, data: data, posterName: posterName)),
          ),
        );
      },
    );
  }

  Widget _buildTile(_FeedItem item, String modelId, int index) {
    if (item.isGig) {
      final data = item.data;
      final brandName = data['brandName'] ?? '';
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GigFullDetailPage(gigId: item.doc.id, data: data, brandName: brandName)),
        ),
        child: _GigTile(
          gigId: item.doc.id,
          modelId: modelId,
          brandName: brandName,
          gigData: data,
          recipe: index,
        ),
      );
    }
    final data = item.data;
    final posterName = data['agencyName'] ?? data['agency'] ?? data['posterName'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CastingFullDetailPage(castingId: item.doc.id, data: data, posterName: posterName)),
      ),
      child: _CastingTile(
        castingId: item.doc.id,
        modelId: modelId,
        posterName: posterName,
        data: data,
        recipe: index,
      ),
    );
  }

  Widget _errorList(VoidCallback onRetry) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ErrorStateView(
            message: 'Could not load jobs. Pull down or try again.',
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}

/// A small internal wrapper that lets the merged feed sort gigs and
/// castings together by `createdAt` without changing either collection's
/// document shape.
class _FeedItem {
  final bool isGig;
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  _FeedItem._(this.isGig, this.doc, this.data, this.createdAt);

  factory _FeedItem.gig(QueryDocumentSnapshot doc, Map<String, dynamic> data) {
    DateTime createdAt;
    try {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } catch (_) {
      createdAt = DateTime.now();
    }
    return _FeedItem._(true, doc, data, createdAt);
  }

  factory _FeedItem.casting(QueryDocumentSnapshot doc, Map<String, dynamic> data) {
    DateTime createdAt;
    try {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } catch (_) {
      createdAt = DateTime.now();
    }
    return _FeedItem._(false, doc, data, createdAt);
  }
}
