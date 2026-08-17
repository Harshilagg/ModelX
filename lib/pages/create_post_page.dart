import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_button.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController captionController = TextEditingController();
  File? selectedImage;
  bool loading = false;

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (file == null || !mounted) return;

    setState(() {
      selectedImage = File(file.path);
    });
  }

Future<void> createPost() async {
  if (selectedImage == null || loading) return;

  setState(() => loading = true);

  try {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      throw Exception('User profile not found');
    }

    final userData = userDoc.data()!;

    final imageUrl = await CloudinaryService.uploadPortfolioImage(
      selectedImage!,
      "post_${user.uid}_${DateTime.now().millisecondsSinceEpoch}",
    );

    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Image upload failed');
    }

    await FirebaseFirestore.instance.collection('posts').add({
      'uid': user.uid,
      'username': userData['username'] ?? '',
      'userImage': userData['profileImage'] ?? '',
      'imageUrl': imageUrl,
      'caption': captionController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
      'likeCount': 0,
    });

    if (!mounted) return;

    Navigator.pop(context); // ✅ SUCCESS
  } catch (e) {
    debugPrint('Create post error: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post. Please try again.')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => loading = false);
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= IMAGE PICKER =================
              GestureDetector(
                onTap: pickImage,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.paperRaised,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.line),
                      image: selectedImage != null
                          ? DecorationImage(
                              image: FileImage(selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                                color: AppColors.inkFaint,
                              ),
                              SizedBox(height: AppSpacing.sm),
                              Text(
                                "Tap to choose a photo",
                                style: TextStyle(color: AppColors.inkFaint, fontSize: 14),
                              ),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Material(
                                color: AppColors.ink.withValues(alpha: 0.55),
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.paper,
                                    size: 18,
                                  ),
                                  onPressed: pickImage,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ================= CAPTION =================
              Text('Caption', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: captionController,
                maxLength: 500,
                maxLines: 6,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: "Write something about this post...",
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ================= SHARE BUTTON =================
              AppButton(
                label: "Share post",
                onPressed: selectedImage == null || loading ? null : createPost,
                loading: loading,
                expand: true,
                icon: Icons.send_rounded,
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
