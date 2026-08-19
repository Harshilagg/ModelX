import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_theme.dart';
import '../widgets/model_application_card.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

class BrandGigApplicationsPage extends StatelessWidget {
  final String gigId;
  final String gigTitle;

  const BrandGigApplicationsPage({
    super.key,
    required this.gigId,
    required this.gigTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(gigTitle),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gigs')
            .doc(gigId)
            .collection('applications')
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateView(message: 'Could not load applicants.');
          }

          if (!snapshot.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppSkeleton.card(height: 176),
              ),
            );
          }

          final apps = snapshot.data!.docs;

          if (apps.isEmpty) {
            return const EmptyState(
              icon: Icons.people_alt_outlined,
              title: 'No applications yet',
              message: 'Models who apply to this gig will show up here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final data = app.data() as Map<String, dynamic>;

              return ModelApplicationCard(
                gigId: gigId,
                modelId: data['modelId'],
                status: data['status'] ?? 'applied',
              );
            },
          );
        },
      ),
    );
  }
}
