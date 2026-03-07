import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/gig_card.dart';
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
        final hasApplied = snapshot.data?.exists ?? false;

        return GigCard(
          showBrandHeader: true,
          brandName: brandName,
          actionWidget: _applyButton(
            hasApplied,
            () => _applyToGig(context),
          ),
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
    borderRadius: BorderRadius.circular(20),
    onTap: applied ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: applied
            ? Colors.grey.withOpacity(0.25)
            : Colors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        applied ? 'Applied' : 'Apply',
        style: TextStyle(
          color: applied ? Colors.grey : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}


  Future<void> _applyToGig(BuildContext context) async {
  final gigRef =
      FirebaseFirestore.instance.collection('gigs').doc(gigId);
  final appRef =
      gigRef.collection('applications').doc(modelId);

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Applied successfully')),
    );
  } catch (e) {
    debugPrint('🔥 Apply failed: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to apply. Try again.')),
    );
  }
}
}


class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final modelId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Jobs'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gigs')
            .where('status', isEqualTo: 'open')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final gigs = snapshot.data!.docs;

          // listen to castings and render both lists together
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('castings')
                .where('status', isEqualTo: 'open')
                .snapshots(),
            builder: (context, castingsSnap) {
              if (!castingsSnap.hasData) {
                if (gigs.isEmpty) {
                  return const Center(child: Text('No jobs available'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: gigs.length,
                  itemBuilder: (context, index) {
                    final doc = gigs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final roleReq =
                        data['roleRequirements'] as Map<String, dynamic>? ?? {};
                    final physical =
                        roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};

                    return _JobCardWrapper(
                      gigId: doc.id,
                      modelId: modelId,
                      brandName: data['brandName'] ?? '',
                      gigData: data,
                      physical: physical,
                    );
                  },
                );
              }

              final castings = castingsSnap.data!.docs;

              final total = gigs.length + castings.length;
              if (total == 0) {
                return const Center(child: Text('No jobs available'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: total,
                itemBuilder: (context, index) {
                  if (index < gigs.length) {
                    final doc = gigs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final roleReq =
                        data['roleRequirements'] as Map<String, dynamic>? ?? {};
                    final physical =
                        roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};

                    return _JobCardWrapper(
                      gigId: doc.id,
                      modelId: modelId,
                      brandName: data['brandName'] ?? '',
                      gigData: data,
                      physical: physical,
                    );
                  }

                  final castDoc = castings[index - gigs.length];
                  final data = castDoc.data() as Map<String, dynamic>;

                  final applicants = data['applicationsCount'] ?? data['applicantsCount'] ?? 0;
                  final posterName = data['agencyName'] ?? data['agency'] ?? data['posterName'] ?? '';
                  DateTime createdAt;
                  try {
                    createdAt = (data['createdAt'] as Timestamp).toDate();
                  } catch (_) {
                    createdAt = DateTime.now();
                  }

                  return FutureBuilder<bool>(
                    future: () async {
                      try {
                        final doc = await FirebaseFirestore.instance
                            .collection('castings')
                            .doc(castDoc.id)
                            .collection('applicants')
                            .doc(modelId)
                            .get();
                        return doc.exists;
                      } catch (e) {
                        // permission denied or other error — treat as not applied to avoid noisy logs
                        return false;
                      }
                    }(),
                    builder: (context, appSnap) {
                      final hasApplied = appSnap.data ?? false;
                      return CastingCard(
                        id: castDoc.id,
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
                        createdAt: createdAt,
                        compensationMin: data['compensationMin']?.toString(),
                        compensationMax: data['compensationMax']?.toString(),
                        shootingStart: (data['shootingStart'] is Timestamp) ? (data['shootingStart'] as Timestamp).toDate() : null,
                        shootingEnd: (data['shootingEnd'] is Timestamp) ? (data['shootingEnd'] as Timestamp).toDate() : null,
                        talentRequirements: (data['talentRequirements'] is Map) ? Map<String, dynamic>.from(data['talentRequirements'] as Map) : null,
                        showApply: !hasApplied,
                        actionWidget: hasApplied
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                child: const Text('Applied', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
                              )
                            : null,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
