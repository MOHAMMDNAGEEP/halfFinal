import 'package:flutter/material.dart';

/// شعار التطبيق. ضع ملف الشعار في: assets/images/logo.png
/// (إذا لم يوجد الملف تظهر أيقونة الشاحنة القديمة بدل أن يتعطل التطبيق)
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.local_shipping, size: size * 0.8, color: Colors.blue),
    );
  }
}
