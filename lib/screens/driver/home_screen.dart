import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'package:shahin_app/repositories/order_repository.dart';
import 'package:shahin_app/repositories/vehicle_repository.dart';
import 'package:shahin_app/models/order_model.dart';
import 'package:shahin_app/screens/driver/driver_tracking_screen.dart';
import 'package:shahin_app/screens/shared/profile_screen.dart';
import 'package:shahin_app/screens/shared/trip_history_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final AuthRepository _authRepo = AuthRepository();
  final OrderRepository _orderRepo = OrderRepository();
  final VehicleRepository _vehicleRepo = VehicleRepository();

  bool _isOnline = false;
  bool _loadingOrders = false;
  List<OrderModel> _nearbyOrders = [];
  String? _driverVehicleTypeId;
  String? _userName;
  String? _userPhone;
  String? _userImageUrl;

  Timer? _retryTimer;
  int _currentRetryStep = 0;
  final List<double> _searchSteps = [10, 25, 50];

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
    _loadUserName();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final user = _authRepo.getCurrentUser();
    if (user == null) return;
    final data = await SupabaseConfig.client
        .from('users')
        .select('full_name, phone, profile_image_url')
        .eq('id', user.id)
        .single();
    if (!mounted) return;
    setState(() {
      _userName = data['full_name'];
      _userPhone = data['phone'];
      _userImageUrl = data['profile_image_url'];
    });
  }

  Future<void> _loadDriverInfo() async {
    final user = _authRepo.getCurrentUser();
    if (user == null) return;
    final profile = await SupabaseConfig.client
        .from('driver_profiles')
        .select('vehicle_type_id, is_online')
        .eq('user_id', user.id)
        .single();
    setState(() {
      _driverVehicleTypeId = profile['vehicle_type_id'];
      _isOnline = profile['is_online'] ?? false;
    });
  }

  Future<void> _toggleOnline(bool value) async {
    final user = _authRepo.getCurrentUser();
    if (user == null) return;
    await _orderRepo.setDriverOnlineStatus(user.id, value);
    setState(() => _isOnline = value);
    if (value) {
      await _startSearch();
    } else {
      _stopSearch();
      setState(() => _nearbyOrders = []);
    }
  }

  void _stopSearch() {
    _retryTimer?.cancel();
    _currentRetryStep = 0;
  }

  Future<void> _startSearch() async {
    _stopSearch();
    _currentRetryStep = 0;
    await _fetchNearbyOrdersWithRetry();
  }

  Future<void> _fetchNearbyOrdersWithRetry() async {
    if (!_isOnline || _driverVehicleTypeId == null) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('يجب منح صلاحية الموقع لاستقبال الطلبات')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'صلاحية الموقع مرفوضة بشكل دائم. يرجى تفعيلها من إعدادات الجهاز')),
      );
      return;
    }

    final isLocationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تفعيل خدمة الموقع (GPS)')),
      );
      return;
    }

    setState(() => _loadingOrders = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final double currentDistance = _searchSteps[_currentRetryStep];

      final orders = await _orderRepo.getNearbyOrdersForDriver(
        driverLat: position.latitude,
        driverLng: position.longitude,
        driverVehicleTypeId: _driverVehicleTypeId!,
        maxDistanceKm: currentDistance,
      );

      if (orders.isNotEmpty) {
        setState(() {
          _nearbyOrders = orders;
          _currentRetryStep = 0;
        });
        _stopSearch();
      } else {
        setState(() => _nearbyOrders = []);
        if (_currentRetryStep < _searchSteps.length - 1) {
          _currentRetryStep++;
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              _fetchNearbyOrdersWithRetry();
            }
          });
        } else {
          _stopSearch();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب الطلبات: $e')),
      );
    } finally {
      setState(() => _loadingOrders = false);
    }
  }

  // دالة قبول محسّنة مع تشخيص
  Future<void> _acceptOrder(OrderModel order) async {
    final user = _authRepo.getCurrentUser();
    if (user == null) return;

    final success = await _orderRepo.acceptOrder(order.id, user.id);

    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverTrackingScreen(orderId: order.id),
        ),
      );
    } else {
      // تشخيص سبب الفشل
      String errorMsg = 'عذراً، هذا الطلب لم يعد متاحاً';
      try {
        final updatedOrder = await _orderRepo.getOrder(order.id);
        if (updatedOrder.driverId != null) {
          errorMsg = 'عذراً، تم قبول هذا الطلب بواسطة سائق آخر';
        } else if (updatedOrder.status != 'pending') {
          errorMsg = 'عذراً، حالة الطلب الحالية هي: ${updatedOrder.status}';
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
      _startSearch(); // تحديث القائمة
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (الكود المتبقي للـ build كما هو تماماً دون تغيير)
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة السائق'),
        backgroundColor: Colors.blue.withOpacity(0.8),
        elevation: 0,
        actions: [
          Switch(
              value: _isOnline,
              onChanged: _toggleOnline,
              activeColor: Colors.green),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    backgroundImage:
                        (_userImageUrl != null && _userImageUrl!.isNotEmpty)
                            ? NetworkImage(_userImageUrl!)
                            : null,
                    child: (_userImageUrl == null || _userImageUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 36, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(_userName ?? 'السائق',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 18)),
                  Text(_userPhone ?? _authRepo.getCurrentUser()?.phone ?? '',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('الملف الشخصي'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen(isDriver: true)))
                    .then((_) => _loadUserName()); // تحديث الصورة والاسم بعد الرجوع
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('سجل الطلبات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const TripHistoryScreen(isDriver: true)));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _authRepo.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
      body: _isOnline
          ? _loadingOrders
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => await _startSearch(),
                  child: _nearbyOrders.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('لا توجد طلبات قريبة حالياً'),
                                  const SizedBox(height: 20),
                                  OutlinedButton(
                                    onPressed: () => _startSearch(),
                                    child: const Text('تحديث الطلبات'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _nearbyOrders.length,
                          itemBuilder: (context, index) {
                            final order = _nearbyOrders[index];
                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ListTile(
                                title: Text('طلب #${order.id.substring(0, 8)}'),
                                subtitle: Text(
                                    'المسافة: ${order.distanceKm?.toStringAsFixed(2)} كم'),
                                trailing: ElevatedButton(
                                  onPressed: () => _acceptOrder(order),
                                  child: const Text('قبول'),
                                ),
                              ),
                            );
                          },
                        ),
                )
          : const Center(child: Text('أنت غير متصل. فعّل المفتاح للاتصال.')),
    );
  }
}
