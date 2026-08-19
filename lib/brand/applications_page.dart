import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/model_application_card.dart';
import 'post_gig_page.dart';

/// All applicants across every gig this brand has posted — flattens the
/// `gigs/{gigId}/applications` subcollections of every gig owned by the
/// current brand into one feed, reusing the same [ModelApplicationCard]
/// used on the per-gig applicants screen.
class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('gigs').where('brandId', isEqualTo: uid).snapshots(),
        builder: (context, gigSnap) {
          if (gigSnap.hasError) {
            return const ErrorStateView(message: 'Could not load applicants. Please try again.');
          }
          if (!gigSnap.hasData) {
            return const LoadingState();
          }

          final gigIds = gigSnap.data!.docs.map((d) => d.id).toList();

          if (gigIds.isEmpty) {
            return _emptyState(context);
          }

          return _MergedApplicants(gigIds: gigIds);
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Expanded(
          child: EmptyState(
            icon: Icons.people_alt_outlined,
            title: 'No applications yet',
            message: 'Gigs with recent activity will appear here',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PostGigPage()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Post a New Gig'),
          ),
        ),
      ],
    );
  }
}

class _MergedApplicants extends StatelessWidget {
  final List<String> gigIds;
  const _MergedApplicants({required this.gigIds});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: _combineStreams(gigIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoadingState();
        }

        final entries = <_ApplicantEntry>[];
        for (var i = 0; i < gigIds.length; i++) {
          final snap = snapshot.data![i];
          for (final doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            entries.add(_ApplicantEntry(
              gigId: gigIds[i],
              modelId: data['modelId'] ?? doc.id,
              status: data['status'] ?? 'applied',
              appliedAt: data['appliedAt'] is Timestamp ? (data['appliedAt'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0),
            ));
          }
        }

        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.people_alt_outlined,
            title: 'No applications yet',
            message: 'When models apply to your gigs, they will appear here.',
          );
        }

        entries.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            return ModelApplicationCard(gigId: e.gigId, modelId: e.modelId, status: e.status);
          },
        );
      },
    );
  }

  Stream<List<QuerySnapshot>> _combineStreams(List<String> ids) {
    final streams = ids
        .map((id) => FirebaseFirestore.instance.collection('gigs').doc(id).collection('applications').snapshots())
        .toList();
    return _zipLatest(streams);
  }

  /// Combines the latest snapshot from every gig's applications stream into
  /// one list, re-emitting whenever any single stream updates.
  Stream<List<QuerySnapshot>> _zipLatest(List<Stream<QuerySnapshot>> streams) {
    final controller = StreamController<List<QuerySnapshot>>();
    final latest = List<QuerySnapshot?>.filled(streams.length, null);
    final subs = <StreamSubscription>[];

    void emitIfReady() {
      if (latest.every((s) => s != null)) {
        controller.add(latest.cast<QuerySnapshot>());
      }
    }

    for (var i = 0; i < streams.length; i++) {
      subs.add(streams[i].listen((snap) {
        latest[i] = snap;
        emitIfReady();
      }, onError: controller.addError));
    }

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };

    return controller.stream;
  }
}

class _ApplicantEntry {
  final String gigId;
  final String modelId;
  final String status;
  final DateTime appliedAt;

  _ApplicantEntry({required this.gigId, required this.modelId, required this.status, required this.appliedAt});
}
