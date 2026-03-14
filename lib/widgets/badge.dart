import 'package:flutter/material.dart';

class Badge extends StatelessWidget {
  final String text;
  final Color? color;

  const Badge({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
