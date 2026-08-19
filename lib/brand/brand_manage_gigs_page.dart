import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_theme.dart';
import '../widgets/gig_card.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';
import 'brand_gig_applications_page.dart';

class BrandManageGigsPage extends StatelessWidget {
  const BrandManageGigsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gigs')
            .where('brandId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorStateView(message: 'Could not load your gigs.');
          }

          if (!snapshot.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppSkeleton.card(),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.layers_outlined,
              title: 'No gigs posted yet',
              message: 'Gigs you post will show up here for you to manage.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;

              final roleReq =
                  data['roleRequirements'] as Map<String, dynamic>? ?? {};
              final physical =
                  roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BrandGigApplicationsPage(
                        gigId: d.id,
                        gigTitle: data['projectTitle'],
                      ),
                    ),
                  );
                },
                onLongPress: () => _confirmDelete(context, d.id),
                child: GigCard(
                  projectTitle: data['projectTitle'] ?? '',
                  description: data['description'] ?? '',

                  physicalAttributes: physical,
                  eyeColors: List<String>.from(physical['eyeColor'] ?? const []),
                  hairColors: List<String>.from(physical['hairColor'] ?? const []),
                  skinComplexion:
                      List<String>.from(physical['skinComplexion'] ?? const []),

                  timeline: data['timeline'] ?? '',
                  durationHours: data['durationHours'] ?? 0,
                  budgetType: data['budgetType'] ?? '',
                  budgetAmount: data['budgetAmount'] ?? '',

                  applications: data['applicationsCount'] ?? 0,
                  status: data['status'] ?? 'open',
                  createdAt: (data['createdAt'] as Timestamp).toDate(),
                ),
              );

            },
          );
        },
      ),
    );
  }
  Future<void> _confirmDelete(BuildContext context, String gigId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text('Delete Gig', style: AppTypography.subheading),
      content: Text(
        'Are you sure you want to delete this gig? '
        'This action cannot be undone.',
        style: AppTypography.body.copyWith(color: AppColors.inkSoft),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.select,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await FirebaseFirestore.instance
        .collection('gigs')
        .doc(gigId)
        .delete();

    if (context.mounted) {
      showAppToast(context, 'Gig deleted');
    }
  }
}

}
