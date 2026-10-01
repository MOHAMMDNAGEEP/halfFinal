import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'package:shahin_app/repositories/vehicle_repository.dart';
import 'package:shahin_app/repositories/order_repository.dart';
import 'package:shahin_app/models/vehicle_type_model.dart';
import 'package:shahin_app/screens/customer/order_tracking_screen.dart';
import 'package:shahin_app/screens/shared/profile_screen.dart';
import 'package:shahin_app/screens/shared/trip_history_screen.dart';
import 'package:shahin_app/core/config/supabase_config.dart'; // أضفناه لاستخدام SupabaseConfig

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final MapController _mapController = MapController();
  final AuthRepository _authRepo = AuthRepository();
  final VehicleRepository _vehicleRepo = VehicleRepository();
  final OrderRepository _orderRepo = OrderRepository();

  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  String _pickupAddress = '';
  String _dropoffAddress = '';

  List<VehicleTypeModel> _vehicleTypes = [];
  String? _selectedVehicleTypeId;
  bool _loadingTypes = true;
  bool _isCreatingOrder = false;

  String? _userName; // متغير لحفظ الاسم
  String? _userPhone;
  String? _userImageUrl;

  @override
  void initState() {
    super.initState();
    _determineCurrentLocation();
    _fetchVehicleTypes();
    _loadUserName(); // تحميل الاسم
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

  Future<void> _determineCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _pickupLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_pickupLocation!, 14);
      _getAddressFromLatLng(_pickupLocation!, isPickup: true);
    } catch (e) {
      setState(() {
        _pickupLocation = const LatLng(15.5007, 32.5599);
      });
      _mapController.move(_pickupLocation!, 12);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng,
      {required bool isPickup}) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      final address =
          '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}';
      setState(() {
        if (isPickup) {
          _pickupAddress = address;
        } else {
          _dropoffAddress = address;
        }
      });
    } catch (e) {}
  }

  Future<void> _fetchVehicleTypes() async {
    try {
      final types = await _vehicleRepo.getActiveVehicleTypes();
      setState(() {
        _vehicleTypes = types;
        _loadingTypes = false;
      });
    } catch (e) {
      setState(() => _loadingTypes = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: const Text('نقطة الاستلام'),
              onTap: () {
                setState(() => _pickupLocation = latLng);
                _getAddressFromLatLng(latLng, isPickup: true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text('نقطة التسليم'),
              onTap: () {
                setState(() => _dropoffLocation = latLng);
                _getAddressFromLatLng(latLng, isPickup: false);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  double _calculateDistance() {
    if (_pickupLocation == null || _dropoffLocation == null) return 0.0;
    return const Distance()
        .as(LengthUnit.Kilometer, _pickupLocation!, _dropoffLocation!);
  }

  double _calculateEstimatedPrice() {
    if (_selectedVehicleTypeId == null) return 0.0;
    final vehicle =
        _vehicleTypes.firstWhere((v) => v.id == _selectedVehicleTypeId);
    final distance = _calculateDistance();
    return distance * vehicle.basePricePerKm;
  }

  Future<void> _createOrder() async {
    if (_pickupLocation == null || _dropoffLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد نقطتي الاستلام والتسليم')),
      );
      return;
    }
    if (_selectedVehicleTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار نوع المركبة')),
      );
      return;
    }

    final user = _authRepo.getCurrentUser();
    if (user == null) return;

    final distance = _calculateDistance();
    final price = _calculateEstimatedPrice();

    setState(() => _isCreatingOrder = true);
    try {
      final orderId = await _orderRepo.createOrder(
        customerId: user.id,
        pickupLocationText:
            _pickupAddress.isEmpty ? 'موقع الاستلام' : _pickupAddress,
        pickupLat: _pickupLocation!.latitude,
        pickupLng: _pickupLocation!.longitude,
        dropoffLocationText:
            _dropoffAddress.isEmpty ? 'موقع التسليم' : _dropoffAddress,
        dropoffLat: _dropoffLocation!.latitude,
        dropoffLng: _dropoffLocation!.longitude,
        requiredVehicleTypeId: _selectedVehicleTypeId!,
        description: null,
        estimatedPrice: price,
        distanceKm: distance,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: orderId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء الطلب: $e')),
      );
    } finally {
      setState(() => _isCreatingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ القائمة الجانبية (Drawer)
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
                  Text(
                      _userName ??
                          'العميل', // استبدلنا النص الثابت بالاسم المتغير
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
                Navigator.pop(context); // إغلاق الـ Drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen(isDriver: false)),
                ).then((_) => _loadUserName()); // تحديث الصورة والاسم بعد الرجوع
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
                      builder: (_) => const TripHistoryScreen(isDriver: false)),
                );
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
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
            ),
          ],
        ),
      ),
      // ✅ إضافة AppBar مع زر القائمة
      appBar: AppBar(
        title: const Text('نجـيـب', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.blue.withValues(alpha: 0.8),
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(15.5007, 32.5599),
              initialZoom: 12,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shahin.app',
              ),
              MarkerLayer(
                markers: [
                  if (_pickupLocation != null)
                    Marker(
                      point: _pickupLocation!,
                      child: const Icon(Icons.location_pin,
                          color: Colors.green, size: 40),
                    ),
                  if (_dropoffLocation != null)
                    Marker(
                      point: _dropoffLocation!,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        'استلام: ${_pickupAddress.isNotEmpty ? _pickupAddress : 'اضغط على الخريطة'}'),
                    Text(
                        'تسليم: ${_dropoffAddress.isNotEmpty ? _dropoffAddress : 'اضغط على الخريطة'}'),
                    const SizedBox(height: 10),
                    _loadingTypes
                        ? const CircularProgressIndicator()
                        : DropdownButtonFormField<String>(
                            value: _selectedVehicleTypeId,
                            decoration: const InputDecoration(
                              labelText: 'نوع المركبة',
                              border: OutlineInputBorder(),
                            ),
                            items: _vehicleTypes.map((type) {
                              return DropdownMenuItem(
                                value: type.id,
                                child: Text(
                                    '${type.name} - ${type.basePricePerKm.toStringAsFixed(0)} ج.س/كم'),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedVehicleTypeId = val),
                          ),
                    const SizedBox(height: 10),
                    if (_pickupLocation != null && _dropoffLocation != null)
                      Text(
                          'المسافة: ${_calculateDistance().toStringAsFixed(2)} كم'),
                    if (_selectedVehicleTypeId != null)
                      Text(
                          'السعر التقديري: ${_calculateEstimatedPrice().toStringAsFixed(0)} ج.س'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _isCreatingOrder ? null : _createOrder,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isCreatingOrder
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('إنشاء الطلب'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
