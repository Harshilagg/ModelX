import 'package:flutter/material.dart';
import '../ui/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';
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
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: Text('Results for "${widget.query}"')),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              itemCount: 6,
              itemBuilder: (context, index) => AppSkeleton.listTile(),
            )
          : (_results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No results found',
                  message: 'Try a different name or username.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    final fullName = (user['fullName'] as String?) ??
                        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                    final username = user['username']?.toString() ?? '';
                    final subtitle = username.isNotEmpty ? '@$username' : (user['bio'] ?? '');
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                      leading: ProfileAvatar(
                        imageUrl: user['profileImage'] as String?,
                        name: fullName,
                        size: 44,
                      ),
                      title: Text(fullName, style: AppTypography.bodyEmphasized),
                      subtitle: Text(
                        subtitle,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
