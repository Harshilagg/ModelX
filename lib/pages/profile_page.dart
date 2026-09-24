import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../onboarding/login_page.dart';
import 'connected_users_page.dart';
import 'user_profile_page.dart';
import 'create_post_page.dart';
import 'comp_card_page.dart';
import '../widgets/comp_card_templates.dart';
import 'home_page.dart' show showCommentsSheet;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';
import '../agency/scouting/ai_scout_service.dart'; // Import AI Service
import '../ui/app_theme.dart';
import '../ui/board_theme.dart';
import 'settings_page.dart';
import '../widgets/board_widgets.dart';
import '../widgets/portfolio_masonry.dart';
import '../widgets/profile_photo_viewer.dart';
import '../widgets/app_button.dart';
import '../widgets/state_views.dart';
import '../widgets/app_skeleton.dart';

/// The model's own profile (style board 4a).
///
/// The old profile was one long scroll: every field always expanded, so
/// the things a model checks daily sat below the things they set once a
/// year. This puts the four facts a booker asks for in the hero, keeps
/// the rest behind spec sheets that open on tap, and splits portfolio
/// and posts onto their own tabs.
///
/// No field changed. Every value here is read from — and written back
/// to — exactly the `users` keys the app already stores, and the edit
/// form is the same form it has always been.
class ProfilePage extends StatefulWidget {
  /// True when the page is a tab inside the shell (which supplies the
  /// nav bar and owns back behaviour) rather than a pushed route.
  final bool embedded;

  const ProfilePage({super.key, this.embedded = false});

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

  /// Portfolio, Details, Posts -- in that order. The work a model is
  /// judged on was sitting behind a page of measurements.
  static const _tabPortfolio = 0;

  int _tab = _tabPortfolio;

  /// Held in a field, not rebuilt inline. `.snapshots()` returns a new
  /// Stream each call and a StreamBuilder resubscribes when its stream
  /// identity changes, so an inline stream blanks itself on every parent
  /// rebuild — a tab switch, a filter tap, a setState.
  Stream<QuerySnapshot>? _portfolioStream;
  Stream<QuerySnapshot>? _postsStream;

