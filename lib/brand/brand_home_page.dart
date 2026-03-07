import 'package:flutter/material.dart';

class BrandHomePage extends StatelessWidget {
  const BrandHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Dashboard'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Brand Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}