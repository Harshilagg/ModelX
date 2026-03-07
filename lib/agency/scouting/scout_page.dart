import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/model_card.dart';
import 'scout_service.dart';

class ScoutPage extends StatefulWidget {
  const ScoutPage({super.key});

  @override
  State<ScoutPage> createState() => _ScoutPageState();
}

class _ScoutPageState extends State<ScoutPage> {
  final _searchCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  final _service = ScoutService();

  String? _gender;
  int? _minAge;
  int? _maxAge;
  String _sort = 'relevance';
  bool _loading = false;

  // full fetched+filtered results and visible page slice
  List<Map<String, dynamic>> _allResults = [];
  List<Map<String, dynamic>> _results = [];
  int _pageSize = 20;

  @override
  void dispose() {
    _searchCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _results = [];
    });

    final filters = <String, dynamic>{};
    if (_gender != null && _gender!.isNotEmpty) filters['gender'] = _gender;
    if (_minAge != null) filters['minAge'] = _minAge;
    if (_maxAge != null) filters['maxAge'] = _maxAge;
    if (_locationCtl.text.trim().isNotEmpty) filters['location'] = _locationCtl.text.trim();

    final query = _searchCtl.text.trim();

    try {
      final results = await _service.searchUsers(query: query, filters: filters);

      // client-side permissive matching: show doc if ANY one field matches query or filters
      final qLower = query.toLowerCase();
      final List<Map<String, dynamic>> docs = [];

      for (final d in results) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(d);
        data['id'] = data['id'] ?? data['uid'];

        bool matched = false;

        if (qLower.isEmpty) matched = true;

        // fields to check for permissive matching
        final fullName = (data['fullName'] ?? data['displayName'] ?? '').toString().toLowerCase();
        final username = (data['username'] ?? '').toString().toLowerCase();
        final location = (data['location'] ?? '').toString().toLowerCase();

        List<String> toList(dynamic v) {
          if (v == null) return [];
          if (v is List) return v.map((e) => e.toString().toLowerCase()).toList();
          return v.toString().split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
        }

        final skills = toList(data['skills']);
        final specialties = toList(data['specialties']);
        final languages = toList(data['languages']);
        final experience = (data['experience'] ?? '').toString().toLowerCase();
        final preferredWork = (data['preferredWork'] ?? '').toString().toLowerCase();

        if (qLower.isNotEmpty) {
          if (fullName.contains(qLower)) matched = true;
          if (username.contains(qLower)) matched = true;
          if (location.contains(qLower)) matched = true;
          if (skills.any((s) => s.contains(qLower))) matched = true;
          if (specialties.any((s) => s.contains(qLower))) matched = true;
          if (languages.any((s) => s.contains(qLower))) matched = true;
          if (experience.contains(qLower)) matched = true;
          if (preferredWork.contains(qLower)) matched = true;
        }

        // apply provided filters permissively (if any filter present, but server-side already applied some)
        if (!matched && filters.isNotEmpty) {
          if (filters['gender'] != null && (data['gender']?.toString() == filters['gender'])) matched = true;
          if (filters['minAge'] != null && data['age'] != null && (data['age'] as num) >= (filters['minAge'] as num)) matched = true;
          if (filters['maxAge'] != null && data['age'] != null && (data['age'] as num) <= (filters['maxAge'] as num)) matched = true;
          if (filters['location'] != null && filters['location'].toString().isNotEmpty && data['location'] != null && data['location'].toString().toLowerCase().contains(filters['location'].toString().toLowerCase())) matched = true;
        }

        if (matched) docs.add(data);
      }

      // simple sorting
      if (_sort == 'recency') {
        docs.sort((a, b) {
          final ta = (a['createdAt'] is Timestamp) ? (a['createdAt'] as Timestamp).toDate() : DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = (b['createdAt'] is Timestamp) ? (b['createdAt'] as Timestamp).toDate() : DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
      }

      if (mounted) {
        setState(() {
          _allResults = docs;
          _results = _allResults.take(_pageSize).toList();
        });
      }
    } catch (e, st) {
      debugPrint('Scout search failed: $e');
      debugPrint(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      } else {
        _loading = false;
      }
    }
  }

  Future<void> _toggleShortlist(String modelId) async {
    final agencyId = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('agency').doc(agencyId).collection('shortlist').doc(modelId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from shortlist')));
    } else {
      await ref.set({'modelId': modelId, 'shortlistedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to shortlist')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Talent Scouting')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtl,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, skill, location...'),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _search, child: const Text('Search'))
          ]),

          const SizedBox(height: 12),

          // Filters row (simple)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              DropdownButton<String>(
                value: _gender,
                hint: const Text('Gender'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 120, child: TextField(decoration: const InputDecoration(hintText: 'Min age'), keyboardType: TextInputType.number, onChanged: (v) => _minAge = int.tryParse(v))),
              const SizedBox(width: 8),
              SizedBox(width: 120, child: TextField(decoration: const InputDecoration(hintText: 'Max age'), keyboardType: TextInputType.number, onChanged: (v) => _maxAge = int.tryParse(v))),
              const SizedBox(width: 12),
              SizedBox(width: 180, child: TextField(controller: _locationCtl, decoration: const InputDecoration(hintText: 'Location'))),
              const SizedBox(width: 12),
              DropdownButton<String>(value: _sort, items: const [DropdownMenuItem(value: 'relevance', child: Text('Relevance')), DropdownMenuItem(value: 'recency', child: Text('Newest'))], onChanged: (v) => setState(() => _sort = v!)),
            ]),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                          ? const Center(child: Text('No results'))
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _results.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
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
                                if (_results.length < _allResults.length)
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
