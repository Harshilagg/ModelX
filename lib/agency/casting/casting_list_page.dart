import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/state_views.dart';
import '../widgets/casting_card.dart';
import 'create_casting_page.dart';
import 'casting_service.dart';
import 'casting_detail_page.dart';

class CastingListPage extends StatefulWidget {
  const CastingListPage({super.key});

  @override
  State<CastingListPage> createState() => _CastingListPageState();
}

class _CastingListPageState extends State<CastingListPage> {
  final _service = CastingService();
  List<dynamic> _castings = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _pageSize = 12;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final agencyId = user?.uid ?? '';
      final snap = await _service.fetchCastingsForAgencyPage(agencyId, limit: _pageSize);
      setState(() {
        _castings = snap.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = snap.docs.length == _pageSize;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final agencyId = user?.uid ?? '';
      final snap = await _service.fetchCastingsForAgencyPage(agencyId, startAfter: _lastDoc, limit: _pageSize);
      final items = snap.docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();
      setState(() {
        _castings.addAll(items);
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length == _pageSize;
      });
    } catch (_) {}
    setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCastingPage())).then((_) => _load()),
        label: const Text('Create casting'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        elevation: 0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Castings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm + 4),
          _loading
              ? const Expanded(child: LoadingState())
              : _castings.isEmpty
                  ? const Expanded(
                      child: EmptyState(
                        icon: Icons.campaign_outlined,
                        title: 'No castings yet',
                        message: 'Create your first casting call to start receiving applications.',
                      ),
                    )
                  : Expanded(
                  child: Column(children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: _castings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
                        itemBuilder: (context, index) {
                          final c = _castings[index] as Map<String, dynamic>;
                          DateTime createdAt;
                          try {
                            createdAt = (c['createdAt'] as Timestamp).toDate();
                          } catch (_) {
                            createdAt = DateTime.now();
                          }

                          return InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CastingDetailPage(castingId: c['id']))).then((_) => _load()),
                            child: CastingCard(
                              id: c['id'],
                              title: c['title'] ?? '',
                              description: c['description'] ?? '',
                              posterName: c['agencyName'] ?? '',
                              location: c['location'] ?? '',
                              timeline: c['timeline'] ?? '',
                              budgetType: c['budgetType'] ?? '',
                              budgetAmount: c['budgetAmount']?.toString() ?? '',
                              compensationMin: c['compensationMin']?.toString(),
                              compensationMax: c['compensationMax']?.toString(),
                              shootingStart: (c['shootingStart'] is Timestamp) ? (c['shootingStart'] as Timestamp).toDate() : null,
                              shootingEnd: (c['shootingEnd'] is Timestamp) ? (c['shootingEnd'] as Timestamp).toDate() : null,
                              talentRequirements: (c['talentRequirements'] is Map) ? Map<String, dynamic>.from(c['talentRequirements'] as Map) : null,
                              media: List<String>.from(c['media'] ?? []),
                              applicants: c['applicationsCount'] ?? c['applicantsCount'] ?? 0,
                              status: c['status'] ?? 'open',
                              showApply: false,
                              createdAt: createdAt,
                              actionWidget: null,
                            ),
                          );
                        },
                      ),
                    ),
                    if (_hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: AppButton(
                          label: 'Load more',
                          variant: AppButtonVariant.secondary,
                          loading: _loadingMore,
                          onPressed: _loadingMore ? null : _loadMore,
                        ),
                      ),
                  ]),
                ),
        ]),
      ),
    );
  }
}
