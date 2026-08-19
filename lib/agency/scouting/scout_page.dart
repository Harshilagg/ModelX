import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/model_card.dart';
import '../../widgets/model_x_copilot.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import 'scout_service.dart';
import 'ai_scout_service.dart';

class ScoutPage extends StatefulWidget {
  final bool standalone;
  final Function(List<AiScoutResult>)? onExternalResults;
  final String role;
  const ScoutPage({super.key, this.standalone = true, this.onExternalResults, this.role = 'Agency'});

  // Static bridge for external AI results (e.g. from Dashboard Copilot)
  static void Function(List<AiScoutResult>)? onAiResultsExternal;

  @override
  State<ScoutPage> createState() => _ScoutPageState();
}

class _ScoutPageState extends State<ScoutPage> {
  final _searchCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  final _service = ScoutService();
  final _aiService = AiScoutService();

  bool _aiMode = false;
  String? _gender;
  int? _minAge;
  int? _maxAge;
  String _sort = 'relevance';
  bool _loading = false;

  // full fetched+filtered results and visible page slice
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _results = [];
  List<AiScoutResult> _aiResults = [];
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    ScoutPage.onAiResultsExternal = _onAiResults;
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _locationCtl.dispose();
    ScoutPage.onAiResultsExternal = null; // Clear bridge
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _results = [];
      _aiMode = false; // Reset AI mode when starting a normal search
      _aiResults = []; // Also clear AI results
    });

    final filters = <String, dynamic>{};
    if (_gender != null && _gender!.isNotEmpty) filters['gender'] = _gender;
    if (_minAge != null) filters['minAge'] = _minAge;
    if (_maxAge != null) filters['maxAge'] = _maxAge;
    if (_locationCtl.text.trim().isNotEmpty) filters['location'] = _locationCtl.text.trim();

    final query = _searchCtl.text.trim();

    try {
      final results = await _service.searchUsers(query: query, filters: filters);

      setState(() {
        _allResults = results.map((d) {
          final data = Map<String, dynamic>.from(d);
          data['id'] = data['id'] ?? data['uid'];
          return data;
        }).toList();

        // simple sorting
        if (_sort == 'recency') {
          _allResults.sort((a, b) {
            final ta = (a['createdAt'] is Timestamp) ? (a['createdAt'] as Timestamp).toDate() : DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final tb = (b['createdAt'] is Timestamp) ? (b['createdAt'] as Timestamp).toDate() : DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return tb.compareTo(ta);
          });
        }

        _results = _allResults.take(_pageSize).toList();
      });
    } catch (e, st) {
      debugPrint('Scout search failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onAiResults(List<AiScoutResult> results) {
    setState(() {
      _aiResults = results;
      _aiMode = true;
      _allResults = [];
      _results = [];
      _loading = false;
    });
  }

  /// Runs the natural-language talent search directly from this page's own
  /// search bar — the AI pipeline previously only ran through the hidden
  /// Copilot bottom sheet (the floating "ask anything" button), which made
  /// it easy to miss entirely and easy to mistake the plain filter search
  /// above for "the AI search."
  Future<void> _aiSearch() async {
    final query = _searchCtl.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe who you\'re looking for first.')));
      return;
    }

    setState(() {
      _loading = true;
      _allResults = [];
      _results = [];
    });

    try {
      final results = await _aiService.searchTalent(query);
      if (!mounted) return;
      setState(() {
        _aiResults = results;
        _aiMode = true;
      });
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No AI matches found for that search — try being less specific.')));
      }
    } catch (e) {
      debugPrint('AI talent search failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI search failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleShortlist(String modelId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final collection = widget.role == 'Brand' ? 'brands' : 'agency';
    final ref = FirebaseFirestore.instance.collection(collection).doc(uid).collection('shortlist').doc(modelId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from shortlist')));
    } else {
      await ref.set({'modelId': modelId, 'shortlistedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to shortlist')));
    }
  }

  /// A dropdown filter styled to match `AppTextField`'s label-above-field
  /// layout, so it reads as one system with the text filters beside it.
  Widget _buildDropdownFilter<T>({
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.label.copyWith(color: AppColors.inkSoft, letterSpacing: 0.08)),
        const SizedBox(height: 7),
        DropdownButtonFormField<T>(
          value: value,
          hint: Text(hint, style: AppTypography.body.copyWith(color: AppColors.inkFaint)),
          isExpanded: true,
          style: AppTypography.bodyEmphasized,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkFaint, size: AppIconSize.sm),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talent Scouting'),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: widget.standalone ? ModelXCopilot(
        pageContext: {'page': 'scout', 'role': widget.role},
        onResults: _onAiResults,
      ) : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtl,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Try "tall models in Delhi for editorial"...'),
                onSubmitted: (_) => _aiSearch(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _search, child: const Text('Filter')),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _aiSearch,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Ask AI'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: AppColors.paper),
            ),
          ]),

          const SizedBox(height: 12),

          // Filters row
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 140, child: _buildDropdownFilter<String>(
                    label: 'Gender',
                    value: _gender,
                    hint: 'Any',
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Any')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  )),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: AppTextField(
                      label: 'Min age',
                      hint: 'e.g. 18',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _minAge = int.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: AppTextField(
                      label: 'Max age',
                      hint: 'e.g. 35',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _maxAge = int.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: AppTextField(
                      label: 'Location',
                      hint: 'City, state...',
                      controller: _locationCtl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 150, child: _buildDropdownFilter<String>(
                    label: 'Sort',
                    value: _sort,
                    hint: 'Relevance',
                    items: const [
                      DropdownMenuItem(value: 'relevance', child: Text('Relevance')),
                      DropdownMenuItem(value: 'recency', child: Text('Newest')),
                    ],
                    onChanged: (v) => setState(() => _sort = v!),
                  )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // AI Results Header (Premium Gradient)
          if (_aiMode && _aiResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AI Recommended Talent',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _aiMode = false;
                        _aiResults = [];
                        _search(); // Re-trigger normal search
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    label: const Text('Clear', style: TextStyle(color: Colors.white)),
                    style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                  ),
                ],
              ),
            ),

          if (_aiMode && _aiResults.isNotEmpty) const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_aiMode ? _aiResults : _results).isEmpty
                    ? const Center(child: Text('No results'))
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: _aiMode ? _aiResults.length : _results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (_aiMode) {
                                  final res = _aiResults[index];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ModelCard(data: res.profile, compact: true),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                onPressed: () => _toggleShortlist(res.profile['id']),
                                                icon: const Icon(Icons.star_border, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF0F172A).withOpacity(0.1)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A).withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("✨", style: TextStyle(fontSize: 16)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                res.explanation,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade800,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  );
                                }
                                final data = _results[index];
                                return Row(children: [
                                  Expanded(child: ModelCard(data: data, compact: true)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _toggleShortlist(data['id']),
                                    icon: const Icon(Icons.star_border),
                                  )
                                ]);
                              },
                            ),
                          ),
                          if (!_aiMode && _results.length < _allResults.length)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    final next = _allResults.skip(_results.length).take(_pageSize).toList();
                                    _results.addAll(next);
                                  });
                                },
                                child: const Text('Load more'),
                              ),
                            )
                        ],
                      ),
          )
        ]),
      ),
    );
  }
}
