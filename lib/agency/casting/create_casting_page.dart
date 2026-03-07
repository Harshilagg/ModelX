import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cloudinary_service.dart';
import 'casting_service.dart';

class CreateCastingPage extends StatefulWidget {
  const CreateCastingPage({super.key});

  @override
  State<CreateCastingPage> createState() => _CreateCastingPageState();
}

class _CreateCastingPageState extends State<CreateCastingPage> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  final _compMinCtl = TextEditingController();
  final _compMaxCtl = TextEditingController();
  final _reqCtl = TextEditingController();
  final _outfitCtl = TextEditingController();
  final _looksCtl = TextEditingController();
  final _skillsCtl = TextEditingController();
  DateTime? _shootingStart;
  DateTime? _shootingEnd;
  String _genderReq = 'any';
  int? _minAge;
  int? _maxAge;
  String _status = 'open';
  final _picker = ImagePicker();
  final _service = CastingService();
  List<String> _mediaUrls = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _locationCtl.dispose();
    _compMinCtl.dispose();
    _compMaxCtl.dispose();
    _reqCtl.dispose();
    _outfitCtl.dispose();
    _looksCtl.dispose();
    _skillsCtl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _saving = true);
    final file = File(picked.path);
    final url = await CloudinaryService.uploadPortfolioImage(file, 'casting_${DateTime.now().millisecondsSinceEpoch}');
    if (url != null) {
      setState(() => _mediaUrls.add(url));
    }
    setState(() => _saving = false);
  }

  Future<void> _submit() async {
    if (_titleCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser;
    String agencyId = '';
    String? agencyName;
    if (user != null) {
      agencyId = user.uid;
      try {
        final doc = await FirebaseFirestore.instance.collection('agency').doc(agencyId).get();
        if (doc.exists && doc.data() != null) {
          agencyName = (doc.data()!['agencyName'] ?? doc.data()!['agency'] ?? '')?.toString();
        }
      } catch (_) {}
    }

    final talentReq = {
      'gender': _genderReq,
      if (_minAge != null) 'minAge': _minAge,
      if (_maxAge != null) 'maxAge': _maxAge,
      if (_looksCtl.text.trim().isNotEmpty) 'looks': _looksCtl.text.trim(),
      if (_skillsCtl.text.trim().isNotEmpty) 'skills': _skillsCtl.text.trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    };

    final data = {
      'title': _titleCtl.text.trim(),
      'description': _descCtl.text.trim(),
      'location': _locationCtl.text.trim(),
      'compensationMin': _compMinCtl.text.trim().isEmpty ? null : _compMinCtl.text.trim(),
      'compensationMax': _compMaxCtl.text.trim().isEmpty ? null : _compMaxCtl.text.trim(),
      'requirements': _reqCtl.text.trim(),
      'outfitRequirements': _outfitCtl.text.trim().isEmpty ? null : _outfitCtl.text.trim(),
      'shootingStart': _shootingStart != null ? Timestamp.fromDate(_shootingStart!) : null,
      'shootingEnd': _shootingEnd != null ? Timestamp.fromDate(_shootingEnd!) : null,
      'talentRequirements': talentReq,
      'status': _status,
      'media': _mediaUrls,
      'agencyId': agencyId,
      if (agencyName != null) 'agencyName': agencyName,
    };
    try {
      await _service.createCasting(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Casting created')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create casting: $e')));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Casting')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _descCtl, decoration: const InputDecoration(labelText: 'Description (brief)'), maxLines: 4),
          const SizedBox(height: 12),

          // Details
          const Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _locationCtl, decoration: const InputDecoration(labelText: 'Venue / Location')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _compMinCtl, decoration: const InputDecoration(labelText: 'Compensation min'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _compMaxCtl, decoration: const InputDecoration(labelText: 'Compensation max'))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _outfitCtl, decoration: const InputDecoration(labelText: 'Outfit requirements (optional)')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Shooting start: ${_shootingStart != null ? _shootingStart!.toLocal().toString().split('.').first : 'Not set'}')),
            TextButton(onPressed: () async {
              final dt = await _pickDateTime(context);
              if (dt != null) setState(() => _shootingStart = dt);
            }, child: const Text('Set')),
          ]),
          Row(children: [
            Expanded(child: Text('Shooting end: ${_shootingEnd != null ? _shootingEnd!.toLocal().toString().split('.').first : 'Not set'}')),
            TextButton(onPressed: () async {
              final dt = await _pickDateTime(context);
              if (dt != null) setState(() => _shootingEnd = dt);
            }, child: const Text('Set')),
          ]),
          const SizedBox(height: 12),

          // Talent requirements
          const Text('Talent requirements', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 8),
            DropdownButton<String>(value: _genderReq, items: const [DropdownMenuItem(value: 'any', child: Text('Any')), DropdownMenuItem(value: 'male', child: Text('Male')), DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'other', child: Text('Other'))], onChanged: (v) => setState(() => _genderReq = v!)),
            const SizedBox(width: 16),
            SizedBox(width: 110, child: TextField(decoration: const InputDecoration(labelText: 'Min age'), keyboardType: TextInputType.number, onChanged: (v) => _minAge = int.tryParse(v))),
            const SizedBox(width: 8),
            SizedBox(width: 110, child: TextField(decoration: const InputDecoration(labelText: 'Max age'), keyboardType: TextInputType.number, onChanged: (v) => _maxAge = int.tryParse(v))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _looksCtl, decoration: const InputDecoration(labelText: 'Looks / Style (comma separated)')),
          const SizedBox(height: 8),
          TextField(controller: _skillsCtl, decoration: const InputDecoration(labelText: 'Skills (comma separated)')),
          const SizedBox(height: 12),

          // Media
          Wrap(spacing: 8, children: _mediaUrls.map((u) => Image.network(u, height: 80, width: 80, fit: BoxFit.cover)).toList()),
          const SizedBox(height: 8),

          // Status
          Row(children: [
            const Text('Status: '),
            const SizedBox(width: 8),
            DropdownButton<String>(value: _status, items: const [DropdownMenuItem(value: 'open', child: Text('Open')), DropdownMenuItem(value: 'closed', child: Text('Closed')), DropdownMenuItem(value: 'filled', child: Text('Filled'))], onChanged: (v) => setState(() => _status = v!)),
          ]),

          const SizedBox(height: 8),
          Row(children: [ElevatedButton(onPressed: _saving ? null : _pickMedia, child: const Text('Add Media')), const SizedBox(width: 12), ElevatedButton(onPressed: _saving ? null : _submit, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publish'))]),
        ]),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date == null) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
