import 'package:flutter/material.dart';

class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(child: Text('Filters: Age, Height, Gender, Location', style: TextStyle(color: Colors.grey[700]))),
        ElevatedButton(onPressed: () {}, child: const Text('Apply'))
      ]),
    );
  }
}
