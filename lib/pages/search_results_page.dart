import 'package:flutter/material.dart';
import 'search_service_impl.dart';
import 'user_profile_page.dart';

class SearchResultsPage extends StatefulWidget {
  final String query;
  const SearchResultsPage({super.key, required this.query});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final SearchService _searchService = SearchService();
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  Future<void> _runSearch() async {
    final q = widget.query.trim();
    final normalized = q.replaceFirst(RegExp(r'^@'), '');
    final results = await _searchService.searchUsers(normalized);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results for "${widget.query}"')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_results.isEmpty
              ? const Center(child: Text('No results found'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user['profileImage'] != null ? NetworkImage(user['profileImage']) : null,
                      ),
                      title: Text(user['fullName'] ?? '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'),
                      subtitle: Text(user['username'] != null && user['username'].toString().isNotEmpty ? '@${user['username']}' : (user['bio'] ?? '')),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UserProfilePage(uid: user['uid'])),
                        );
                      },
                    );
                  },
                )),
    );
  }
}
