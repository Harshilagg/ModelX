import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/gig_card.dart';
class PostGigPage extends StatefulWidget {
  const PostGigPage({super.key});

  @override
  State<PostGigPage> createState() => _PostGigPageState();
}

class _PostGigPageState extends State<PostGigPage> {
  final _formKey = GlobalKey<FormState>();
  bool loading = false;

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

  // ================= POST GIG =================
  Future<void> _postGig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final Map<String, dynamic> roleRequirements = {};

      // 🔥 ONLY ADD WHEN ROLE = MODEL
      if (roleType == 'Model') {
        roleRequirements['gender'] = gender;
        roleRequirements['ethnicity'] =
            ethnicityController.text.trim();
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
          'shoeSize': shoeController.text.trim(),
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
        'companyLocation': {
          'address': addressController.text.trim(),
          'city': cityController.text.trim(),
        },
        'jobLocations': selectedLocations,
        'venueVisibility': venueType,
        'description': descriptionController.text.trim(),
        'timeline': timeline,
        'durationHours':
            int.tryParse(hoursController.text.trim()) ?? 0,
        'budgetType': budgetType,
        'budgetAmount': budgetController.text.trim(),
        'terms': termsController.text.trim(),

        // ROLE DETAILS
        'roleType': roleType,
        'openings':
            int.tryParse(openingsController.text.trim()) ?? 1,
        'roleRequirements': roleRequirements,
        'applicationsCount': 0,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gig posted successfully')),
      );

      _formKey.currentState!.reset();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post gig')),
      );
    } finally {
      setState(() => loading = false);
    }
  }

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
    } finally {
      setState(() => loading = false);
    }
  }


  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _title('Post a Gig'),

              _section('Project Details'),
              _textField('Project Title', titleController),
              _dropdown(
                label: 'Project Type',
                value: projectType,
                items: const [
                  'Photoshoot',
                  'Video Shoot',
                  'Ramp Walk',
                  'Ad Campaign',
                ],
                onChanged: (v) => setState(() => projectType = v),
              ),
              _textField('Brand Name', brandNameController),

              _section('Role Details'),
              _dropdown(
                label: 'Role Type',
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
                'Number of Openings',
                openingsController,
                keyboardType: TextInputType.number,
              ),

              // 🔥 CONDITIONAL MODEL SECTIONS
              if (roleType == 'Model') ...[
                _section('General Requirements'),
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

                _section('Physical Attributes'),
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
                label: 'Shoulder Width',
                values: shoulderRange,
                min: 30,
                max: 48,
                divisions: 18,
                unit: 'in',
                onChanged: (v) => setState(() => shoulderRange = v),
              ),
              _rangeSlider(
                label: ' Inseam',
                values: inseamRange,
                min: 30,
                max: 48,
                divisions: 18,
                unit: 'in',
                onChanged: (v) => setState(() => inseamRange = v),
              ),

                _textField('Shoe Size (UK/US)', shoeController),
                _multiSelectGrid(
                title: 'Skin Complexion',
                options: skinOptions,
                selected: selectedSkin,
                onTap: (v) {
                  setState(() {
                    selectedSkin.contains(v)
                        ? selectedSkin.remove(v)
                        : selectedSkin.add(v);
                  });
                },
              ),

              _multiSelectGrid(
                title: 'Eye Color',
                options: eyeOptions,
                selected: selectedEyes,
                onTap: (v) {
                  setState(() {
                    selectedEyes.contains(v)
                        ? selectedEyes.remove(v)
                        : selectedEyes.add(v);
                  });
                },
              ),

              _multiSelectGrid(
                title: 'Hair Color',
                options: hairOptions,
                selected: selectedHair,
                onTap: (v) {
                  setState(() {
                    selectedHair.contains(v)
                        ? selectedHair.remove(v)
                        : selectedHair.add(v);
                  });
                },
              ),
              ],
              _section('Company Location'),
              _textField('Office Address', addressController),
              _textField('Office City', cityController),
              _section('Job Location'),

              _multiSelectGrid(
                title: 'Select Cities',
                options: locationOptions,
                selected: selectedLocations,
                onTap: (v) {
                  setState(() {
                    selectedLocations.contains(v)
                        ? selectedLocations.remove(v)
                        : selectedLocations.add(v);
                  });
                },
              ),

              _dropdown(
                label: 'Venue Visibility',
                value: venueType,
                items: const ['Public', 'Reveal after booking'],
                onChanged: (v) => setState(() => venueType = v),
              ),
            
              _section('Job Description'),
              _textField('Description', descriptionController, maxLines: 5),

              _section('Timeline & Duration'),
              _dropdown(
                label: 'Timeline',
                value: timeline,
                items: const ['Fixed', 'Tentative'],
                onChanged: (v) => setState(() => timeline = v),
              ),
              _textField(
                'Job Duration (hours)',
                hoursController,
                keyboardType: TextInputType.number,
              ),

              _section('Budget'),
              _dropdown(
                label: 'Budget Type',
                value: budgetType,
                items: const ['Fixed', 'Hourly', 'Range'],
                onChanged: (v) => setState(() => budgetType = v),
              ),
              _textField(
                'Budget Amount',
                budgetController,
                keyboardType: TextInputType.number,
              ),

              _section('Terms & Usage'),
              _textField(
                'Terms, rights & usage',
                termsController,
                maxLines: 4,
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _ctaButton(
                      label: 'Draft',
                      filled: true,
                      onPressed: loading ? null : () => _saveGig(status: 'draft'),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: _ctaButton(
                      label: 'Preview',
                      filled: true,
                      onPressed: _previewGig,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: _ctaButton(
                      label: 'Post Gig',
                      filled: true,
                      loading: loading,
                      onPressed: loading ? null : () => _saveGig(status: 'open'),
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

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );

  Widget _textField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (v) =>
            v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((e) =>
                DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => onChanged(v!),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _checkbox(
      String label, bool value, Function(bool) onChanged) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v!),
      title: Text(label),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${values.start.round()} – ${values.end.round()} $unit',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          RangeSlider(
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
        ],
      ),
    );
  }
  Widget _multiSelectGrid({
    required String title,
    required List<String> options,
    required List<String> selected,
    required Function(String) onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 🔥 3 per row
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selected.contains(option);

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onTap(option),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.withOpacity(0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade400,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color:
                          isSelected ? Colors.blue : Colors.grey.shade800,
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
      backgroundColor: const Color(0xFFF9FAFB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
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


  Widget _ctaButton({
  required String label,
  required VoidCallback? onPressed,
  bool filled = false,
  bool loading = false,
}) {
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  if (filled) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: shape,
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: shape,
          side: BorderSide(color: Colors.grey.shade400),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
