import 'package:flutter/material.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'brand_profile_page.dart';
import 'post_gig_page.dart';
import 'applications_page.dart';
import 'brand_notifications_page.dart';
import 'brand_home_page.dart';
import '../pages/chat_inbox_page.dart';
import 'brand_manage_gigs_page.dart';

class BrandDashboardPage extends StatefulWidget {
  const BrandDashboardPage({super.key});

  @override
  State<BrandDashboardPage> createState() => _BrandDashboardPageState();
}

class _BrandDashboardPageState extends State<BrandDashboardPage> {
  int _selectedIndex = 0;

  final TextEditingController _searchController = TextEditingController();

  final List<Widget> _pages = const [
    BrandHomePage(),
    BrandManageGigsPage(), 
    PostGigPage(),
    ApplicationsPage(),
    BrandNotificationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      // ================= TOP BAR =================
      body: Column(
        children: [
          Container(
          color: Colors.blue, // Top bar color
          child: SafeArea(
          child: Container(
            color: Colors.blue, // Match SafeArea color with top bar
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                // PROFILE
                IconButton(
                  icon: const Icon(Icons.business, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BrandProfilePage(),
                      ),
                    );
                  },
                ),

                // SEARCH
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search models, skills, locations...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // CHAT
                IconButton(
                  icon: const Icon(Icons.chat, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatInboxPage(
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          ),
          ),

          // ================= PAGE CONTENT =================
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      

      // ================= BOTTOM NAV =================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
           BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Manage Gigs', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Post Gig',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
