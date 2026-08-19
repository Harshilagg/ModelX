import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'roster_service.dart';

class AddModelPage extends StatefulWidget {
  const AddModelPage({super.key});

  @override
  State<AddModelPage> createState() => _AddModelPageState();
}

class _AddModelPageState extends State<AddModelPage> {
  final _emailCtl = TextEditingController();
  final _service = RosterService();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.inviteModel('', email, {});
      if (!mounted) return;
      showAppToast(context, 'Invite sent');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Invite failed: $e', isError: true);
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Model')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Model email',
              hint: 'name@example.com',
              controller: _emailCtl,
              keyboardType: TextInputType.emailAddress,
              leadingIcon: const Icon(Icons.mail_outline, size: AppIconSize.sm, color: AppColors.inkFaint),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Send Invite',
              onPressed: _sending ? null : _invite,
              loading: _sending,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}
