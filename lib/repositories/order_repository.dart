import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/models/order_model.dart';

class OrderRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // ==========================================
  // قسم العميل (Customer Functions)
  // ==========================================

  /// إنشاء طلب جديد
  Future<String> createOrder({
    required String customerId,
    required String pickupLocationText,
    required double pickupLat,
    required double pickupLng,
    required String dropoffLocationText,
    required double dropoffLat,
    required double dropoffLng,
    required String requiredVehicleTypeId,
    String? description,
    required double estimatedPrice,
    required double distanceKm,
  }) async {
    final data = await _client
        .from('orders')
        .insert({
          'customer_id': customerId,
          'pickup_location_text': pickupLocationText,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_location_text': dropoffLocationText,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          'required_vehicle_type_id': requiredVehicleTypeId,
          'description': description,
          'estimated_price': estimatedPrice,
          'distance_km': distanceKm,
          'status': 'pending',
        })
        .select('id')
        .single();

    return data['id'] as String;
  }

  /// الاستماع لتغيرات طلب معين (لتتبع الحالة والمسار)
  Stream<OrderModel> listenToOrder(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((data) => OrderModel.fromJson(data.first));
  }

  /// جلب تفاصيل طلب واحد
  Future<OrderModel> getOrder(String orderId) async {
    final data =
        await _client.from('orders').select().eq('id', orderId).single();
    return OrderModel.fromJson(data);
  }

  // ==========================================
  // قسم السائق (Driver Functions)
  // ==========================================

  /// جلب الطلبات القريبة والمتاحة للسائق
  Future<List<OrderModel>> getNearbyOrdersForDriver({
    required double driverLat,
    required double driverLng,
    required String driverVehicleTypeId,
    double maxDistanceKm = 10,
  }) async {
    final data = await _client.rpc('get_nearby_orders_for_driver', params: {
      'driver_lat': driverLat,
      'driver_lng': driverLng,
      'driver_vehicle_type_id': driverVehicleTypeId,
      'max_distance_km': maxDistanceKm,
    });
    return (data as List).map((json) => OrderModel.fromJson(json)).toList();
  }

  /// قبول الطلب (تم تصحيح .filter بدل .is_)
  Future<bool> acceptOrder(String orderId, String driverId) async {
    try {
      final response = await _client
          .from('orders')
          .update({
            'driver_id': driverId,
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('status', 'pending')
          .filter('driver_id', 'is', null) // 👈 التصحيح هنا
          .select('id')
          .maybeSingle(); // استخدام maybeSingle لتجنب Exception إذا لم يتحقق الشرط

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// تحديث حالة الطلب خلال الرحلة
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final updates = <String, dynamic>{'status': newStatus};

    final now = DateTime.now().toIso8601String();
    if (newStatus == 'arrived') {
      updates['arrived_at'] = now;
    } else if (newStatus == 'started') {
      updates['started_at'] = now;
    } else if (newStatus == 'completed') {
      updates['completed_at'] = now;
    }

    await _client.from('orders').update(updates).eq('id', orderId);
  }

  /// تحديث موقع السائق الحالي
  Future<void> updateDriverLocation({
    required String userId,
    required double lat,
    required double lng,
  }) async {
    await _client.from('driver_profiles').update({
      'current_lat': lat,
      'current_lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }

  /// تغيير حالة اتصال السائق
  Future<void> setDriverOnlineStatus(String userId, bool isOnline) async {
    await _client.from('driver_profiles').update({
      'is_online': isOnline,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }

  // ==========================================
  // كود الاستلام والتتبع (تعتمد على دوال الداتا بيز الجديدة)
  // ==========================================

  /// السائق يدخل الكود، والتحقق يتم في السيرفر.
  /// النتيجة: ok | wrong_code | locked | not_allowed
  Future<String> startTrip(String orderId, String code) async {
    final res = await _client
        .rpc('start_trip', params: {'p_order_id': orderId, 'p_code': code});
    return res as String;
  }

  /// السائق يدخل كود التسليم لإنهاء الرحلة (التحقق في السيرفر).
  /// النتيجة: ok | wrong_code | locked | not_allowed
  Future<String> completeTrip(String orderId, String code) async {
    final res = await _client
        .rpc('complete_trip', params: {'p_order_id': orderId, 'p_code': code});
    return res as String;
  }

  /// كود التسليم للعميل فقط (يرجع null إن لم تكن الحالة started)
  Future<String?> getDeliveryCode(String orderId) async {
    final res =
        await _client.rpc('get_delivery_code', params: {'p_order_id': orderId});
    return res as String?;
  }

  /// كود الاستلام للعميل فقط (يرجع null إن لم تكن الحالة arrived)
  Future<String?> getPickupCode(String orderId) async {
    final res =
        await _client.rpc('get_pickup_code', params: {'p_order_id': orderId});
    return res as String?;
  }

  /// بيانات الطرف الآخر في الرحلة: full_name, phone, vehicle_type_name, vehicle_plate
  Future<Map<String, dynamic>?> getTripContact(String orderId) async {
    final res =
        await _client.rpc('get_trip_contact', params: {'p_order_id': orderId});
    final list = res as List;
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  /// السائق يرسل موقعه الحي (صف واحد لكل سائق)
  Future<void> upsertDriverLocation({
    required String driverId,
    required String orderId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    await _client.from('driver_live_locations').upsert({
      'driver_id': driverId,
      'order_id': orderId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
    });
  }

  /// العميل يتابع موقع السائق لحظياً
  Stream<LatLng?> listenToDriverLocation(String driverId) {
    return _client
        .from('driver_live_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .map((rows) {
          if (rows.isEmpty) return null;
          final r = rows.first;
          return LatLng(
              (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
        });
  }
}
