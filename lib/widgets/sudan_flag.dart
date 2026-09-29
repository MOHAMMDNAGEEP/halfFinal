import 'package:flutter/material.dart';

/// علم السودان مرسوم بالكود (بدون ملف صورة).
/// الأحمر ثم الأبيض ثم الأسود، ومثلث أخضر عند السارية.
class SudanFlag extends StatelessWidget {
  final double width;
  final double height;
  const SudanFlag({super.key, this.width = 26, this.height = 17});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(painter: _SudanFlagPainter()),
        ),
      ),
    );
  }
}

class _SudanFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h),
        Paint()..color = const Color(0xFFD21034));
    canvas.drawRect(
        Rect.fromLTWH(0, h, size.width, h), Paint()..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(0, h * 2, size.width, h), Paint()..color = Colors.black);
    final triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.45, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, Paint()..color = const Color(0xFF007229));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
