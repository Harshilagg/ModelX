import 'package:flutter/material.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/state_views.dart';
import 'roster_service.dart';

class ModelDetailPage extends StatefulWidget {
  final String modelId;
  const ModelDetailPage({super.key, required this.modelId});

  @override
  State<ModelDetailPage> createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  final _service = RosterService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await _service.getModelById(widget.modelId);
    setState(() {
      _data = doc.exists ? doc.data() as Map<String, dynamic> : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingState());
    }
    final d = _data ?? {};
    final portfolio = d['portfolio'] is List ? (d['portfolio'] as List) : const [];
    return Scaffold(
      backgroundColor: AppColors.paperRaised,
      appBar: AppBar(title: Text(d['displayName'] ?? 'Model')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d['coverUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.network(d['coverUrl'], height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  ProfileAvatar(imageUrl: d['avatarUrl'], name: d['displayName'], size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['displayName'] ?? '', style: AppTypography.subheading),
                        if ((d['location'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: AppIconSize.xs, color: AppColors.inkFaint),
                              const SizedBox(width: 4),
                              Text(d['location'], style: AppTypography.caption),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if ((d['bio'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About', style: AppTypography.label),
                    const SizedBox(height: 8),
                    Text(d['bio'], style: AppTypography.body.copyWith(height: 1.5)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Portfolio', style: AppTypography.label),
            const SizedBox(height: 10),
            if (portfolio.isEmpty)
              const EmptyState(icon: Icons.photo_library_outlined, title: 'No portfolio images yet')
            else
              Column(
                children: portfolio
                    .map<Widget>(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: p.toString().contains('http')
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: Image.network(p, height: 120, width: double.infinity, fit: BoxFit.cover),
                              )
                            : const SizedBox(),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 20),
            AppButton(label: 'Edit Portfolio', onPressed: () {}, expand: true),
          ],
        ),
      ),
    );
  }
}
