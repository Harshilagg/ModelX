import 'package:flutter/material.dart';
import 'widgets/header.dart';
import 'widgets/dashboard_card.dart';
import 'roster/model_roster_page.dart';
import 'scouting/scout_page.dart';
import 'casting/casting_list_page.dart';
import 'announcements/announcements_page.dart';
import 'team_access/team_access_page.dart';

class AgencyDashboardPage extends StatefulWidget {
  const AgencyDashboardPage({super.key});

  @override
  State<AgencyDashboardPage> createState() => _AgencyDashboardPageState();
}

class _AgencyDashboardPageState extends State<AgencyDashboardPage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    _HomeView(),
    ModelRosterPage(),
    ScoutPage(),
    CastingListPage(),
    AnnouncementsPage(),
    TeamAccessPage(),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'My Models'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: 'Scout'),
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Castings'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), label: 'Announcements'),
          BottomNavigationBarItem(icon: Icon(Icons.group_add_outlined), label: 'Team'),
        ],
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            DashboardCard(title: 'Total Models', value: '24', icon: Icons.person),
            DashboardCard(title: 'Active Castings', value: '3', icon: Icons.work),
            DashboardCard(title: 'New Messages', value: '5', icon: Icons.mail),
            DashboardCard(title: 'Recent Activity', value: '12', icon: Icons.history),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Recent Models', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => Container(
              width: 120,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(radius: 36, backgroundColor: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('Model ${index+1}'),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Recent Castings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Column(children: List.generate(3, (i) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(title: Text('Casting ${i+1}'), subtitle: const Text('Brief details'))))),
      ]),
    );
  }
}
