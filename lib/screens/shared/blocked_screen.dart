import 'package:flutter/material.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العميل - الرئيسية')),
      body: const Center(child: Text('قيد التطوير')),
    );
  }
}
