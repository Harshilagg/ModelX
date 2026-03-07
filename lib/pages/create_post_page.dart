import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_modelx/services/cloudinary_service.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PostAction({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}


class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController captionController = TextEditingController();
  File? selectedImage;
  bool loading = false;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (file == null) return;

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
    backgroundColor: const Color(0xFFF3F4F6),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "New Post",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ================= IMAGE PICKER =================
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      style: BorderStyle.solid,
                    ),
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
                            Icon(Icons.camera_alt_outlined,
                                size: 42, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              "Tap to upload image",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 20),

              // ================= CAPTION =================
              TextField(
                controller: captionController,
                maxLength: 500,
                maxLines: 7,
                decoration: InputDecoration(
                  hintText: "Write something about this post...",
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ================= ACTION ROW =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _PostAction(icon: Icons.people_outline, label: "Tag People"),
                  _PostAction(icon: Icons.tag_outlined, label: "Add Hashtags"),
                ],
              ),

              const SizedBox(height: 24),

              // ================= SHARE BUTTON =================
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : createPost,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3B82F6),
                          Color(0xFF8B5CF6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Share Post",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
