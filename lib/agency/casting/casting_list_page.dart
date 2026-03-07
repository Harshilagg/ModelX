import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCastingPage())).then((_) => _load()), label: const Text('Create Casting'), icon: const Icon(Icons.add)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Castings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: Column(children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: _castings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _loadingMore
                            ? const CircularProgressIndicator()
                            : ElevatedButton(onPressed: _loadMore, child: const Text('Load more')),
                      ),
                  ]),
                ),
        ]),
      ),
    );
  }
}
