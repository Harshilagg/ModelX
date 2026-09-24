import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ui/app_type.dart';
import '../ui/board_palette.dart';
import '../ui/board_theme.dart';
import '../ui/theme_controller.dart';
import '../widgets/kit/kit.dart';

/// The settings the app actually has.
///
/// These three lived scattered across the profile page -- the unit
/// switches inside the measurements editor, log out at the foot of a
/// long scroll. Settings is where people look for them, and moving them
/// here means the profile page is about the profile.
class SettingsPage extends StatefulWidget {
  /// Optional so the page can be pumped in a test without installing a
  /// scope. In the app it always comes from [ThemeScope], so settings
  /// and MaterialApp read the same controller rather than disagreeing.
  final ThemeController? themeController;

  const SettingsPage({super.key, this.themeController});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Both already exist on the user document and are written by the
  /// profile editor; this is a second way in, not a new field.
  String _heightUnit = 'cm';
  String _shoeSizeUnit = 'US';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        _heightUnit = (data?['heightUnit'] ?? 'cm').toString();
        _shoeSizeUnit = (data?['shoeSizeUnit'] ?? 'US').toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(String field, String value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        field: value,
      }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that. Try again.')),
      );
    }
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need your password to get back in."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // Everything below this is signed-in state, so the stack goes with
    // it rather than leaving a back button into a dead session.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final p = BoardColors.of(context);
    final controller = widget.themeController ?? ThemeScope.maybeOf(context);

    return Scaffold(
      backgroundColor: p.surface,
      appBar: AppBar(
        title: Text('Settings', style: AppType.heading(color: p.onSurface)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppMetrics.gutter,
                vertical: 12,
              ),
              children: [
                if (kThemeSwitchingEnabled && controller != null) ...[
                  _Section(label: 'Appearance', palette: p),
                  _Row(
                    label: 'Theme',
                    hint: 'Follow phone uses your device setting.',
                    palette: p,
                    control: AppSegmentedControl<ThemeMode>(
                      options: const [
                        (ThemeMode.system, 'Phone'),
                        (ThemeMode.light, 'Light'),
                        (ThemeMode.dark, 'Dark'),
                      ],
                      value: controller.storedMode,
                      dense: true,
                      onChanged: (m) async {
                        await controller.setMode(m);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],

                _Section(label: 'Units', palette: p),
                _Row(
                  label: 'Height',
                  palette: p,
                  control: AppSegmentedControl<String>(
                    options: const [('cm', 'cm'), ('in', 'in'), ('ft', 'ft')],
                    value: _heightUnit,
                    dense: true,
                    onChanged: (v) {
                      setState(() => _heightUnit = v);
                      _save('heightUnit', v);
                    },
                  ),
                ),
                _Row(
                  label: 'Shoe size',
                  palette: p,
                  control: AppSegmentedControl<String>(
                    options: const [('US', 'US'), ('EU', 'EU'), ('UK', 'UK')],
                    value: _shoeSizeUnit,
                    dense: true,
                    onChanged: (v) {
                      setState(() => _shoeSizeUnit = v);
                      _save('shoeSizeUnit', v);
                    },
                  ),
                ),

                _Section(label: 'Account', palette: p),
                const SizedBox(height: 4),
                AppPillButton(
                  label: 'Log out',
                  kind: AppButtonKind.outlined,
                  onPressed: _logOut,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final BoardPalette palette;

  const _Section({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(label, style: AppType.label(color: palette.onSurfaceFaint)),
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget control;
  final BoardPalette palette;

  const _Row({
    required this.label,
    required this.control,
    required this.palette,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.body(color: palette.onSurface)),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: AppType.caption(color: palette.onSurfaceFaint),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        control,
      ],
    ),
  );
}
