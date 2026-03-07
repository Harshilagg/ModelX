import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/model_application_card.dart';

class BrandGigApplicationsPage extends StatelessWidget {
  final String gigId;
  final String gigTitle;

  const BrandGigApplicationsPage({
    super.key,
    required this.gigId,
    required this.gigTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(gigTitle),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gigs')
            .doc(gigId)
            .collection('applications')
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final apps = snapshot.data!.docs;

          if (apps.isEmpty) {
            return const Center(child: Text('No applications yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final data = app.data() as Map<String, dynamic>;

              return ModelApplicationCard(
                gigId: gigId,
                modelId: data['modelId'],
                status: data['status'] ?? 'applied',
              );
            },
          );
        },
      ),
    );
  }
}
