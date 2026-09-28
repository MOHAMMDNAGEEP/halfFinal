import 'package:flutter/material.dart';
import 'package:shahin_app/core/config/supabase_config.dart';

class RatingScreen extends StatefulWidget {
  final String orderId;
  final bool isCustomer;

  const RatingScreen({
    super.key,
    required this.orderId,
    required this.isCustomer,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار تقييم')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final orderData = await SupabaseConfig.client
          .from('orders')
          .select('customer_id, driver_id')
          .eq('id', widget.orderId)
          .single();

      final fromUserId =
          widget.isCustomer ? orderData['customer_id'] : orderData['driver_id'];
      final toUserId =
          widget.isCustomer ? orderData['driver_id'] : orderData['customer_id'];

      await SupabaseConfig.client.from('ratings').insert({
        'order_id': widget.orderId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'rating': _rating,
        'comment': _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكراً لتقييمك!')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال التقييم: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقييم الرحلة')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('كيف كانت تجربتك؟',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 50,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تعليق (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            _submitting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitRating,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('إرسال التقييم'),
                  ),
          ],
        ),
      ),
    );
  }
}
