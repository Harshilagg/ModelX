import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'connected_users_page.dart';
import 'user_profile_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';
import '../agency/scouting/ai_scout_service.dart'; // Import AI Service
import '../widgets/profile_avatar.dart';
import '../widgets/profile_stats.dart';
import 'create_post_page.dart';
import '../widgets/portfolio_grid.dart';
import '../widgets/model_x_copilot.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // Basic info
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // Model-specific info
  final TextEditingController ageController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController measurementsController = TextEditingController();
  final TextEditingController skillsController = TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController availabilityController = TextEditingController();
  final TextEditingController achievementsController = TextEditingController();
  final TextEditingController preferredWorkController = TextEditingController();
  final TextEditingController taglineController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // Followers / following
  int followersCount = 0;
  int followingCount = 0;

  // Additional physical attributes
  final TextEditingController skinColorController = TextEditingController();
  final TextEditingController waistController = TextEditingController();
  final TextEditingController hipsController = TextEditingController();
  final TextEditingController shoeSizeController = TextEditingController();
  String heightUnit = 'cm';
  String shoeSizeUnit = 'US';
  final TextEditingController eyeColorController = TextEditingController();
  final TextEditingController hairColorController = TextEditingController();
  final TextEditingController tattoosController = TextEditingController();
  final TextEditingController shoulderWidthController = TextEditingController();
  final TextEditingController piercingController = TextEditingController();

  // Projects & agencies
  final TextEditingController projectsController = TextEditingController();
  final TextEditingController agenciesController = TextEditingController();

  bool loading = false;
  bool _isLoading = true;
  String profileImageUrl = '';
  String username = '';
  File? pickedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
          setState(() {
            // Prefer fullName; fall back to firstName/lastName if needed
            if (data['fullName'] != null) {
              fullNameController.text = data['fullName'];
            } else if (data['firstName'] != null || data['lastName'] != null) {
              fullNameController.text = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
            } else {
              fullNameController.text = '';
            }
            contactController.text = data['contact'] ?? '';
            emailController.text = data['email'] ?? '';
            bioController.text = data['bio'] ?? '';
            profileImageUrl = data['profileImage'] ?? '';

          // Model-specific
          ageController.text = data['age'] ?? '';
          genderController.text = data['gender'] ?? '';
          heightController.text = data['height'] ?? '';
          heightUnit = data['heightUnit'] ?? 'cm';
          weightController.text = data['weight'] ?? '';
          measurementsController.text = data['measurements'] ?? '';
          skillsController.text = data['skills'] ?? '';
          experienceController.text = data['experience'] ?? '';
          availabilityController.text = data['availability'] ?? '';
          achievementsController.text = data['achievements'] ?? '';
          preferredWorkController.text = data['preferredWork'] ?? '';
          taglineController.text = data['tagline'] ?? '';
          locationController.text = data['location'] ?? '';
        });
          username = data['username'] ?? (data['fullName'] ?? '');

          // followers / following
          followersCount = (data['followers'] is List) ? (data['followers'] as List).length : (data['followers'] is int ? data['followers'] : 0);
          followingCount = (data['following'] is List) ? (data['following'] as List).length : (data['following'] is int ? data['following'] : 0);

          // Additional attributes
          skinColorController.text = data['skinColor'] ?? '';
          waistController.text = data['waist']?.toString() ?? '';
          hipsController.text = data['hips']?.toString() ?? '';
          shoeSizeController.text = data['shoeSize']?.toString() ?? '';
          shoeSizeUnit = data['shoeSizeUnit'] ?? 'US';
          eyeColorController.text = data['eyeColor'] ?? '';
          hairColorController.text = data['hairColor'] ?? '';
          tattoosController.text = data['tattoos'] ?? '';
          shoulderWidthController.text = data['shoulderWidth']?.toString() ?? '';
          piercingController.text = data['piercing'] ?? '';

          projectsController.text = (data['projects'] is List) ? (data['projects'] as List).join('\n') : (data['projects'] ?? '');
          agenciesController.text = (data['agencies'] is List) ? (data['agencies'] as List).join('\n') : (data['agencies'] ?? '');
      }
    } catch (e) {
      debugPrint("🔥 Error loading user data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> pickAndUploadImage() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 70,
  );

  if (pickedFile == null) return;

  final user = _auth.currentUser!;
  final imageFile = File(pickedFile.path);

  final imageUrl = await CloudinaryService.uploadProfileImage(
    imageFile,
    user.uid,
  );

  if (imageUrl == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Upload failed")),
    );
    return;
  }

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'profileImage': imageUrl,
  }, SetOptions(merge: true));

  setState(() {
    profileImageUrl = imageUrl;
  });
}

  void saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => loading = true);
      final user = _auth.currentUser!;
      final profileData = {
        'fullName': fullNameController.text.trim(),
        'fullNameLower': fullNameController.text.trim().toLowerCase(),
        'location': locationController.text.trim(),
        'contact': contactController.text.trim(),
        'email': emailController.text.trim(),
        'bio': bioController.text.trim(),
        'profileImage': profileImageUrl.isNotEmpty ? profileImageUrl : null,
        'age': ageController.text.trim(),
        'gender': genderController.text.trim(),
        'height': heightController.text.trim(),
        'weight': weightController.text.trim(),
        'measurements': measurementsController.text.trim(),
        'skills': skillsController.text.trim(),
        'experience': experienceController.text.trim(),
        'availability': availabilityController.text.trim(),
        'achievements': achievementsController.text.trim(),
        'preferredWork': preferredWorkController.text.trim(),
        'tagline': taglineController.text.trim(),
        'heightUnit': heightUnit,
        'shoeSizeUnit': shoeSizeUnit,
        'usernameLower': username.trim().isNotEmpty ? username.trim().toLowerCase() : null,
        'skinColor': skinColorController.text.trim(),
        'waist': waistController.text.trim(),
        'hips': hipsController.text.trim(),
        'shoeSize': shoeSizeController.text.trim(),
        'eyeColor': eyeColorController.text.trim(),
        'hairColor': hairColorController.text.trim(),
        'tattoos': tattoosController.text.trim(),
        'shoulderWidth': shoulderWidthController.text.trim(),
        'piercing': piercingController.text.trim(),
        'projects': projectsController.text.trim().isEmpty ? null : projectsController.text.trim().split('\n'),
        'agencies': agenciesController.text.trim().isEmpty ? null : agenciesController.text.trim().split('\n'),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(profileData, SetOptions(merge: true));
      
      // AUTO-SYNC: Update AI Vector Index in background
      AiScoutService().indexProfile(user.uid, profileData).catchError((e) {
        debugPrint('AI Sync failed: $e');
      });

      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
      _loadUserData();
    }
  }

  void logout() async {
  await _auth.signOut();
  // After sign out, go to LoginPage and clear stack so user can log in or create account
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (Route<dynamic> route) => false,
  );
}


  // -------------------- Helper Widgets --------------------
  Widget _infoCard(String title, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.paperRaised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkFaint,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.trim().isEmpty ? "—" : value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    ),
  );
}

  Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
  );
}

