import 'package:flutter/material.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'package:shahin_app/screens/customer/order_tracking_screen.dart';
import 'package:shahin_app/screens/driver/driver_tracking_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  final bool isDriver;

  const TripHistoryScreen({super.key, required this.isDriver});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final AuthRepository _authRepo = AuthRepository();
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final user = _authRepo.getCurrentUser();
    if (user == null) return;

    try {
      final column = widget.isDriver ? 'driver_id' : 'customer_id';
      final data = await SupabaseConfig.client
          .from('orders')
          .select(
              'id, status, pickup_location_text, dropoff_location_text, distance_km, estimated_price, created_at')
          .eq(column, user.id)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _trips = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب السجل: $e')),
        );
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
        return 'تم القبول';
      case 'driver_on_the_way':
        return 'السائق في الطريق';
      case 'arrived':
        return 'وصل السائق';
      case 'started':
        return 'جارية';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'driver_on_the_way':
      case 'arrived':
        return Colors.blue;
      case 'started':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  bool _isActiveOrder(String status) {
    return ['pending', 'accepted', 'driver_on_the_way', 'arrived', 'started']
        .contains(status);
  }

  void _openOrder(String orderId) {
    if (widget.isDriver) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverTrackingScreen(orderId: orderId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الطلبات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? const Center(child: Text('لا توجد طلبات سابقة'))
              : ListView.builder(
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    final date = DateTime.parse(trip['created_at']).toLocal();
                    final dateStr =
                        '${date.year}/${date.month}/${date.day} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
                    final isActive = _isActiveOrder(trip['status']);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        enabled: isActive, // لا يمكن النقر على الرحلات المنتهية
                        onTap: () => _openOrder(trip['id']),
                        title: Text(
                          '${trip['pickup_location_text']} → ${trip['dropoff_location_text']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'المسافة: ${trip['distance_km']?.toStringAsFixed(2) ?? "—"} كم'),
                            Text(
                                'السعر: ${trip['estimated_price']?.toStringAsFixed(0) ?? "—"} ج.س'),
                            Text(dateStr),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(trip['status'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(trip['status']),
                                ),
                              ),
                              child: Text(
                                _getStatusText(trip['status']),
                                style: TextStyle(
                                  color: _getStatusColor(trip['status']),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
