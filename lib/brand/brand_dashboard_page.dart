import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'brand_profile_page.dart';
import 'post_gig_page.dart';
import 'applications_page.dart';
import 'brand_notifications_page.dart';
import 'brand_home_page.dart';
import '../pages/chat_inbox_page.dart';
import 'brand_manage_gigs_page.dart';
import '../agency/scouting/scout_page.dart';
import '../pages/home_page.dart';
import '../widgets/model_x_copilot.dart';

class BrandDashboardPage extends StatefulWidget {
  const BrandDashboardPage({super.key});

  @override
  State<BrandDashboardPage> createState() => _BrandDashboardPageState();
}

class _BrandDashboardPageState extends State<BrandDashboardPage> {
  int _selectedIndex = 0;

  final TextEditingController _searchController = TextEditingController();

  final List<Widget> _pages = const [
    HomePage(), // New Primary Social Feed
    BrandHomePage(), // Analysis/Insights moved here
    BrandManageGigsPage(), 
    PostGigPage(),
    ApplicationsPage(),
    BrandNotificationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ================= PREMIUM TOP BAR =================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // PROFILE
                  IconButton(
                    icon: Icon(Icons.business_center, color: Theme.of(context).primaryColor),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BrandProfilePage()),
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  // MODERN SEARCH BAR
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search models, skills...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // CHAT WITH BADGE
                  if (currentUser != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('user_chats')
                          .doc(currentUser.uid)
                          .collection('chats')
                          .where('unreadCount', isGreaterThan: 0)
                          .snapshots(),
                      builder: (context, snapshot) {
                        int unreadTotal = 0;
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            unreadTotal += (doc['unreadCount'] ?? 0) as int;
                          }
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: Icon(Icons.chat_bubble_outline, color: Theme.of(context).primaryColor),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChatInboxPage()),
                                );
                              },
                            ),
                            if (unreadTotal > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Center(
                                    child: Text(
                                      unreadTotal > 9 ? '9+' : unreadTotal.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                  // AI SCOUT
                  IconButton(
                    icon: const Icon(Icons.auto_awesome_outlined, color: Color(0xFF0F172A)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScoutPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ================= PAGE CONTENT =================
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),

      // ================= PREMIUM BOTTOM NAV =================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF0F172A), // Midnight Navy
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.rss_feed_rounded), label: 'Feed'),
              BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Insights'),
              BottomNavigationBarItem(icon: Icon(Icons.layers_outlined), label: 'Gigs'),
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Post'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Applicants'),
              BottomNavigationBarItem(icon: Icon(Icons.notifications_none_rounded), label: 'Alerts'),
            ],
          ),
        ),
      ),
      floatingActionButton: ModelXCopilot(
        pageContext: {
          'page': 'home',
          'role': 'Brand',
          'tab': ['Feed', 'Insights', 'Gigs', 'Post', 'Applicants', 'Alerts'][_selectedIndex],
        },
      ),
    );
  }
}
