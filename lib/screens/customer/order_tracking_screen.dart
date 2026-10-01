import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shahin_app/repositories/order_repository.dart';
import 'package:shahin_app/models/order_model.dart';
import 'package:shahin_app/screens/shared/rating_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final OrderRepository _orderRepo = OrderRepository();
  late Stream<OrderModel> _orderStream;
  OrderModel? _order;

  // بيانات السائق التي ستظهر بعد القبول
  String? _driverName;
  String? _driverPhone;
  String? _driverVehicle;
  String? _driverVehiclePlate;

  String? _driverLoadedFor; // السائق الذي جُلبت بياناته
  String? _pickupCode;
  bool _codeRequested = false;
  String? _deliveryCode;
  bool _deliveryRequested = false;
  String? _locDriverId;
  Stream<LatLng?>? _locStream; // موقع السائق الحي

  @override
  void initState() {
    super.initState();
    _orderStream = _orderRepo.listenToOrder(widget.orderId);
  }

  Future<void> _fetchPickupCode() async {
    try {
      final code = await _orderRepo.getPickupCode(widget.orderId);
      if (mounted) setState(() => _pickupCode = code);
    } catch (_) {
      _codeRequested = false; // نعيد المحاولة عند التحديث القادم
    }
  }

  Future<void> _fetchDeliveryCode() async {
    try {
      final code = await _orderRepo.getDeliveryCode(widget.orderId);
      if (mounted) setState(() => _deliveryCode = code);
    } catch (_) {
      _deliveryRequested = false; // نعيد المحاولة عند التحديث القادم
    }
  }

  Future<void> _fetchDriverInfo() async {
    try {
      final data = await _orderRepo.getTripContact(widget.orderId);
      if (!mounted) return;

      setState(() {
        _driverName = data?['full_name'] ?? 'سائق';
        _driverPhone = data?['phone'] ?? 'غير معروف';
        _driverVehicle = data?['vehicle_type_name'] ?? 'مركبة';
        _driverVehiclePlate = data?['vehicle_plate'] ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      // قيم افتراضية عند الفشل لضمان ظهور البطاقة
      setState(() {
        _driverName = 'سائق';
        _driverPhone = 'غير معروف';
        _driverVehicle = 'مركبة';
        _driverVehiclePlate = '';
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'جاري البحث عن سائق...';
      case 'accepted':
        return 'تم قبول الطلب';
      case 'driver_on_the_way':
        return 'السائق في الطريق إليك';
      case 'arrived':
        return 'وصل السائق';
      case 'started':
        return 'الرحلة جارية';
      case 'completed':
        return 'اكتملت الرحلة';
      default:
        return status;
    }
  }

  void _shareRide() {
    if (_order == null) return;
    final url =
        'https://www.openstreetmap.org/?mlat=${_order!.pickupLat}&mlon=${_order!.pickupLng}';
    Share.share('تابع رحلتي على نجـيـب: $url', subject: 'مشاركة موقع الرحلة');
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء الطلب؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، إلغاء')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _orderRepo.updateOrderStatus(_order!.id, 'cancelled');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الإلغاء: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تتبع الطلب')),
      body: StreamBuilder<OrderModel>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('خطأ: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          _order = snapshot.data!;

          // جلب معلومات السائق عند القبول (وعند تغيّر السائق)
          if (_order!.driverId != null &&
              _driverLoadedFor != _order!.driverId) {
            _driverLoadedFor = _order!.driverId;
            _fetchDriverInfo();
          } else if (_order!.driverId == null && _driverLoadedFor != null) {
            _driverLoadedFor = null;
            _driverName = null;
          }

          // متابعة موقع السائق الحي
          if (_order!.driverId != _locDriverId) {
            _locDriverId = _order!.driverId;
            _locStream = _locDriverId == null
                ? null
                : _orderRepo.listenToDriverLocation(_locDriverId!);
          }

          // كود الاستلام: يُطلب من السيرفر عند وصول السائق فقط
          if (_order!.status == 'arrived' && !_codeRequested) {
            _codeRequested = true;
            _fetchPickupCode();
          }

          // كود التسليم: يُطلب من السيرفر عند بدء الرحلة فقط
          if (_order!.status == 'started' && !_deliveryRequested) {
            _deliveryRequested = true;
            _fetchDeliveryCode();
          }

          // عند اكتمال الرحلة → انتقل إلى شاشة التقييم
          if (_order!.status == 'completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      RatingScreen(orderId: _order!.id, isCustomer: true),
                ),
              );
            });
            return const SizedBox();
          }

          final canCancel = ['pending', 'accepted', 'driver_on_the_way']
              .contains(_order!.status);

          return Column(
            children: [
              // صف الأزرار (مشاركة + إلغاء)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: _shareRide,
                      tooltip: 'مشاركة الرحلة',
                    ),
                    if (canCancel)
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: _cancelOrder,
                        tooltip: 'إلغاء الطلب',
                      ),
                  ],
                ),
              ),

              // معلومات الحالة
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _getStatusText(_order!.status),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_pickupCode != null && _order!.status == 'arrived')
                      Text(
                        'كود الاستلام: $_pickupCode',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                    if (_deliveryCode != null && _order!.status == 'started')
                      ...[
                      Text(
                        'كود التسليم: $_deliveryCode',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const Text('أعطه للسائق عند تسليم البضاعة'),
                    ],
                  ],
                ),
              ),

              // بطاقة معلومات السائق (تظهر بعد القبول دائمًا)
              if (_order!.driverId != null && _driverName != null)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _driverName ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '${_driverVehicle ?? ''} ${_driverVehiclePlate ?? ''}',
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () =>
                              launchUrl(Uri.parse('tel:${_driverPhone ?? ''}')),
                        ),
                        IconButton(
                          icon:
                              Icon(Icons.message, color: Colors.green.shade700),
                          onPressed: () => launchUrl(Uri.parse(
                              'https://wa.me/${(_driverPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '')}')),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // الخريطة
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(_order!.pickupLat, _order!.pickupLng),
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.shahin.app',
                    ),
                    StreamBuilder<LatLng?>(
                      stream: _locStream,
                      builder: (context, snap) {
                        final driverPos = snap.data;
                        return MarkerLayer(
                          markers: [
                            Marker(
                              point:
                                  LatLng(_order!.pickupLat, _order!.pickupLng),
                              child: const Icon(Icons.location_pin,
                                  color: Colors.green, size: 40),
                            ),
                            Marker(
                              point: LatLng(
                                  _order!.dropoffLat, _order!.dropoffLng),
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 40),
                            ),
                            if (driverPos != null)
                              Marker(
                                point: driverPos,
                                child: const Icon(Icons.local_shipping,
                                    color: Colors.blue, size: 36),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
