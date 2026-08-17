import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/gig_card.dart';
class PostGigPage extends StatefulWidget {
  const PostGigPage({super.key});

  @override
  State<PostGigPage> createState() => _PostGigPageState();
}

class _PostGigPageState extends State<PostGigPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  bool loading = false;
  double _scrollProgress = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollProgress);
  }

  void _updateScrollProgress() {
    final max = _scrollController.position.maxScrollExtent;
    final progress = max <= 0 ? 1.0 : (_scrollController.offset / max).clamp(0.0, 1.0);
    if ((progress - _scrollProgress).abs() > 0.005) {
      setState(() => _scrollProgress = progress);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    super.dispose();
  }

  // ================= BASIC CONTROLLERS =================
  final titleController = TextEditingController();
  final brandNameController = TextEditingController();
  final addressController = TextEditingController();
  final descriptionController = TextEditingController();
  final hoursController = TextEditingController();
  final budgetController = TextEditingController();
  final cityController = TextEditingController();
  final termsController = TextEditingController();
  final openingsController = TextEditingController();

  // ================= ROLE-SPECIFIC (MODEL) =================

  // General Requirements
  String gender = 'All';
  final ethnicityController = TextEditingController();
  bool tattoosAllowed = false;
  bool piercingsAllowed = false;

  // Physical Attributes
  RangeValues heightRange = const RangeValues(160, 180);
  RangeValues chestRange = const RangeValues(32, 38);
  RangeValues waistRange = const RangeValues(26, 32);
  RangeValues hipsRange = const RangeValues(34, 40);
  RangeValues shoulderRange = const RangeValues(34, 40);
  RangeValues inseamRange = const RangeValues(34, 40);
  final shoeController = TextEditingController();
  final List<String> skinOptions = [
  'Very Fair',
  'Fair',
  'Wheatish',
  'Dusky',
  'Dark',
  ];

  final List<String> eyeOptions = [
    'Black',
    'Brown',
    'Hazel',
    'Green',
    'Blue',
    'Grey',
  ];

  final List<String> hairOptions = [
    'Black',
    'Brown',
    'Blonde',
    'Red',
    'Grey',
    'White',
  ];
  final List<String> locationOptions = [
  'Mumbai',
  'Delhi',
  'Bangalore',
  'Hyderabad',
  'Chennai',
  'Pune',
  'Kolkata',
];

  List<String> selectedLocations = [];
  List<String> selectedSkin = [];
  List<String> selectedEyes = [];
  List<String> selectedHair = [];

  // ================= DROPDOWNS =================
  String projectType = 'Photoshoot';
  String timeline = 'Fixed';
  String budgetType = 'Fixed';
  String venueType = 'Public';
  String roleType = 'Model';

  // ================= SAVE / POST GIG =================
  Future<void> _saveGig({required String status}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final Map<String, dynamic> roleRequirements = {};

      if (roleType == 'Model') {
        roleRequirements['gender'] = gender;
        roleRequirements['ethnicity'] = ethnicityController.text.trim();
        roleRequirements['tattoos'] = tattoosAllowed;
        roleRequirements['piercings'] = piercingsAllowed;
        roleRequirements['physicalAttributes'] = {
          'height': {
            'min': heightRange.start.round(),
            'max': heightRange.end.round(),
          },
          'chest': {
            'min': chestRange.start.round(),
            'max': chestRange.end.round(),
          },
          'waist': {
            'min': waistRange.start.round(),
            'max': waistRange.end.round(),
          },
          'hips': {
            'min': hipsRange.start.round(),
            'max': hipsRange.end.round(),
          },
          'shoulderWidth': {
            'min': shoulderRange.start.round(),
            'max': shoulderRange.end.round(),
          },
          'inseam': {
            'min': inseamRange.start.round(),
            'max': inseamRange.end.round(),
          },
          'skinComplexion': selectedSkin,
          'eyeColor': selectedEyes,
          'hairColor': selectedHair,
        };
      }

      await FirebaseFirestore.instance.collection('gigs').add({
        'brandId': uid,
        'projectTitle': titleController.text.trim(),
        'projectType': projectType,
        'brandName': brandNameController.text.trim(),
        'officeAddress': addressController.text.trim(),
        'city': cityController.text.trim(),
        'jobLocations': selectedLocations,
        'venueVisibility': venueType,
        'description': descriptionController.text.trim(),
        'timeline': timeline,
        'durationHours': int.tryParse(hoursController.text.trim()) ?? 0,
        'budgetType': budgetType,
        'budgetAmount': budgetController.text.trim(),
        'terms': termsController.text.trim(),
        'roleType': roleType,
        'openings': int.tryParse(openingsController.text.trim()) ?? 1,
        'roleRequirements': roleRequirements,
        'applicationsCount': 0,
        'status': status, // 🔥 draft | open
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'draft'
                ? 'Gig saved as draft'
                : 'Gig posted successfully',
          ),
        ),
      );

      _formKey.currentState!.reset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save gig: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Post a gig'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _scrollProgress,
            minHeight: 3,
            backgroundColor: AppColors.line,
            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Project details'),
              AppCard(
                child: Column(children: [
                  _textField('Project title', titleController),
                  _dropdown(
                    label: 'Project type',
                    value: projectType,
                    items: const [
                      'Photoshoot',
                      'Video Shoot',
                      'Ramp Walk',
                      'Ad Campaign',
                    ],
                    onChanged: (v) => setState(() => projectType = v),
                  ),
                  _textField('Brand name', brandNameController, last: true),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              _section('Role details'),
              AppCard(
                child: Column(children: [
                  _dropdown(
                    label: 'Role type',
                    value: roleType,
                    items: const [
                      'Model',
                      'Influencer',
                      'Photographer',
                      'Fashion Designer',
                      'MUA',
                    ],
                    onChanged: (v) => setState(() => roleType = v),
                  ),
                  _textField(
                    'Number of openings',
                    openingsController,
                    keyboardType: TextInputType.number,
                    last: true,
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 🔥 CONDITIONAL MODEL SECTIONS
              if (roleType == 'Model') ...[
                _section('General requirements'),
                AppCard(
                  child: Column(children: [
                    _dropdown(
                      label: 'Gender',
                      value: gender,
                      items: const ['Male', 'Female', 'Transgender', 'All'],
                      onChanged: (v) => setState(() => gender = v),
                    ),
                    _textField('Ethnicity', ethnicityController),
                    _checkbox(
                      'Tattoos allowed',
                      tattoosAllowed,
                      (v) => setState(() => tattoosAllowed = v),
                    ),
                    _checkbox(
                      'Piercings allowed',
                      piercingsAllowed,
                      (v) => setState(() => piercingsAllowed = v),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),

                _section('Physical attributes'),
                AppCard(
                  child: Column(children: [
                    _rangeSlider(
                      label: 'Height',
                      values: heightRange,
                      min: 140,
                      max: 210,
                      divisions: 70,
                      unit: 'cm',
                      onChanged: (v) => setState(() => heightRange = v),
                    ),
                    _rangeSlider(
                      label: 'Chest / Bust',
                      values: chestRange,
                      min: 28,
                      max: 48,
                      divisions: 20,
                      unit: 'in',
                      onChanged: (v) => setState(() => chestRange = v),
                    ),
                    _rangeSlider(
                      label: 'Waist',
                      values: waistRange,
                      min: 22,
                      max: 40,
                      divisions: 18,
                      unit: 'in',
                      onChanged: (v) => setState(() => waistRange = v),
                    ),
                    _rangeSlider(
                      label: 'Hips',
                      values: hipsRange,
                      min: 30,
                      max: 48,
                      divisions: 18,
                      unit: 'in',
                      onChanged: (v) => setState(() => hipsRange = v),
                    ),
                    _rangeSlider(
                      label: 'Shoulder width',
                      values: shoulderRange,
                      min: 30,
                      max: 48,
                      divisions: 18,
                      unit: 'in',
                      onChanged: (v) => setState(() => shoulderRange = v),
                    ),
                    _rangeSlider(
                      label: 'Inseam',
                      values: inseamRange,
                      min: 30,
                      max: 48,
                      divisions: 18,
                      unit: 'in',
                      onChanged: (v) => setState(() => inseamRange = v),
                    ),
                    _textField('Shoe size (UK/US)', shoeController),
                    _multiSelectGrid(
                      title: 'Skin complexion',
                      options: skinOptions,
                      selected: selectedSkin,
                      onTap: (v) {
                        setState(() {
                          selectedSkin.contains(v) ? selectedSkin.remove(v) : selectedSkin.add(v);
                        });
                      },
                    ),
                    _multiSelectGrid(
                      title: 'Eye color',
                      options: eyeOptions,
                      selected: selectedEyes,
                      onTap: (v) {
                        setState(() {
                          selectedEyes.contains(v) ? selectedEyes.remove(v) : selectedEyes.add(v);
                        });
                      },
                    ),
                    _multiSelectGrid(
                      title: 'Hair color',
                      options: hairOptions,
                      selected: selectedHair,
                      onTap: (v) {
                        setState(() {
                          selectedHair.contains(v) ? selectedHair.remove(v) : selectedHair.add(v);
                        });
                      },
                      last: true,
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              _section('Company location'),
              AppCard(
                child: Column(children: [
                  _textField('Office address', addressController),
                  _textField('Office city', cityController, last: true),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              _section('Job location'),
              AppCard(
                child: Column(children: [
                  _multiSelectGrid(
                    title: 'Select cities',
                    options: locationOptions,
                    selected: selectedLocations,
                    onTap: (v) {
                      setState(() {
                        selectedLocations.contains(v) ? selectedLocations.remove(v) : selectedLocations.add(v);
                      });
                    },
                  ),
                  _dropdown(
                    label: 'Venue visibility',
                    value: venueType,
                    items: const ['Public', 'Reveal after booking'],
                    onChanged: (v) => setState(() => venueType = v),
                    last: true,
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              _section('Job description'),
              AppCard(
                child: _textField('Description', descriptionController, maxLines: 5, last: true),
              ),
              const SizedBox(height: AppSpacing.lg),

              _section('Timeline & duration'),
              AppCard(
                child: Column(children: [
                  _dropdown(
                    label: 'Timeline',
                    value: timeline,
                    items: const ['Fixed', 'Tentative'],
                    onChanged: (v) => setState(() => timeline = v),
                  ),
                  _textField(
                    'Job duration (hours)',
                    hoursController,
                    keyboardType: TextInputType.number,
                    last: true,
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              _section('Budget'),
              AppCard(
                child: Column(children: [
                  _dropdown(
                    label: 'Budget type',
                    value: budgetType,
                    items: const ['Fixed', 'Hourly', 'Range'],
                    onChanged: (v) => setState(() => budgetType = v),
                  ),
                  _textField(
                    'Budget amount',
                    budgetController,
                    keyboardType: TextInputType.number,
                    last: true,
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.lg),

              _section('Terms & usage'),
              AppCard(
                child: _textField(
                  'Terms, rights & usage',
                  termsController,
                  maxLines: 4,
                  last: true,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ================= CTAs =================
              // Post Gig reads as the primary action; Draft/Preview are
              // secondary, lower-emphasis actions below it.
              AppButton(
                label: 'Post gig',
                expand: true,
                loading: loading,
                onPressed: loading ? null : () => _saveGig(status: 'open'),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Save as draft',
                      variant: AppButtonVariant.secondary,
                      onPressed: loading ? null : () => _saveGig(status: 'draft'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: AppButton(
                      label: 'Preview',
                      variant: AppButtonVariant.ghost,
                      onPressed: _previewGig,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm + 2),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.3),
        ),
      );

  Widget _textField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (v) =>
            v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items
            .map((e) =>
                DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v!),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _checkbox(
      String label, bool value, Function(bool) onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v!),
      title: Text(label),
      activeColor: AppColors.ink,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _rangeSlider({
  required String label,
  required RangeValues values,
  required double min,
  required double max,
  required int divisions,
  required String unit,
  required Function(RangeValues) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${values.start.round()} – ${values.end.round()} $unit',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.ink),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.ink,
              inactiveTrackColor: AppColors.line,
              thumbColor: AppColors.ink,
              overlayColor: AppColors.ink.withValues(alpha: 0.1),
              valueIndicatorColor: AppColors.ink,
            ),
            child: RangeSlider(
              values: values,
              min: min,
              max: max,
              divisions: divisions,
              labels: RangeLabels(
                '${values.start.round()}',
                '${values.end.round()}',
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
  Widget _multiSelectGrid({
    required String title,
    required List<String> options,
    required List<String> selected,
    required Function(String) onTap,
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selected.contains(option);

              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => onTap(option),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.goldBg : AppColors.paperRaised,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppColors.line,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.gold : AppColors.inkSoft,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _previewGig() {
  final Map<String, dynamic> physicalAttributes = {};

  if (roleType == 'Model') {
    physicalAttributes.addAll({
      'height': {
        'min': heightRange.start.round(),
        'max': heightRange.end.round(),
      },
      'chest': {
        'min': chestRange.start.round(),
        'max': chestRange.end.round(),
      },
      'waist': {
        'min': waistRange.start.round(),
        'max': waistRange.end.round(),
      },
      'hips': {
        'min': hipsRange.start.round(),
        'max': hipsRange.end.round(),
      },
      'shoulderWidth': {
        'min': shoulderRange.start.round(),
        'max': shoulderRange.end.round(),
      },
      'inseam': {
        'min': inseamRange.start.round(),
        'max': inseamRange.end.round(),
      },
    });
  }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: GigCard(
          projectTitle: titleController.text,
          description: descriptionController.text,

          // 🔥 SAME STRUCTURE AS MANAGE GIGS
          physicalAttributes: physicalAttributes,
          eyeColors: selectedEyes,
          hairColors: selectedHair,
          skinComplexion: selectedSkin,

          timeline: timeline,
          durationHours:
              int.tryParse(hoursController.text) ?? 0,
          budgetType: budgetType,
          budgetAmount: budgetController.text,

          applications: 0,
          status: 'Draft',
          createdAt: DateTime.now(), // preview = now
        ),
      ),
    );
  }
}
