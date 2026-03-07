import 'package:flutter/material.dart';
import '../agency_profile_page.dart';
import 'search_bar.dart' as local_widgets;
import '../communication/conversation_list_page.dart';

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
        color: Colors.white,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgencyProfilePage())),
              child: Row(
                children: const [
                  CircleAvatar(radius: 20, backgroundColor: Colors.grey),
                  SizedBox(width: 8),
                  Text('Agency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Use Expanded so the search bar adapts to screen width on mobile
            Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: local_widgets.SearchBar())),
            const SizedBox(width: 12),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationListPage())), icon: const Icon(Icons.mark_chat_unread)),
          ],
        ),
      ),
    );
  }
}
