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
    const primaryNavy = Color(0xFF0F172A);
    const accentBlue = Colors.blueAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Create Casting', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: primaryNavy,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ================= BASIC INFO =================
          _sectionHeader('Basic Information'),
          _card(Column(children: [
            _textField(_titleCtl, 'Job Title', Icons.work_outline),
            const SizedBox(height: 16),
            _textField(_descCtl, 'Description', Icons.description_outlined, maxLines: 4),
          ])),

          const SizedBox(height: 24),

          // ================= GIG DETAILS =================
          _sectionHeader('Gig Details'),
          _card(Column(children: [
            _textField(_locationCtl, 'Location / Venue', Icons.location_on_outlined),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _textField(_compMinCtl, 'Min Pay', Icons.payments_outlined, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _textField(_compMaxCtl, 'Max Pay', Icons.payments_outlined, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            _textField(_outfitCtl, 'Outfit Requirements', Icons.checkroom_outlined),
          ])),

          const SizedBox(height: 24),

          // ================= SHOOTING DATES =================
          _sectionHeader('Project Timeline'),
          _card(Column(children: [
            _dateTile('Shooting Starts', _shootingStart, () async {
              final dt = await _pickDateTime(context);
              if (dt != null) setState(() => _shootingStart = dt);
            }),
            const Divider(height: 24),
            _dateTile('Shooting Ends', _shootingEnd, () async {
              final dt = await _pickDateTime(context);
              if (dt != null) setState(() => _shootingEnd = dt);
            }),
          ])),

          const SizedBox(height: 24),

          // ================= TALENT REQUISITES =================
          _sectionHeader('Talent Requirements'),
          _card(Column(children: [
             Row(children: [
              const Icon(Icons.wc, color: Colors.grey, size: 22),
              const SizedBox(width: 12),
              const Text('Gender: ', style: TextStyle(color: Colors.grey)),
              const Spacer(),
              DropdownButton<String>(
                value: _genderReq,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('Any')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other'))
                ],
                onChanged: (v) => setState(() => _genderReq = v!),
              ),
            ]),
            const Divider(height: 16),
            Row(children: [
              Expanded(child: _textField(null, 'Min Age', Icons.calendar_today_outlined, keyboardType: TextInputType.number, initialValue: _minAge?.toString(), onChanged: (v) => _minAge = int.tryParse(v))),
              const SizedBox(width: 12),
              Expanded(child: _textField(null, 'Max Age', Icons.calendar_today_outlined, keyboardType: TextInputType.number, initialValue: _maxAge?.toString(), onChanged: (v) => _maxAge = int.tryParse(v))),
            ]),
            const SizedBox(height: 16),
            _textField(_looksCtl, 'Preferred Looks (comma separated)', Icons.face_outlined),
            const SizedBox(height: 16),
            _textField(_skillsCtl, 'Required Skills (comma separated)', Icons.star_border),
          ])),

          const SizedBox(height: 24),

          // ================= MEDIA =================
          _sectionHeader('Casting Assets'),
          if (_mediaUrls.isNotEmpty)
            Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _mediaUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_mediaUrls[i], height: 100, width: 100, fit: BoxFit.cover),
                ),
              ),
            ),
          
          ElevatedButton.icon(
            onPressed: _saving ? null : _pickMedia,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add Reference Media'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryNavy,
              elevation: 0,
              side: BorderSide(color: Colors.grey.shade200),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 32),

          // ================= SUBMIT =================
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: primaryNavy.withOpacity(0.3),
              ),
              child: _saving 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text('Publish Casting Call', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    ),
    child: child,
  );

  Widget _textField(TextEditingController? ctl, String label, IconData icon, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? initialValue, Function(String)? onChanged}) => TextFormField(
    controller: ctl,
    initialValue: initialValue,
    onChanged: onChanged,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    ),
  );

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Row(children: [
      const Icon(Icons.calendar_month, color: Colors.grey, size: 22),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value != null ? value.toLocal().toString().split('.').first : 'Not Set', style: TextStyle(fontWeight: FontWeight.w600, color: value != null ? Colors.black : Colors.grey)),
      ]),
      const Spacer(),
      const Icon(Icons.edit_calendar_outlined, size: 18, color: Colors.blueAccent),
    ]),
  );

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date == null) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
