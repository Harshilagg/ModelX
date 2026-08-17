import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cloudinary_service.dart';
import '../../ui/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'casting_service.dart';

class CreateCastingPage extends StatefulWidget {
  const CreateCastingPage({super.key});

  @override
  State<CreateCastingPage> createState() => _CreateCastingPageState();
}

class _CreateCastingPageState extends State<CreateCastingPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  final _compMinCtl = TextEditingController();
  final _compMaxCtl = TextEditingController();
  final _reqCtl = TextEditingController();
  final _outfitCtl = TextEditingController();
  DateTime? _shootingStart;
  DateTime? _shootingEnd;
  String _genderReq = 'any';
  int? _minAge;
  int? _maxAge;
  final String _status = 'open';
  final _picker = ImagePicker();
  final _service = CastingService();
  List<String> _mediaUrls = [];
  bool _saving = false;

  // Preferred looks / required skills are now a chip-based multiselect
  // instead of free-form comma-separated text — see report for the
  // talentRequirements.looks shape change (String -> List<String>).
  static const _lookOptions = [
    'Editorial',
    'Commercial',
    'High Fashion',
    'Glamour',
    'Athletic',
    'Classic',
    'Alternative',
    'Exotic',
  ];
  static const _skillOptions = [
    'Runway Walk',
    'Posing',
    'Acting',
    'Dance',
    'Voice Over',
    'Swimming',
    'Sports',
    'Yoga',
  ];
  final List<String> _selectedLooks = [];
  final List<String> _selectedSkills = [];

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _locationCtl.dispose();
    _compMinCtl.dispose();
    _compMaxCtl.dispose();
    _reqCtl.dispose();
    _outfitCtl.dispose();
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
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the required fields')),
      );
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

    // NOTE: `looks` is now written as a List<String> (from the chip
    // multiselect) instead of a single comma-joined string. See report.
    final talentReq = {
      'gender': _genderReq,
      if (_minAge != null) 'minAge': _minAge,
      if (_maxAge != null) 'maxAge': _maxAge,
      if (_selectedLooks.isNotEmpty) 'looks': _selectedLooks,
      if (_selectedSkills.isNotEmpty) 'skills': _selectedSkills,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Casting created')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create casting: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Create Casting')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ================= BASIC INFO =================
            _sectionHeader('Basic information'),
            AppCard(
              child: Column(children: [
                _textField(_titleCtl, 'Job title', Icons.work_outline, required: true),
                const SizedBox(height: AppSpacing.md),
                _textField(_descCtl, 'Description', Icons.description_outlined, maxLines: 4, required: true),
              ]),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ================= GIG DETAILS =================
            _sectionHeader('Gig details'),
            AppCard(
              child: Column(children: [
                _textField(_locationCtl, 'Location / venue', Icons.location_on_outlined, required: true),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(child: _textField(_compMinCtl, 'Min pay', Icons.payments_outlined, keyboardType: TextInputType.number)),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(child: _textField(_compMaxCtl, 'Max pay', Icons.payments_outlined, keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: AppSpacing.md),
                _textField(_outfitCtl, 'Outfit requirements', Icons.checkroom_outlined),
              ]),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ================= SHOOTING DATES =================
            _sectionHeader('Project timeline'),
            AppCard(
              child: Column(children: [
                _dateTile('Shooting starts', _shootingStart, () async {
                  final dt = await _pickDateTime(context);
                  if (dt != null) setState(() => _shootingStart = dt);
                }),
                const Divider(height: AppSpacing.lg),
                _dateTile('Shooting ends', _shootingEnd, () async {
                  final dt = await _pickDateTime(context);
                  if (dt != null) setState(() => _shootingEnd = dt);
                }),
              ]),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ================= TALENT REQUISITES =================
            _sectionHeader('Talent requirements'),
            AppCard(
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.wc_rounded, color: AppColors.inkFaint, size: 22),
                  const SizedBox(width: AppSpacing.sm + 4),
                  const Text('Gender', style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _genderReq,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'any', child: Text('Any')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _genderReq = v!),
                  ),
                ]),
                const Divider(height: AppSpacing.lg),
                Row(children: [
                  Expanded(
                    child: _textField(
                      null,
                      'Min age',
                      Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      initialValue: _minAge?.toString(),
                      onChanged: (v) => _minAge = int.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: _textField(
                      null,
                      'Max age',
                      Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      initialValue: _maxAge?.toString(),
                      onChanged: (v) => _maxAge = int.tryParse(v),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),
                _chipMultiSelect('Preferred looks', _lookOptions, _selectedLooks),
                const SizedBox(height: AppSpacing.lg),
                _chipMultiSelect('Required skills', _skillOptions, _selectedSkills),
              ]),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ================= MEDIA =================
            _sectionHeader('Casting assets'),
            if (_mediaUrls.isNotEmpty)
              Container(
                height: 100,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _mediaUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.network(_mediaUrls[i], height: 100, width: 100, fit: BoxFit.cover),
                  ),
                ),
              ),
            AppButton(
              label: 'Add reference media',
              icon: Icons.add_a_photo_outlined,
              variant: AppButtonVariant.secondary,
              expand: true,
              onPressed: _saving ? null : _pickMedia,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ================= SUBMIT =================
            AppButton(
              label: 'Publish casting call',
              expand: true,
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm + 2),
        child: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.3),
        ),
      );

  Widget _textField(
    TextEditingController? ctl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? initialValue,
    Function(String)? onChanged,
    bool required = false,
  }) =>
      TextFormField(
        controller: ctl,
        initialValue: ctl == null ? initialValue : null,
        onChanged: onChanged,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: Icon(icon, size: 20),
        ),
      );

  Widget _chipMultiSelect(String title, List<String> options, List<String> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: AppSpacing.sm + 2),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) => setState(() {
                isSelected ? selected.remove(option) : selected.add(option);
              }),
              showCheckmark: false,
              backgroundColor: AppColors.paperRaised,
              selectedColor: AppColors.goldBg,
              side: BorderSide(color: isSelected ? Colors.transparent : AppColors.line),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.gold : AppColors.inkSoft,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded, color: AppColors.inkFaint, size: 22),
          const SizedBox(width: AppSpacing.sm + 4),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.inkFaint, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value != null ? value.toLocal().toString().split('.').first : 'Not set',
              style: TextStyle(fontWeight: FontWeight.w600, color: value != null ? AppColors.ink : AppColors.inkFaint),
            ),
          ]),
          const Spacer(),
          const Icon(Icons.edit_calendar_outlined, size: 18, color: AppColors.gold),
        ]),
      );

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date == null) return null;
    if (!context.mounted) return date;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
