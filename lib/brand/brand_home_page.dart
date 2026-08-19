import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_theme.dart';
import '../agency/widgets/dashboard_card.dart';
import '../widgets/gig_card.dart';
import '../widgets/app_skeleton.dart';
import 'brand_gig_applications_page.dart';

class BrandHomePage extends StatelessWidget {
  const BrandHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WELCOME HEADER
            Text('Brand Dashboard', style: AppTypography.heading),
            const SizedBox(height: 4),
            Text(
              'Manage your gigs and discover talent',
              style: AppTypography.body.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),

            // STATS GRID
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('gigs')
                  .where('brandId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, gigSnapshot) {
                final gigsCount = gigSnapshot.data?.docs.length ?? 0;
                
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('applications')
                      .where('brandId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, appSnapshot) {
                    final appsCount = appSnapshot.data?.docs.length ?? 0;

                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      children: [
                        DashboardCard(
                          title: 'Total Gigs',
                          value: gigsCount.toString(),
                          icon: Icons.layers_outlined,
                        ),
                        DashboardCard(
                          title: 'Applicants',
                          value: appsCount.toString(),
                          icon: Icons.people_outline,
                        ),
                        const DashboardCard(
                          title: 'Active Castings',
                          value: '2', // Mock for now or fetch active
                          icon: Icons.bolt_outlined,
                        ),
                        const DashboardCard(
                          title: 'Messages',
                          value: '5', // Mock or fetch unread
                          icon: Icons.chat_bubble_outline,
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 32),

            // ACTIVE GIGS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active Gigs', style: AppTypography.subheading),
                TextButton(
                  onPressed: () {
                    // Navigate to Manage Gigs tab would be better, but we are inside the tab
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('gigs')
                  .where('brandId', isEqualTo: uid)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    height: 100,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text('Could not load your gigs.', style: AppTypography.caption),
                  );
                }

                if (!snapshot.hasData) {
                  return Column(
                    children: List.generate(
                      2,
                      (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppSkeleton.card(height: 120),
                      ),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Center(
                      child: Text(
                        'No active gigs. Post one to get started!',
                        style: AppTypography.caption,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data() as Map<String, dynamic>;
                    final roleReq = data['roleRequirements'] as Map<String, dynamic>? ?? {};
                    final physical = roleReq['physicalAttributes'] as Map<String, dynamic>? ?? {};

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
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
                        child: GigCard(
                          projectTitle: data['projectTitle'] ?? '',
                          description: data['description'] ?? '',
                          physicalAttributes: physical,
                          eyeColors: List<String>.from(physical['eyeColor'] ?? const []),
                          hairColors: List<String>.from(physical['hairColor'] ?? const []),
                          skinComplexion: List<String>.from(physical['skinComplexion'] ?? const []),
                          timeline: data['timeline'] ?? '',
                          durationHours: data['durationHours'] ?? 0,
                          budgetType: data['budgetType'] ?? '',
                          budgetAmount: data['budgetAmount'] ?? '',
                          applications: data['applicationsCount'] ?? 0,
                          status: data['status'] ?? 'open',
                          createdAt: (data['createdAt'] as Timestamp).toDate(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}