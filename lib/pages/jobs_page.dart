import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_theme.dart';
import '../widgets/gig_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/state_views.dart';
import '../agency/widgets/casting_card.dart';

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

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item.isGig) {
                      final data = item.data;
                      final roleReq = data['roleRequirements'] as Map<String, dynamic>? ?? {};
                      final physical = roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};

                      return _JobCardWrapper(
                        gigId: item.doc.id,
                        modelId: modelId,
                        brandName: data['brandName'] ?? '',
                        gigData: data,
                        physical: physical,
                      );
                    }

                    final data = item.data;
                    final applicants = data['applicationsCount'] ?? data['applicantsCount'] ?? 0;
                    final posterName = data['agencyName'] ?? data['agency'] ?? data['posterName'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('castings')
                          .doc(item.doc.id)
                          .collection('applicants')
                          .doc(modelId)
                          .get(),
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
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
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
