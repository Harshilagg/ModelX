import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/header.dart';
import 'widgets/dashboard_card.dart';
import 'roster/model_roster_page.dart';
import 'roster/model_detail_page.dart';
import 'scouting/scout_page.dart';
import 'casting/casting_list_page.dart';
import 'casting/casting_detail_page.dart';
import 'announcements/announcements_page.dart';
import 'team_access/team_access_page.dart';
import '../widgets/model_x_copilot.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/status_pill.dart';
import '../widgets/state_views.dart';
import '../ui/app_theme.dart';

import '../pages/home_page.dart';

class AgencyDashboardPage extends StatefulWidget {
  const AgencyDashboardPage({super.key});

  @override
  State<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends State<AgencyDashboardPage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const HomePage(), 
    const _HomeView(), 
    const ModelRosterPage(),
    const ScoutPage(standalone: false),
    const CastingListPage(),
    const TeamAccessPage(), // Removed Announcements from main nav to keep it clean (moved to Insights)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(preferredSize: Size.fromHeight(72), child: AgencyHeader()),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: AppColors.paper, boxShadow: AppShadows.raised),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            iconSize: AppIconSize.md,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.rss_feed_rounded), label: 'Feed'),
              BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Insights'),
              BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Models'),
              BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Scout'),
              BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Castings'),
              BottomNavigationBarItem(icon: Icon(Icons.group_add_outlined), label: 'Team'),
            ],
          ),
        ),
      ),
      floatingActionButton: ModelXCopilot(
        pageContext: {
          'page': _selectedIndex == 3 ? 'scout' : 'home',
          'role': 'Agency',
          'tab': ['Feed', 'Insights', 'Models', 'Scout', 'Castings', 'Team'][_selectedIndex],
        },
        onResults: (results) {
          if (_selectedIndex == 3) {
            ScoutPage.onAiResultsExternal?.call(results);
          }
        },
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final modelsStream = FirebaseFirestore.instance
        .collection('models')
        .where('agencyId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    final castingsStream = FirebaseFirestore.instance
        .collection('castings')
        .where('agencyId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Overview', style: AppTypography.heading),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: modelsStream,
          builder: (context, modelsSnap) {
            final models = modelsSnap.data?.docs ?? [];
            return StreamBuilder<QuerySnapshot>(
              stream: castingsStream,
              builder: (context, castingsSnap) {
                final castings = castingsSnap.data?.docs ?? [];
                final activeCastings = castings.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'open').length;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('user_chats')
                      .doc(uid)
                      .collection('chats')
                      .where('unreadCount', isGreaterThan: 0)
                      .snapshots(),
                  builder: (context, chatsSnap) {
                    int unreadTotal = 0;
                    for (final doc in chatsSnap.data?.docs ?? []) {
                      unreadTotal += (doc['unreadCount'] ?? 0) as int;
                    }

                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          DashboardCard(title: 'Total Models', value: models.length.toString(), icon: Icons.person),
                          DashboardCard(title: 'Active Castings', value: activeCastings.toString(), icon: Icons.work),
                          DashboardCard(title: 'New Messages', value: unreadTotal.toString(), icon: Icons.mail),
                          DashboardCard(title: 'Total Castings', value: castings.length.toString(), icon: Icons.history),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Recent Models', style: AppTypography.subheading),
                      const SizedBox(height: 12),
                      if (!modelsSnap.hasData)
                        const SizedBox(height: 140, child: LoadingState())
                      else if (models.isEmpty)
                        const EmptyState(icon: Icons.people_outline, title: 'No models yet', message: 'Models added to your roster will show up here.')
                      else
                        SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: models.length > 6 ? 6 : models.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final m = models[index].data() as Map<String, dynamic>;
                              return InkWell(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModelDetailPage(modelId: models[index].id))),
                                child: Container(
                                  width: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.paper,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(color: AppColors.line),
                                    boxShadow: AppShadows.card,
                                  ),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    ProfileAvatar(imageUrl: m['avatarUrl'], name: m['displayName'], size: 56),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        m['displayName'] ?? 'Model',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption,
                                      ),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text('Recent Announcements', style: AppTypography.subheading),
                      const SizedBox(height: 12),
                      const SizedBox(height: 320, child: AnnouncementsPage()),
                      const SizedBox(height: 20),
                      Text('Recent Castings', style: AppTypography.subheading),
                      const SizedBox(height: 12),
                      if (!castingsSnap.hasData)
                        const LoadingState()
                      else if (castings.isEmpty)
                        const EmptyState(icon: Icons.work_outline, title: 'No castings yet', message: 'Castings you post will show up here.')
                      else
                        Column(
                          children: castings.take(3).map((doc) {
                            final c = doc.data() as Map<String, dynamic>;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppColors.paper,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: const BorderSide(color: AppColors.line)),
                              child: ListTile(
                                title: Text(c['title'] ?? c['projectTitle'] ?? 'Untitled casting', style: AppTypography.bodyEmphasized),
                                subtitle: Text(c['location'] ?? '', style: AppTypography.caption),
                                trailing: StatusPill(status: (c['status'] ?? 'open').toString()),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CastingDetailPage(castingId: doc.id))),
                              ),
                            );
                          }).toList(),
                        ),
                    ]);
                  },
                );
              },
            );
          },
        ),
      ]),
    );
  }
}