Widget _sectionCard({required Widget child}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: AppCard(
      padding: const EdgeInsets.all(18),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

// Removed legacy _statItem in favor of `ProfileStats` widget.

// Legacy _chip removed; UI uses Section cards and ProfileStats widget.

Widget _bulletBlock(String title, String value) {
  if (value.trim().isEmpty) return const SizedBox();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.inkSoft,
          height: 1.6,
          fontSize: 14,
        ),
      ),
    ],
  );
}

Widget _contactRow(IconData icon, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.gold),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}


  // -------------------- Edit Profile Modal --------------------
  void _showEditProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Edit Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),

                // Basic info
                TextField(controller: fullNameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: bioController, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 16),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: genderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    hintText: 'Male / Female / Other',
                    border: OutlineInputBorder(),
                  ),
                ),
                // Physical attributes grid
                Align(alignment: Alignment.centerLeft, child: Text('Physical Attributes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: heightController,
                        decoration: InputDecoration(
                          labelText: 'Height',
                          border: const OutlineInputBorder(),
                          suffixIcon: SizedBox(
                            width: 80,
                            child: DropdownButton<String>(
                              value: heightUnit,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(value: 'cm', child: Text('cm')),
                                DropdownMenuItem(value: 'in', child: Text('in')),
                                DropdownMenuItem(value: 'ft', child: Text('ft')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => heightUnit = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 120, child: TextField(controller: waistController, decoration: const InputDecoration(labelText: 'Waist (cm)', border: OutlineInputBorder()))),
                    SizedBox(width: 120, child: TextField(controller: hipsController, decoration: const InputDecoration(labelText: 'Hips (cm)', border: OutlineInputBorder()))),
                    SizedBox(width: 120, child: TextField(controller: shoulderWidthController, decoration: const InputDecoration(labelText: 'Shoulder (cm)', border: OutlineInputBorder()))),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: skinColorController,
                        decoration: const InputDecoration(
                          labelText: 'Skin Tone',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: shoeSizeController,
                        decoration: InputDecoration(
                          labelText: 'Shoe Size',
                          border: const OutlineInputBorder(),
                          suffixIcon: SizedBox(
                            width: 80,
                            child: DropdownButton<String>(
                              value: shoeSizeUnit,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(value: 'US', child: Text('US')),
                                DropdownMenuItem(value: 'EU', child: Text('EU')),
                                DropdownMenuItem(value: 'UK', child: Text('UK')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => shoeSizeUnit = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 140, child: TextField(controller: weightController, decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()))),
                    SizedBox(width: 140, child: TextField(controller: eyeColorController, decoration: const InputDecoration(labelText: 'Eye Color', border: OutlineInputBorder()))),
                    SizedBox(width: 140, child: TextField(controller: hairColorController, decoration: const InputDecoration(labelText: 'Hair Color', border: OutlineInputBorder()))),
                    SizedBox(width: 200, child: TextField(controller: tattoosController, decoration: const InputDecoration(labelText: 'Tattoos (describe)', border: OutlineInputBorder()))),
                    SizedBox(width: 200, child: TextField(controller: piercingController, decoration: const InputDecoration(labelText: 'Piercing (describe)', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 16),

                // Projects & Agencies
                Align(alignment: Alignment.centerLeft, child: Text('Experience', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkSoft))),
                const SizedBox(height: 8),
                TextField(controller: projectsController, decoration: const InputDecoration(labelText: 'Projects (one per line)', border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 12),
                TextField(controller: agenciesController, decoration: const InputDecoration(labelText: 'Agency associations (one per line)', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 16),

                // ================= PROFESSIONAL DETAILS =================
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Professional Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: skillsController,
                  decoration: const InputDecoration(
                    labelText: 'Skills (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),


                TextField(
                  controller: preferredWorkController,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Work',
                    hintText: 'Runway, commercial, shoots, etc.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: availabilityController,
                  decoration: const InputDecoration(
                    labelText: 'Availability',
                    hintText: 'Full-time, freelance, weekends',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: achievementsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Achievements',
                    hintText: 'Awards, features, notable wins',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                AppButton(
                  label: "Save Changes",
                  variant: AppButtonVariant.primary,
                  expand: true,
                  onPressed: () {
                    saveProfile();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // -------------------- Portfolio Upload --------------------
  Future<void> _uploadPortfolioMedia() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  if (pickedFile == null) return;

  final user = _auth.currentUser!;
  final file = File(pickedFile.path);

  final publicId =
      "portfolio/${user.uid}_${DateTime.now().millisecondsSinceEpoch}";

  final imageUrl = await CloudinaryService.uploadPortfolioImage(
    file,
    publicId,
  );

  if (imageUrl == null) return;

  await FirebaseFirestore.instance.collection('portfolio').add({
    'uid': user.uid,
    'mediaUrl': imageUrl,
    'mediaType': 'image',
    'cloudinaryPublicId': publicId, 
    'timestamp': FieldValue.serverTimestamp(),
    'isPublic': true,
  });
}

      Future<void> _deletePortfolioItem(DocumentSnapshot mediaDoc) async {
        try {
          final data = mediaDoc.data() as Map<String, dynamic>;
          final publicId = data['cloudinaryPublicId'];

          if (publicId != null) {
            await CloudinaryService.deleteImage(publicId);
          }

          await FirebaseFirestore.instance
              .collection('portfolio')
              .doc(mediaDoc.id)
              .delete();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Portfolio image deleted")),
          );
        } catch (e) {
          debugPrint("🔥 Delete failed: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete image")),
          );
        }
      }


  void _viewMediaFullScreen(String url, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent),
          body: Center(
            child: type == "image"
                ? Image.network(url)
                : const Icon(Icons.play_circle_fill, size: 80, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _showFollowersList() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    final followers = data['followers'] ?? [];

    final List<Map<String, dynamic>> followerData = [];
    for (var fid in followers) {
      try {
        final fdoc = await FirebaseFirestore.instance.collection('users').doc(fid).get();
        if (fdoc.exists && fdoc.data() != null) {
          final d = fdoc.data()!;
          d['uid'] = fid;
          followerData.add(d);
        }
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: followerData.length,
        itemBuilder: (context, index) {
          final f = followerData[index];
          return ListTile(
            leading: ProfileAvatar(
              imageUrl: f['profileImage'],
              name: f['fullName'] ?? '${f['firstName'] ?? ''} ${f['lastName'] ?? ''}',
              size: 40,
            ),
            title: Text(f['fullName'] ?? '${f['firstName'] ?? ''} ${f['lastName'] ?? ''}'),
            subtitle: f['username'] != null ? Text('@${f['username']}') : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(uid: f['uid'])));
            },
          );
        },
      ),
    );
  }
  
  // -------------------- Build --------------------
// -------------------- Build --------------------
PreferredSizeWidget _buildAppBar() {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    title: const Text(
      "Profile",
      style: TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.logout, color: AppColors.ink),
        onPressed: logout,
      ),
    ],
  );
}

@override
Widget build(BuildContext context) {
  if (_isLoading) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: _buildAppBar(),
      body: const LoadingState(),
    );
  }

  return Scaffold(
    backgroundColor: AppColors.paper,

    appBar: _buildAppBar(),
    floatingActionButton: ModelXCopilot(
      pageContext: {
        'page': 'profile',
        'role': 'Model',
        'profileData': {
          'bio': bioController.text,
          'skills': skillsController.text,
          'experience': experienceController.text,
        }
      },
    ),

    body: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ================= HERO =================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              children: [
                // Modern card-style hero area
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0,6))],
                  ),
                  child: Column(
                    children: [
                      // cover strip
                      Container(height: 12, decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(16)), color: AppColors.goldBg)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18).copyWith(top: 0, bottom: 18),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                ProfileAvatar(
                                  imageUrl: profileImageUrl.isNotEmpty ? profileImageUrl : null,
                                  name: fullNameController.text,
                                  size: 92,
                                ),
                                GestureDetector(
                                  onTap: pickAndUploadImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt, size: 16, color: AppColors.paper),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fullNameController.text.isEmpty ? 'Your Name' : fullNameController.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
                                  if (username.isNotEmpty) Text('@$username', style: const TextStyle(color: AppColors.inkFaint, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 12),
                                  ProfileStats(
                                    followers: followersCount,
                                    following: followingCount,
                                    onFollowers: _showFollowersList,
                                    onFollowing: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectedUsersPage())),
                                    onEdit: () => _showEditProfileModal(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ================= ABOUT =================
          _sectionTitle("About"),
          _sectionCard(
            child: Text(
              bioController.text.isEmpty
                  ? "Tell people who you are and what you do."
                  : bioController.text,
              style: const TextStyle(
                color: AppColors.inkSoft,
                height: 1.6,
                fontSize: 15,
              ),
            ),
          ),

          if (taglineController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.goldBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  taglineController.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),

          if (contactController.text.trim().isNotEmpty || emailController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contactController.text.trim().isNotEmpty)
                      _contactRow(Icons.call_outlined, contactController.text.trim()),
                    if (contactController.text.trim().isNotEmpty && emailController.text.trim().isNotEmpty)
                      const SizedBox(height: 10),
                    if (emailController.text.trim().isNotEmpty)
                      _contactRow(Icons.mail_outline, emailController.text.trim()),
                  ],
                ),
              ),
            ),

          // ================= PROFILE OVERVIEW =================
          _sectionTitle("Profile Overview"),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SectionHeader(title: "Basics"),
          ),
          _sectionCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _infoCard("Location", locationController.text),
                _infoCard("Age", ageController.text),
                _infoCard("Gender", genderController.text),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SectionHeader(title: "Measurements"),
          ),
          _sectionCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _infoCard("Height", "${heightController.text} $heightUnit"),
                _infoCard("Weight", weightController.text),
                _infoCard("Measurements", measurementsController.text),
                _infoCard("Waist", waistController.text),
                _infoCard("Hips", hipsController.text),
                _infoCard("Shoulder", shoulderWidthController.text),
                _infoCard("Shoe Size", "${shoeSizeController.text} $shoeSizeUnit"),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SectionHeader(title: "Appearance"),
          ),
          _sectionCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _infoCard("Skin Tone", skinColorController.text),
                _infoCard("Eye Color", eyeColorController.text),
                _infoCard("Hair Color", hairColorController.text),
                _infoCard("Tattoos", tattoosController.text),
                _infoCard("Piercing", piercingController.text),
              ],
            ),
          ),

          // ================= PROFESSIONAL =================
          _sectionTitle("Professional"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (skillsController.text.isNotEmpty)
                  _sectionCard(
                    child: _bulletBlock(
                        "Skills", skillsController.text),
                  ),
                  const SizedBox(height: 20),
                if (preferredWorkController.text.isNotEmpty)
                  _sectionCard(
                    child: _bulletBlock(
                        "Preferred Work",
                        preferredWorkController.text),
                  ),
                  const SizedBox(height: 20),
                if (availabilityController.text.isNotEmpty)
                  _sectionCard(
                    child: _bulletBlock(
                        "Availability",
                        availabilityController.text),
                  ),
                  const SizedBox(height: 20),
                if (achievementsController.text.isNotEmpty)
                  _sectionCard(
                    child: _bulletBlock(
                        "Achievements",
                        achievementsController.text),
                  ),
              ],
            ),
          ),

          // ================= EXPERIENCE =================
          _sectionTitle("Experience"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (projectsController.text.trim().isNotEmpty)
                  _sectionCard(
                    child: _bulletBlock(
                      "Projects",
                      projectsController.text,
                    ),
                  ),
                const SizedBox(height: 20),
                if (agenciesController.text.trim().isNotEmpty)
                  _sectionCard(
                    child: _bulletBlock(
                      "Agency Associations",
                      agenciesController.text,
                    ),
                  ),
              ],
            ),
          ),
          // ================= POSTS =================
          Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Posts",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              IconButton(
                          icon: const Icon(Icons.add_box_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreatePostPage(),
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
          Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('uid', isEqualTo: _auth.currentUser!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: LoadingState(),
                );
              }

              final posts = snapshot.data!.docs;

              if (posts.isEmpty) {
                return EmptyState(
                  icon: Icons.grid_on_outlined,
                  title: "No posts yet",
                  message: "Share your first post to start building your presence.",
                  actionLabel: "Create post",
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreatePostPage()),
                    );
                  },
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final data = post.data() as Map<String, dynamic>;

                  return _ProfilePostCard(
                    postId: post.id,
                    postData: data,
                  );
                },
              );
            },
          ),
        ),

          // ================= PORTFOLIO =================
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Portfolio",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _uploadPortfolioMedia,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PortfolioGrid(
              stream: FirebaseFirestore.instance.collection('portfolio').where('uid', isEqualTo: _auth.currentUser!.uid).snapshots(),
              onDelete: (doc) => _deletePortfolioItem(doc),
              onView: (url, type) => _viewMediaFullScreen(url, type),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    ),
  );
}
}
class _ProfilePostCard extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const _ProfilePostCard({
    required this.postId,
    required this.postData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // POST IMAGE
          if (postData['imageUrl'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                postData['imageUrl'],
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          // CAPTION
          if (postData['caption'] != null &&
              postData['caption'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                postData['caption'],
                style: const TextStyle(fontSize: 14),
              ),
            ),

          const Divider(height: 1),

          // DELETE BUTTON (OWNER ONLY — PROFILE PAGE)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete post?"),
                    content: const Text(
                      "This action cannot be undone.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .delete();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
