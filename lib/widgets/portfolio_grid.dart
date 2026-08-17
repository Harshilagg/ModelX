import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'state_views.dart';

class PortfolioGrid extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final void Function(DocumentSnapshot) onDelete;
  final void Function(String, String) onView;

  const PortfolioGrid({super.key, required this.stream, required this.onDelete, required this.onView});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: LoadingState(),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.photo_library_outlined,
            title: "No portfolio items yet",
            message: "Add your best work to stand out.",
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final media = docs[index];
            final data = media.data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () => onView(data['mediaUrl'], data['mediaType']),
              onLongPress: () => onDelete(media),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(data['mediaUrl'], fit: BoxFit.cover),
              ),
            );
          },
        );
      },
    );
  }
}
