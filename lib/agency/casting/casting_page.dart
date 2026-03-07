import 'package:flutter/material.dart';

class CastingPage extends StatelessWidget {
  const CastingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Create Casting'),
        icon: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Castings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text('Casting ${index + 1}'),
                      subtitle: const Text('Short description'),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text(index % 2 == 0 ? 'Open' : 'Closed')),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
