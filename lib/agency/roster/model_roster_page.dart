import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/state_views.dart';
import 'roster_service.dart';
import 'model_detail_page.dart';
import 'add_model_page.dart';

class ModelRosterPage extends StatefulWidget {
  const ModelRosterPage({super.key});

  @override
  State<ModelRosterPage> createState() => _ModelRosterPageState();
}

class _ModelRosterPageState extends State<ModelRosterPage> {
  final _service = RosterService();
  bool _gridView = true;
  List<dynamic> _models = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // attempt to find current agency id via auth (defer to service caller in future)
    // For now leave agencyId blank which will return empty set in dev
    try {
      final snapshot = await _service.fetchAgencyModels('');
      setState(() {
        _models = snapshot.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
      });
    } catch (_) {
      // ignore for now
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Models'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddModelPage())),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Invite model',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.inkSoft),
                tooltip: 'Refresh',
              ),
              const Spacer(),
              _ViewModeToggle(
                gridView: _gridView,
                onChanged: (grid) => setState(() => _gridView = grid),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingState()
                : _models.isEmpty
                    ? const EmptyState(
                        icon: Icons.groups_2_outlined,
                        title: 'No models yet',
                        message: 'Invite a model to start building your roster.',
                      )
                    : _gridView
                        ? GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _models.length,
                            itemBuilder: (context, index) {
                              final m = _models[index];
                              return AppCard(
                                padding: const EdgeInsets.all(12),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModelDetailPage(modelId: m['id']))),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ProfileAvatar(imageUrl: m['avatarUrl'], name: m['displayName'], size: 64),
                                    const SizedBox(height: 12),
                                    Text(
                                      m['displayName'] ?? 'Model',
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            itemCount: _models.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final m = _models[index];
                              return AppCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ModelDetailPage(modelId: m['id']))),
                                child: Row(
                                  children: [
                                    ProfileAvatar(imageUrl: m['avatarUrl'], name: m['displayName'], size: 48),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m['displayName'] ?? 'Model',
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodyEmphasized.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          if ((m['headline'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              m['headline'],
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.caption,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _confirmUnlink(m['id']),
                                      icon: const Icon(Icons.link_off, color: AppColors.inkFaint),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          )
        ]),
      ),
    );
  }

  void _confirmUnlink(String modelId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove model'),
        content: const Text('Unlink this model from your agency?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await _service.unlinkModel(modelId);
      _load();
    }
  }
}

/// Icon-grouped segmented control shared by any screen that needs a
/// two-way view toggle — active segment fills with `AppColors.ink`,
/// matching the app's selected-state pattern elsewhere.
class _ViewModeToggle extends StatelessWidget {
  final bool gridView;
  final ValueChanged<bool> onChanged;

  const _ViewModeToggle({required this.gridView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(icon: Icons.grid_view_rounded, selected: gridView, onTap: () => onChanged(true)),
          _segment(icon: Icons.view_list_rounded, selected: !gridView, onTap: () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment({required IconData icon, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Icon(icon, size: AppIconSize.sm, color: selected ? AppColors.paper : AppColors.inkFaint),
      ),
    );
  }
}
