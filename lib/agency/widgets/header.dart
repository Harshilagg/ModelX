import 'package:flutter/material.dart';
import '../agency_profile_page.dart';
import '../scouting/search_service.dart';
import '../communication/conversation_list_page.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_search_bar.dart';

class AgencyHeader extends StatelessWidget implements PreferredSizeWidget {
  const AgencyHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.paper,
          boxShadow: AppShadows.raised,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyProfilePage())),
              child: Row(
                children: const [
                  CircleAvatar(radius: 20, backgroundColor: AppColors.line),
                  SizedBox(width: 8),
                  Text('Agency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Use Expanded so the search bar adapts to screen width on mobile
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: AppSearchBar(
                  hintText: 'Search models, castings, talent...',
                  showClearButton: true,
                  onSubmitted: (v) => SearchService.setQuery(v.trim()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationListPage())),
              icon: const Icon(Icons.mark_chat_unread, color: AppColors.ink),
              iconSize: AppIconSize.md,
            ),
          ],
        ),
      ),
    );
  }
}
