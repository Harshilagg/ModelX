import 'package:flutter/material.dart';

class TalentScoutPage extends StatelessWidget {
  const TalentScoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Talent Scout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: Container(height: 44, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('Filters placeholder')))), const SizedBox(width: 12), ElevatedButton(onPressed: () {}, child: const Text('Search'))]),
          const SizedBox(height: 12),
          Expanded(child: GridView.builder(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: 8, itemBuilder: (context, index) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 40, backgroundColor: Colors.grey[300]), const SizedBox(height: 8), Text('Result ${index+1}'), const SizedBox(height: 8), ElevatedButton(onPressed: () {}, child: const Text('Shortlist'))]))))
        ]),
      ),
    );
  }
}
