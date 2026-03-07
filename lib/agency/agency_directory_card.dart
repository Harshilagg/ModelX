import 'package:flutter/material.dart';

class AgencyDirectoryCard extends StatelessWidget {
  final Map<String, dynamic> agency;
  final VoidCallback? onTap;

  const AgencyDirectoryCard({super.key, required this.agency, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (agency['logoUrl'] != null)
              CircleAvatar(backgroundImage: NetworkImage(agency['logoUrl']), radius: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(agency['agencyName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if ((agency['specialties'] ?? '').toString().isNotEmpty) Text((agency['specialties'] is List) ? (agency['specialties'] as List).join(', ') : agency['specialties']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
