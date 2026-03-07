import 'package:flutter/material.dart';
// no firestore import required here; applicant data is passed in
import '../../pages/user_profile_page.dart';

class ApplicantCard extends StatelessWidget {
  final String castingId;
  final Map<String, dynamic> applicant;
  final Future<void> Function(String id, String status) onUpdate;

  const ApplicantCard({super.key, required this.castingId, required this.applicant, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final avatar = applicant['avatarUrl'] ?? applicant['profileImage'] ?? applicant['photo'] ?? '';
    final name = applicant['displayName'] ?? applicant['fullName'] ?? applicant['name'] ?? applicant['username'] ?? 'Applicant';
    final status = (applicant['status'] ?? 'pending').toString();
    final message = (applicant['message'] ?? '').toString();
    final applicantId = applicant['id'];
    final modelUid = applicant['uid'] ?? applicant['modelId'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 30, backgroundImage: avatar.toString().isNotEmpty ? NetworkImage(avatar) as ImageProvider : null, backgroundColor: Colors.grey[200]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Text(status, style: const TextStyle(fontSize: 12))),
              ]),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(onPressed: status == 'Shortlisted' ? null : () => onUpdate(applicantId, 'shortlisted'), child: const Text('Shortlist')),
                  OutlinedButton(onPressed: () => onUpdate(applicantId, 'rejected'), child: const Text('Reject')),
                  TextButton(onPressed: modelUid != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(uid: modelUid))) : null, child: const Text('View Profile')),
                ],
              )
            ]),
          )
        ]),
      ),
    );
  }
}