  @override
  void initState() {
    super.initState();
    final me = _auth.currentUser;
    if (me != null) {
      _portfolioStream = FirebaseFirestore.instance
          .collection('portfolio')
          .where('uid', isEqualTo: me.uid)
          .snapshots();
      _postsStream = FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: me.uid)
          .snapshots();
    }
    _loadUserData();
  }

  @override
  void dispose() {
    for (final c in [
      fullNameController,
      contactController,
      bioController,
      emailController,
      ageController,
      genderController,
      heightController,
      weightController,
      measurementsController,
      skillsController,
      experienceController,
      availabilityController,
      achievementsController,
      preferredWorkController,
      taglineController,
      locationController,
      skinColorController,
      waistController,
      hipsController,
      shoeSizeController,
      eyeColorController,
      hairColorController,
      tattoosController,
      shoulderWidthController,
      piercingController,
      projectsController,
      agenciesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ===================================================================
  // Data — unchanged from the previous profile
  // ===================================================================

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          // Prefer fullName; fall back to firstName/lastName if needed
          if (data['fullName'] != null) {
            fullNameController.text = data['fullName'];
          } else if (data['firstName'] != null || data['lastName'] != null) {
            fullNameController.text =
                "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
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
        followersCount = (data['followers'] is List)
            ? (data['followers'] as List).length
            : (data['followers'] is int ? data['followers'] : 0);
        followingCount = (data['following'] is List)
            ? (data['following'] as List).length
            : (data['following'] is int ? data['following'] : 0);

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

        projectsController.text = (data['projects'] is List)
            ? (data['projects'] as List).join('\n')
            : (data['projects'] ?? '');
        agenciesController.text = (data['agencies'] is List)
            ? (data['agencies'] as List).join('\n')
            : (data['agencies'] ?? '');
      }
    } catch (e) {
      debugPrint("🔥 Error loading user data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pick, frame, then upload.
  ///
  /// The framing step matters because every surface in the app crops this
  /// to a circle. Without it the model picks a photograph and the app
  /// decides which third of it to keep.
  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || !mounted) return;

    final cropped = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarCropPage(source: File(pickedFile.path)),
      ),
    );
    if (cropped == null || !mounted) return;

    setState(() => loading = true);

    final user = _auth.currentUser!;
    final imageUrl = await CloudinaryService.uploadProfileImage(
      cropped,
      user.uid,
    );

    if (!mounted) return;
    if (imageUrl == null) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Upload failed")));
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'profileImage': imageUrl,
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() {
      profileImageUrl = imageUrl;
      loading = false;
    });
  }

  void saveProfile() async {
    // The form key belongs to the full edit modal. Section editors write
    // the same controllers without it mounted, so a bare `!` here used to
    // be a crash waiting for the first person who edited one section.
    final form = _formKey.currentState;
    if (form == null || form.validate()) {
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
        'usernameLower': username.trim().isNotEmpty
            ? username.trim().toLowerCase()
            : null,
        'skinColor': skinColorController.text.trim(),
        'waist': waistController.text.trim(),
        'hips': hipsController.text.trim(),
        'shoeSize': shoeSizeController.text.trim(),
        'eyeColor': eyeColorController.text.trim(),
        'hairColor': hairColorController.text.trim(),
        'tattoos': tattoosController.text.trim(),
        'shoulderWidth': shoulderWidthController.text.trim(),
        'piercing': piercingController.text.trim(),
        'projects': projectsController.text.trim().isEmpty
            ? null
            : projectsController.text.trim().split('\n'),
        'agencies': agenciesController.text.trim().isEmpty
            ? null
            : agenciesController.text.trim().split('\n'),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      // AUTO-SYNC: Update AI Vector Index in background
      AiScoutService().indexProfile(user.uid, profileData).catchError((e) {
        debugPrint('AI Sync failed: $e');
      });

      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      _loadUserData();
    }
  }

  void logout() async {
    await _auth.signOut();
    if (!mounted) return;
    // After sign out, go to LoginPage and clear the stack so the user can
    // log in or create an account.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingLoginPage()),
      (Route<dynamic> route) => false,
    );
  }

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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Portfolio image deleted")));
    } catch (e) {
      debugPrint("🔥 Delete failed: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to delete image")));
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
                : const Icon(
                    Icons.play_circle_fill,
                    size: 80,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFollowersList() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    final followers = data['followers'] ?? [];

    final List<Map<String, dynamic>> followerData = [];
    for (var fid in followers) {
      try {
        final fdoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(fid)
            .get();
        if (fdoc.exists && fdoc.data() != null) {
          final d = fdoc.data()!;
          d['uid'] = fid;
          followerData.add(d);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: BoardColors.paper,
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: followerData.length,
        itemBuilder: (context, index) {
          final f = followerData[index];
          final name =
              (f['fullName'] ??
                      '${f['firstName'] ?? ''} ${f['lastName'] ?? ''}')
                  .toString()
                  .trim();
          return ListTile(
            leading: SizedBox(
              width: 36,
              height: 42,
              child: BoardMedia(
                url: (f['profileImage'] ?? '').toString(),
                cut: 10,
              ),
            ),
            title: Text(
              name.isEmpty ? 'User' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardType.title(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            subtitle: f['username'] != null
                ? Text(
                    '@${f['username']}',
                    style: BoardType.mono(
                      fontSize: 10,
                      color: BoardColors.inkSoft,
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfilePage(uid: f['uid']),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ===================================================================
  // Build
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final content = _isLoading ? _loadingSkeleton() : _content();
    if (widget.embedded) return content;
    return Scaffold(backgroundColor: BoardColors.paper, body: content);
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(),
        BoardTabRail(
          tabs: const ['Portfolio', 'Details', 'Posts'],
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
          accent: BoardColors.brass,
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [_portfolioTab(), _detailsTab(), _postsTab()],
          ),
        ),
      ],
    );
  }

  // ---- hero ---------------------------------------------------------

  Widget _hero() {
    final name = fullNameController.text.trim();
    final location = locationController.text.trim();

    final handle = [
      if (username.trim().isNotEmpty) '@${username.trim()}',
      if (location.isNotEmpty) location,
    ].join(' · ');

    return Container(
      color: BoardColors.ink,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  if (!widget.embedded)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: BoardColors.onInk,
                      ),
                    )
                  else
                    const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: BoardType.title(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.9,
                        color: BoardColors.onInk,
                      ),
                    ),
                  ),
                  // Edit lives here, not at the foot of a long
                  // scroll. It is the thing a model reaches for most and
                  // it used to be the furthest away.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showEditProfileModal(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Edit',
                          style: BoardType.mono(
                            fontSize: 10,
                            color: BoardColors.brass,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: BoardColors.brass,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Settings: the theme switch, the unit switches and
                  // log out. Those were scattered -- the units buried
                  // inside the measurements editor, log out at the foot
                  // of a long scroll -- and a gear is where people look
                  // for them.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Settings',
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: BoardColors.onInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular: this is you, not a portfolio tile. The
                  // comp-card cut stays on the work — the Portfolio tab,
                  // the comp card tool — so the two never get confused.
                  //
                  // Tapping opens the photograph. It used to launch the
                  // gallery picker, so brushing your own avatar threw you
                  // into the OS file browser; changing the photo belongs
                  // in Edit profile with the rest of your details.
                  GestureDetector(
                    onTap: () => showProfilePhoto(
                      context,
                      url: profileImageUrl,
                      name: name.isEmpty ? 'Your name' : name,
                      onEdit: pickAndUploadImage,
                    ),
                    child: BoardAvatar(
                      url: profileImageUrl,
                      name: name,
                      size: 96,
                      onDark: true,
                      ring: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (name.isEmpty ? 'Your name' : name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.display(
                            fontSize: 30,
                            color: BoardColors.onInk,
                            height: 0.9,
                          ),
                        ),
                        if (handle.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            handle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BoardType.mono(
                              fontSize: 10,
                              color: BoardColors.onInkSoft,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _showFollowersList,
                                child: BoardStatWell(
                                  label: 'Followers',
                                  value: followersCount.toString(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ConnectedUsersPage(),
                                  ),
                                ),
                                child: BoardStatWell(
                                  label: 'Following',
                                  value: followingCount.toString(),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  // ---- details ------------------------------------------------------

  String _statValue(String raw, [String suffix = '']) {
    final value = raw.trim();
    if (value.isEmpty) return '—';
    return suffix.isEmpty ? value : '$value $suffix';
  }

  Widget _detailsTab() {
    final contactValue = contactController.text.trim();
    final emailValue = emailController.text.trim();
    final bio = bioController.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
      children: [
        _quadStats(),
        const SizedBox(height: 12),
        _unitsRow(),
        const SizedBox(height: 12),

        BoardSectionLabel('About', trailing: _editChip(_editAbout)),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _editAbout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: BoardColors.card,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bio.isEmpty ? 'Add a short bio.' : bio,
              style: BoardType.body(
                fontSize: 13,
                color: bio.isEmpty ? BoardColors.inkSoft : BoardColors.ink,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
        BoardSectionLabel('Contact', trailing: _editChip(_editContact)),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _editContact,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: BoardColors.card,
              borderRadius: BorderRadius.circular(8),
            ),
            child: (contactValue.isEmpty && emailValue.isEmpty)
                ? Text(
                    'Add a phone number brands can reach you on.',
                    style: BoardType.body(
                      fontSize: 13,
                      color: BoardColors.inkSoft,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (contactValue.isNotEmpty)
                        SpecRow(
                          label: 'Tel',
                          value: contactValue,
                          topBorder: false,
                        ),
                      if (emailValue.isNotEmpty)
                        SpecRow(
                          label: 'Eml',
                          value: emailValue,
                          topBorder: contactValue.isNotEmpty,
                        ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),
        const BoardSectionLabel('Spec sheet — tap to open, or edit inside'),
        const SizedBox(height: 6),
        _specRow(
          'Measurements',
          _summary([
            _statValue(weightController.text, 'KG'),
            measurementsController.text,
            waistController.text,
          ]),
          _openMeasurements,
        ),
        const SizedBox(height: 6),
        _specRow(
          'Appearance',
          _summary([
            skinColorController.text,
            eyeColorController.text,
            hairColorController.text,
          ]),
          _openAppearance,
        ),
        const SizedBox(height: 6),
        _specRow(
          'Professional',
          _summary([
            skillsController.text,
            preferredWorkController.text,
            availabilityController.text,
          ]),
          _openProfessional,
        ),
        const SizedBox(height: 6),
        _specRow(
          'Career History',
          _summary([projectsController.text, agenciesController.text]),
          _openCareer,
        ),

        const SizedBox(height: 12),
        _compCardRow(),
      ],
    );
  }

  /// Joins whatever of a sheet's values exist into one preview line, so
  /// an empty field shortens the line instead of printing a dash.
  String _summary(List<String> parts) {
    final kept = parts
        .map((p) => p.replaceAll('\n', ' · ').trim())
        .where((p) => p.isNotEmpty && p != '—')
        .toList();
    if (kept.isEmpty) return 'NOT SET YET';
    return kept.join(' · ');
  }

  Widget _quadStats() {
    final cells = [
      ('Height', _statValue(heightController.text, heightUnit)),
      ('Waist', _statValue(waistController.text)),
      ('Shoe', _statValue(shoeSizeController.text, shoeSizeUnit)),
      ('Age', _statValue(ageController.text)),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: BoardColors.inkLine,
        // IntrinsicHeight: this Row sits in a scroll view, so its height is
        // unbounded, and a bare `stretch` would hand the cells an infinite
        // height constraint. This measures the tallest cell, then squares
        // the rest to it so the hairline dividers run the full height.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                Expanded(
                  child: Container(
                    color: BoardColors.card,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cells[i].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.mono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w400,
                            color: BoardColors.inkSoft,
                            letterSpacing: 0.55,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cells[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.mono(
                            fontSize: 12.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i != cells.length - 1) const SizedBox(width: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Switches the unit label stored on the profile. Writes only
  /// `heightUnit`, a field the app already keeps — the number itself
  /// stays the model's to retype, because converting it silently would
  /// rewrite data they entered.
  Widget _unitsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: BoardColors.shell,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(child: BoardSectionLabel('Height unit')),
          for (final unit in ['cm', 'in', 'ft'])
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  setState(() => heightUnit = unit);
                  final user = _auth.currentUser;
                  if (user == null) return;
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({'heightUnit': unit}, SetOptions(merge: true));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: heightUnit == unit
                        ? BoardColors.ink
                        : BoardColors.inkWell,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    unit,
                    style: BoardType.mono(
                      fontSize: 10,
                      color: heightUnit == unit
                          ? BoardColors.onInk
                          : BoardColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _specRow(String title, String detail, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BoardColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.title(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 10,
                      color: BoardColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: BoardColors.ink,
              ),
              child: const Icon(
                Icons.arrow_outward_rounded,
                size: 14,
                color: BoardColors.brass,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The comp card's entry point. It belongs in the spec sheet because
  /// the card is made of exactly these fields — and the readiness number
  /// is the nudge that gets a thin profile filled in.
  Widget _compCardRow() {
    // One shared definition — see CompCardReadiness — so this number
    // can't disagree with the comp card tool or the Network nudge for the
    // same card. It also scores only fields a template actually prints;
    // weight appears on none of them.
    final statsPct = CompCardReadiness.statsPercent({
      'height': heightController.text,
      'measurements': measurementsController.text,
      'waist': waistController.text,
      'hips': hipsController.text,
      'shoeSize': shoeSizeController.text,
      'hairColor': hairColorController.text,
      'eyeColor': eyeColorController.text,
      'location': locationController.text,
      'contact': contactController.text,
      'username': username,
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CompCardPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: BoardColors.ink,
          borderRadius: BorderRadius.circular(BoardRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Comp card',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.title(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: BoardColors.onInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'FREE · NO WATERMARK · DETAILS $statsPct% READY',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BoardType.mono(
                      fontSize: 9.5,
                      color: BoardColors.onInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: BoardColors.brass,
              ),
              child: const Icon(
                Icons.arrow_outward_rounded,
                size: 14,
                color: BoardColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The edit affordance beside a section heading.
  Widget _editChip(VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: const MonoChip(
      'EDIT',
      filled: true,
      accent: BoardColors.ink,
      fontSize: 9,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
  );

  // ---- section editing ----------------------------------------------

  /// One field in a focused editor.
  ///
  /// Editing used to mean the whole profile in one sheet — twenty-odd
  /// inputs you scrolled past to reach the one you came for. These let a
  /// model fix what they are looking at.
  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: BoardType.body(fontSize: 14, color: BoardColors.onInk),
        cursorColor: BoardColors.brass,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: BoardType.mono(
            fontSize: 10,
            color: BoardColors.onInkSoft,
          ),
          hintStyle: BoardType.body(
            fontSize: 13,
            color: BoardColors.onInkFaint,
          ),
          filled: true,
          fillColor: BoardColors.slate,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: const OutlineInputBorder(borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide.none),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: BoardColors.brass, width: 1.5),
          ),
        ),
      ),
    );
  }

  /// A unit chooser that writes straight to the profile, matching the
  /// Details tab's own toggle.
  Widget _unitField(
    String label,
    TextEditingController controller,
    List<String> units,
    String current,
    ValueChanged<String> onUnit,
  ) {
    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                label,
                controller,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            for (final unit in units)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setSheetState(() => onUnit(unit));
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 12,
                    ),
                    color: current == unit
                        ? BoardColors.brass
                        : BoardColors.slate,
                    child: Text(
                      unit,
                      style: BoardType.mono(
                        fontSize: 10,
                        color: current == unit
                            ? BoardColors.ink
                            : BoardColors.onInkSoft,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _editSection(String title, List<Widget> Function() fields) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: BoardColors.scrim,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
          ),
          decoration: const BoxDecoration(
            color: BoardColors.ink,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(BoardRadius.sheet),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BoardColors.onInk.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.display(
                            fontSize: 26,
                            color: BoardColors.onInk,
                            height: 1,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          'Cancel',
                          style: BoardType.mono(
                            fontSize: 11,
                            color: BoardColors.onInkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: fields(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: BoardButton(
                    label: 'Save',
                    background: BoardColors.brass,
                    foreground: BoardColors.ink,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      saveProfile();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editMeasurements() => _editSection(
    'Measurements',
    () => [
      _unitField(
        'Height',
        heightController,
        const ['cm', 'in', 'ft'],
        heightUnit,
        (u) => heightUnit = u,
      ),
      _field(
        'Bust · waist · hips',
        measurementsController,
        hint: 'e.g. 82-60-88',
      ),
      _field('Waist', waistController, keyboardType: TextInputType.number),
      _field('Hips', hipsController, keyboardType: TextInputType.number),
      _field(
        'Shoulder',
        shoulderWidthController,
        keyboardType: TextInputType.number,
      ),
      _field(
        'Weight (kg)',
        weightController,
        keyboardType: TextInputType.number,
      ),
      _unitField(
        'Shoe size',
        shoeSizeController,
        const ['US', 'EU', 'UK'],
        shoeSizeUnit,
        (u) => shoeSizeUnit = u,
      ),
    ],
  );

  void _editAppearance() => _editSection(
    'Appearance',
    () => [
      _field('Skin tone', skinColorController),
      _field('Eye colour', eyeColorController),
      _field('Hair colour', hairColorController),
      _field('Tattoos', tattoosController),
      _field('Piercing', piercingController),
      _field('Gender', genderController, hint: 'Male / Female / Other'),
    ],
  );

  void _editProfessional() => _editSection(
    'Professional',
    () => [
      _field('Skills', skillsController, hint: 'Comma separated'),
      _field('Preferred work', preferredWorkController),
      _field(
        'Availability',
        availabilityController,
        hint: 'Full-time, freelance',
      ),
      _field('Experience', experienceController, maxLines: 2),
      _field('Achievements', achievementsController, maxLines: 3),
      _field('Tagline', taglineController),
    ],
  );

  void _editCareer() => _editSection(
    'Career History',
    () => [
      _field('Projects', projectsController, maxLines: 4, hint: 'One per line'),
      _field(
        'Agency associations',
        agenciesController,
        maxLines: 3,
        hint: 'One per line',
      ),
    ],
  );

  void _editAbout() =>
      _editSection('About', () => [_field('Bio', bioController, maxLines: 5)]);

  void _editContact() => _editSection(
    'Contact',
    () => [
      _field('Full name', fullNameController),
      _field('City', locationController),
      _field('Age', ageController, keyboardType: TextInputType.number),
      _field('Phone', contactController, keyboardType: TextInputType.phone),
      _field(
        'Email',
        emailController,
        keyboardType: TextInputType.emailAddress,
      ),
    ],
  );

  // ---- spec sheets --------------------------------------------------

  String _orDash(String v) => v.trim().isEmpty ? '—' : v.trim();

  void _openMeasurements() {
    showBoardSheet(
      context,
      title: 'Measurements',
      onEdit: _editMeasurements,
      children: [
        Row(
          children: [
            Expanded(
              child: BoardStatWell(
                label: 'Weight',
                value: _orDash(weightController.text),
                valueSize: 20,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: BoardStatWell(
                label: 'Waist',
                value: _orDash(waistController.text),
                valueSize: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: BoardStatWell(
                label: 'Hips',
                value: _orDash(hipsController.text),
                valueSize: 20,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: BoardStatWell(
                label: 'Shoulder',
                value: _orDash(shoulderWidthController.text),
                valueSize: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SpecRow(
          label: 'Height',
          value: _statValue(heightController.text, heightUnit),
          onDark: true,
        ),
        SpecRow(
          label: 'Shoe size',
          value: _statValue(shoeSizeController.text, shoeSizeUnit),
          onDark: true,
        ),
        SpecRow(
          label: 'Measurements',
          value: _orDash(measurementsController.text),
          onDark: true,
          bottomBorder: true,
        ),
      ],
    );
  }

  void _openAppearance() {
    showBoardSheet(
      context,
      title: 'Appearance',
      onEdit: _editAppearance,
      children: [
        SpecRow(
          label: 'Skin tone',
          value: _orDash(skinColorController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Eye color',
          value: _orDash(eyeColorController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Hair color',
          value: _orDash(hairColorController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Tattoos',
          value: _orDash(tattoosController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Piercing',
          value: _orDash(piercingController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Gender',
          value: _orDash(genderController.text),
          onDark: true,
          bottomBorder: true,
        ),
      ],
    );
  }

  void _openProfessional() {
    showBoardSheet(
      context,
      title: 'Professional',
      onEdit: _editProfessional,
      children: [
        SpecRow(
          label: 'Skills',
          value: _orDash(skillsController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Preferred work',
          value: _orDash(preferredWorkController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Availability',
          value: _orDash(availabilityController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Experience',
          value: _orDash(experienceController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Achievements',
          value: _orDash(achievementsController.text),
          onDark: true,
        ),
        SpecRow(
          label: 'Tagline',
          value: _orDash(taglineController.text),
          onDark: true,
          bottomBorder: true,
        ),
      ],
    );
  }

  void _openCareer() {
    showBoardSheet(
      context,
      title: 'Career History',
      onEdit: _editCareer,
      children: [
        SpecRow(
          label: 'Projects',
          value: _orDash(projectsController.text.replaceAll('\n', ' · ')),
          onDark: true,
        ),
        SpecRow(
          label: 'Agency associations',
          value: _orDash(agenciesController.text.replaceAll('\n', ' · ')),
          onDark: true,
          bottomBorder: true,
        ),
      ],
    );
  }

  // ---- portfolio ----------------------------------------------------

  Widget _portfolioTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _portfolioStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
          children: [
            BoardSectionLabel(
              'Portfolio · ${docs.length} shot${docs.length == 1 ? '' : 's'}',
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _uploadPortfolioMedia,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BoardColors.brass,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 15,
                    color: BoardColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!snapshot.hasData)
              const Padding(padding: EdgeInsets.all(20), child: LoadingState())
            else if (docs.isEmpty)
              const EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'No shots yet',
                message: 'Add shots here and they become your comp card.',
              )
            else
              PortfolioMasonry(
                itemCount: docs.length,
                itemBuilder: (context, i, height) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final url = (data['mediaUrl'] ?? '').toString();

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _viewMediaFullScreen(
                      url,
                      (data['mediaType'] ?? 'image').toString(),
                    ),
                    onLongPress: () => _confirmDeleteShot(doc),
                    child: BoardMedia(
                      url: url,
                      dark: i.isOdd,
                      cut: 20,
                      overlay: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            color: BoardColors.ink,
                            child: Text(
                              'SHOT ${(i + 1).toString().padLeft(2, '0')}',
                              style: BoardType.mono(
                                fontSize: 9,
                                color: BoardColors.brass,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteShot(DocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BoardColors.paper,
        title: Text(
          'DELETE SHOT?',
          style: BoardType.title(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This removes it from your portfolio and your comp card.',
          style: BoardType.body(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: BoardColors.brass),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _deletePortfolioItem(doc);
  }

  // ---- posts --------------------------------------------------------

  Widget _postsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
          children: [
            BoardSectionLabel(
              '${docs.length} post${docs.length == 1 ? '' : 's'}',
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostPage()),
                ),
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BoardColors.brass,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 15,
                    color: BoardColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!snapshot.hasData)
              const Padding(padding: EdgeInsets.all(20), child: LoadingState())
            else if (docs.isEmpty)
              const EmptyState(
                icon: Icons.post_add_outlined,
                title: 'No posts yet',
                message: 'Share a shot or a note and it shows up here.',
              )
            else
              for (final doc in docs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _ownPost(doc),
                ),
          ],
        );
      },
    );
  }

  Widget _ownPost(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    final likes = List<String>.from(data['likes'] ?? const []);

    return Container(
      decoration: BoxDecoration(
        color: BoardColors.card,
        borderRadius: BorderRadius.circular(BoardRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageUrl.isNotEmpty)
            AspectRatio(aspectRatio: 1.35, child: BoardMedia(url: imageUrl)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (caption.isNotEmpty)
                        Text(
                          caption,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: BoardType.body(fontSize: 12.5),
                        ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showCommentsSheet(context, doc.id),
                        child: Text(
                          '♥ ${likes.length} · COMMENT',
                          style: BoardType.mono(
                            fontSize: 10,
                            color: BoardColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _confirmDeletePost(doc),
                  child: const MonoChip(
                    'DELETE',
                    filled: true,
                    accent: BoardColors.brass,
                    fontSize: 9.5,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePost(QueryDocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BoardColors.paper,
        title: Text(
          'DELETE POST?',
          style: BoardType.title(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: BoardColors.brass),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
  }

  // ---- loading ------------------------------------------------------

  Widget _loadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: BoardColors.ink,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 92, height: 114, color: BoardColors.slate),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 28, color: BoardColors.slate),
                        const SizedBox(height: 10),
                        Container(
                          height: 12,
                          width: 140,
                          color: BoardColors.slate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              const AppSkeleton(height: 56),
              const SizedBox(height: 12),
              AppSkeleton.card(height: 90),
              const SizedBox(height: 12),
              AppSkeleton.card(height: 64),
              const SizedBox(height: 12),
              AppSkeleton.card(height: 64),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // Edit Profile Modal — the same form, and the same fields, as before
  // ===================================================================

  void _showEditProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BoardColors.paper,
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
                Text(
                  'Edit profile',
                  style: BoardType.display(fontSize: 26, height: 1),
                ),
                const SizedBox(height: 20),

                // Basic info
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: genderController,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    hintText: 'Male / Female / Other',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Physical attributes grid
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Physical Attributes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (context, setSheetState) => Wrap(
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
                                items: const [
                                  DropdownMenuItem(
                                    value: 'cm',
                                    child: Text('cm'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in',
                                    child: Text('in'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ft',
                                    child: Text('ft'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setSheetState(() => heightUnit = v);
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: waistController,
                          decoration: const InputDecoration(
                            labelText: 'Waist (cm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: hipsController,
                          decoration: const InputDecoration(
                            labelText: 'Hips (cm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: shoulderWidthController,
                          decoration: const InputDecoration(
                            labelText: 'Shoulder (cm)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
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
                                items: const [
                                  DropdownMenuItem(
                                    value: 'US',
                                    child: Text('US'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'EU',
                                    child: Text('EU'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'UK',
                                    child: Text('UK'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setSheetState(() => shoeSizeUnit = v);
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: weightController,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: eyeColorController,
                          decoration: const InputDecoration(
                            labelText: 'Eye Color',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: hairColorController,
                          decoration: const InputDecoration(
                            labelText: 'Hair Color',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: measurementsController,
                          decoration: const InputDecoration(
                            labelText: 'Measurements',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: tattoosController,
                          decoration: const InputDecoration(
                            labelText: 'Tattoos (describe)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: piercingController,
                          decoration: const InputDecoration(
                            labelText: 'Piercing (describe)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Projects & Agencies
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Career History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: projectsController,
                  decoration: const InputDecoration(
                    labelText: 'Projects (one per line)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: agenciesController,
                  decoration: const InputDecoration(
                    labelText: 'Agency associations (one per line)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // ================= PROFESSIONAL DETAILS =================
                const Align(
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
                  controller: experienceController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Experience',
                    hintText: 'Years active, notable experience',
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
                  controller: taglineController,
                  decoration: const InputDecoration(
                    labelText: 'Tagline',
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
}
