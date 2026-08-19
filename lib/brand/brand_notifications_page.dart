import 'package:flutter/material.dart';
import '../ui/app_theme.dart';
import '../widgets/state_views.dart';

class BrandNotificationsPage extends StatelessWidget {
  const BrandNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Notifications')),
      body: const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No new alerts',
        message: "We'll notify you about applications and messages",
      ),
    );
  }
}
