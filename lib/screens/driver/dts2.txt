import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/repositories/order_repository.dart';
import 'package:shahin_app/models/order_model.dart';
import 'package:shahin_app/screens/shared/rating_screen.dart';

class DriverTrackingScreen extends StatefulWidget {
  final String orderId;
  const DriverTrackingScreen({super.key, required this.orderId});

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  late Stream<OrderModel> _orderStream;
  final TextEditingController _codeController = TextEditingController();
  OrderModel? _order; // لتتبع الحالة الحالية
  Timer? _locTimer;
  String? _customerPhone;

  @override
  void initState() {
    super.initState();
    _orderStream = _orderRepo.listenToOrder(widget.orderId);
    _loadCustomerPhone();
    _sendLocation();
    _locTimer = Timer.periodic(
        const Duration(seconds: 7), (_) => _sendLocation()); // موقع حي كل 7 ثواني
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerPhone() async {
    try {
      final c = await _orderRepo.getTripContact(widget.orderId);
      if (mounted) setState(() => _customerPhone = c?['phone'] as String?);
    } catch (_) {}
  }

  Future<void> _sendLocation() async {
    // نرسل الموقع فقط أثناء الرحلة النشطة
    const active = ['accepted', 'driver_on_the_way', 'arrived', 'started'];
    if (_order != null && !active.contains(_order!.status)) return;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final uid = SupabaseConfig.client.auth.currentUser?.id;
      if (uid == null) return;
      final p = await Geolocator.getCurrentPosition();
      await _orderRepo.upsertDriverLocation(
        driverId: uid,
        orderId: widget.orderId,
        lat: p.latitude,
        lng: p.longitude,
        heading: p.heading,
        speed: p.speed,
      );
    } catch (_) {}
  }

  Future<void> _updateStatus(String status) async {
    try {
      await _orderRepo.updateOrderStatus(widget.orderId, status);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديث الحالة: $e')),
      );
    }
  }

  void _shareRide() async {
    final order = await _orderRepo.getOrder(widget.orderId);
    final url =
        'https://www.openstreetmap.org/?mlat=${order.pickupLat}&mlon=${order.pickupLng}';
    Share.share('أنا في الطريق إليك: $url', subject: 'مشاركة موقع السائق');
  }

  Future<void> _cancelDriverAcceptance() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء القبول'),
        content: const Text('سيتم إعادة الطلب لباقي السائقين. متأكد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم')),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseConfig.client.from('orders').update({
        'status': 'pending',
        'driver_id': null,
        'accepted_at': null,
      }).eq('id', widget.orderId);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _showCodeDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أدخل كود الاستلام'),
        content: TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(hintText: 'الكود المكون من 4 أرقام'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              // التحقق من الكود يتم في السيرفر (الكود لا ينزل لجهاز السائق)
              String result;
              try {
                result = await _orderRepo.startTrip(
                    widget.orderId, _codeController.text.trim());
              } catch (_) {
                result = 'error';
              }
              if (!mounted) return;
              if (result == 'ok') {
                _codeController.clear();
                Navigator.pop(context);
              } else {
                final msg = result == 'wrong_code'
                    ? 'الكود غير صحيح'
                    : result == 'locked'
                        ? 'تم إيقاف المحاولات مؤقتاً، حاول بعد 10 دقائق'
                        : 'تعذّر التحقق من الكود، حاول مرة أخرى';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(OrderModel order) {
    switch (order.status) {
      case 'accepted':
        return ElevatedButton(
          onPressed: () => _updateStatus('driver_on_the_way'),
          child: const Text('الانطلاق إلى العميل'),
        );
      case 'driver_on_the_way':
        return ElevatedButton(
          onPressed: () => _updateStatus('arrived'),
          child: const Text('وصلت إلى موقع الاستلام'),
        );
      case 'arrived':
        return ElevatedButton(
          onPressed: _showCodeDialog,
          child: const Text('إدخال كود الاستلام وبدء الرحلة'),
        );
      case 'started':
        return ElevatedButton(
          onPressed: () => _updateStatus('completed'),
          child: const Text('تم التسليم'),
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الرحلة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareRide,
            tooltip: 'مشاركة الرحلة',
          ),
          if (_order != null &&
              ['accepted', 'driver_on_the_way'].contains(_order!.status))
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: _cancelDriverAcceptance,
              tooltip: 'إلغاء القبول',
            ),
        ],
      ),
      body: StreamBuilder<OrderModel>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data!;
          _order = order; // تحديث الحالة

          // عند اكتمال الرحلة → انتقل إلى شاشة التقييم
          if (order.status == 'completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => RatingScreen(
                    orderId: order.id,
                    isCustomer: false,
                  ),
                ),
              );
            });
            return const SizedBox();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('الحالة: ${order.status}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (order.status == 'arrived')
                      const Text('الكود مع العميل',
                          style: TextStyle(color: Colors.blue)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.phone),
                          onPressed: _customerPhone == null
                              ? null
                              : () => launchUrl(
                                  Uri.parse('tel:$_customerPhone')),
                        ),
                        IconButton(
                          icon: const Icon(Icons.navigation),
                          onPressed: () => launchUrl(Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&destination=${order.pickupLat},${order.pickupLng}')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(order.pickupLat, order.pickupLng),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.shahin.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(order.pickupLat, order.pickupLng),
                          child: const Icon(Icons.location_pin,
                              color: Colors.green, size: 40),
                        ),
                        Marker(
                          point: LatLng(order.dropoffLat, order.dropoffLng),
                          child: const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildActionButton(order),
              ),
            ],
          );
        },
      ),
    );
  }
}
