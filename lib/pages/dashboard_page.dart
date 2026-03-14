import 'package:flutter/material.dart';
import 'home_page.dart';
import 'notifications_page.dart';
import 'network_page.dart';
import 'jobs_page.dart';
import 'profile_page.dart';
import 'chat_inbox_page.dart';
import 'search_service_impl.dart';
import 'user_profile_page.dart';
import 'search_results_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/model_x_copilot.dart';



class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  DateTime? _lastBackPress;
  final _pages = [
    const HomePage(),
    const NotificationsPage(),
    const NetworkPage(),
    const JobsPage(),
  ];
  final SearchService _searchService = SearchService();
  List<Map<String, dynamic>> searchResults = [];
  bool searching = false;
  String _userType = 'User';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<String> recentSearches = [];
  bool showRecent = false;
  static const int _suggestionLimit = 5;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && mounted) {
        setState(() => showRecent = false);
      }
    });
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        setState(() => _userType = doc.data()?['userType'] ?? 'User');
      }
    }
  }

  
  void onSearchChanged(String query) async {
    final q = query.trim();
    // Normalize common username input: strip leading '@' so we search stored usernames
    final normalized = q.replaceFirst(RegExp(r'^@'), '');
    if (normalized.isEmpty) {
      setState(() {
        searchResults = [];
        showRecent = _searchFocus.hasFocus;
      });
      return;
    }

    setState(() {
      searching = true;
      showRecent = false;
    });

    final results = await _search_service_search(normalized);
    if (!mounted) return;

    setState(() {
      searchResults = results.take(_suggestionLimit).toList();
      searching = false;
    });
  }

  // wrapper to call search service and handle exceptions
  Future<List<Map<String, dynamic>>> _search_service_search(String q) async {
    try {
      return await _searchService.searchUsers(q);
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    if (!mounted) return;
    setState(() => recentSearches = list);
  }

  Future<void> _addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > 10) list.removeRange(10, list.length);
    await prefs.setStringList('recent_searches', list);
    if (!mounted) return;
    setState(() => recentSearches = list);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return false;
        }
        return true; // allow app exit
      },
      child: Scaffold(
        body: Column(
          
          children: [
            // Persistent Top Bar (modern neutral style)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          searchResults = [];
                          showRecent = false;
                        });
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage()));
                      },
                      icon: Icon(Icons.person, color: Theme.of(context).primaryColor),
                    ),

                    const SizedBox(width: 12),

                    // Search field with subtle card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocus,
                                onChanged: onSearchChanged,
                                onTap: () {
                                  if (_searchController.text.trim().isEmpty) {
                                    _loadRecentSearches();
                                    setState(() => showRecent = true);
                                  }
                                },
                                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search users or @username'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Chat button with badge
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('user_chats')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
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
                                setState(() {
                                  searchResults = [];
                                  showRecent = false;
                                });
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatInboxPage()));
                              },
                            ),
                            if (unreadTotal > 0)
                              Positioned(
                                right: 2,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                  child: Center(child: Text(unreadTotal.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Page content
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // dismiss keyboard and search results when tapping anywhere
                  FocusScope.of(context).unfocus();
                  setState(() {
                    searchResults.clear();
                    showRecent = false;
                  });
                },
                child: Stack(
                  children: [
                    _pages[_selectedIndex],

                    // Tap-catcher: when overlay is visible, capture taps outside it to dismiss
                    if (showRecent || searchResults.isNotEmpty)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              searchResults = [];
                              showRecent = false;
                            });
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                    // Search / Recent Results Overlay (positioned under top bar)
                    if (showRecent || searchResults.isNotEmpty)
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 20,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 380),
                            child: Container(
                              color: Colors.white,
                              child: Builder(builder: (context) {
                                if (showRecent && _searchController.text.trim().isEmpty) {
                                  if (recentSearches.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text('No recent searches'),
                                    );
                                  }
                                  return ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: recentSearches.length,
                                    itemBuilder: (_, i) {
                                      final q = recentSearches[i];
                                      return ListTile(
                                        leading: const Icon(Icons.history),
                                        title: Text(q),
                                        onTap: () {
                                          _searchController.text = q;
                                          onSearchChanged(q);
                                          _addRecentSearch(q);
                                        },
                                      );
                                    },
                                  );
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: searchResults.length + 1,
                                  itemBuilder: (_, index) {
                                    if (index < searchResults.length) {
                                      final user = searchResults[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: user['profileImage'] != null
                                              ? NetworkImage(user['profileImage'])
                                              : null,
                                        ),
                                        title: Text(user['fullName'] ?? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
                                        subtitle: Text(user['username'] != null && user['username'].toString().isNotEmpty ? '@${user['username']}' : (user['bio'] ?? '')),
                                        onTap: () async {
                                        final uid = user['uid'];

                                          FocusScope.of(context).unfocus();

                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserProfilePage(uid: uid),
                                            ),
                                          );

                                          if (!mounted) return;
                                          _addRecentSearch(_searchController.text.trim());
                                          setState(() {
                                            searchResults.clear();
                                            showRecent = false;
                                          });
                                        }
                                      );
                                    }

                                    return ListTile(
                                      leading: const Icon(Icons.search),
                                      title: const Text('See all results'),
                                      onTap: () {
                                        final q = _searchController.text.trim();
                                        if (q.isEmpty) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => SearchResultsPage(query: q)),
                                        );
                                        _addRecentSearch(q);
                                        setState(() {
                                          searchResults = [];
                                          showRecent = false;
                                        });
                                      },
                                    );
                                  },
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          ],
        ),

        // Bottom Navigation Bar (modern)
        bottomNavigationBar: Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)]),
          child: SafeArea(
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() {
                _selectedIndex = i;
                // hide search overlay when switching tabs
                searchResults = [];
                showRecent = false;
                FocusScope.of(context).unfocus();
              }),
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey[600],
              type: BottomNavigationBarType.fixed,
              backgroundColor: Theme.of(context).cardColor,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Network'),
                BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
              ],
            ),
          ),
        ),
        floatingActionButton: ModelXCopilot(
          pageContext: {
            'page': 'home',
            'role': _userType,
            'tab': ['Home', 'Notifications', 'Network', 'Jobs'][_selectedIndex],
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}
