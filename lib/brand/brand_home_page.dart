import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../agency/widgets/dashboard_card.dart';
import '../widgets/gig_card.dart';
import 'brand_gig_applications_page.dart';

class BrandHomePage extends StatelessWidget {
  const BrandHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WELCOME HEADER
            const Text(
              'Brand Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your gigs and discover talent',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                const Text(
                  'Active Gigs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
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
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Text(
                        'No active gigs. Post one to get started!',
                        style: TextStyle(color: Colors.grey[500]),
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