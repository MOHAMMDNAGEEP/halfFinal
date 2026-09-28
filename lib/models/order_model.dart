class OrderModel {
  final String id;
  final String customerId;
  final String? driverId;
  final String pickupLocationText;
  final double pickupLat;
  final double pickupLng;
  final String dropoffLocationText;
  final double dropoffLat;
  final double dropoffLng;
  final String? requiredVehicleTypeId; // 🔥 أصبح اختياريًا (String?)
  final String? description;
  final double? estimatedPrice;
  final double? finalPrice;
  final double? distanceKm;
  final String? pickupCode;
  final String status;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  OrderModel({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.pickupLocationText,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLocationText,
    required this.dropoffLat,
    required this.dropoffLng,
    this.requiredVehicleTypeId, // اختياري
    this.description,
    this.estimatedPrice,
    this.finalPrice,
    this.distanceKm,
    this.pickupCode,
    required this.status,
    this.cancellationReason,
    this.cancelledBy,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      customerId: json['customer_id'],
      driverId: json['driver_id'],
      pickupLocationText: json['pickup_location_text'],
      pickupLat: json['pickup_lat'],
      pickupLng: json['pickup_lng'],
      dropoffLocationText: json['dropoff_location_text'],
      dropoffLat: json['dropoff_lat'],
      dropoffLng: json['dropoff_lng'],
      requiredVehicleTypeId:
          json['required_vehicle_type_id'] as String?, // 👈 تحويل آمن
      description: json['description'],
      estimatedPrice: json['estimated_price']?.toDouble(),
      finalPrice: json['final_price']?.toDouble(),
      distanceKm: json['distance_km']?.toDouble(),
      pickupCode: json['pickup_code'],
      status: json['status'],
      cancellationReason: json['cancellation_reason'],
      cancelledBy: json['cancelled_by'],
      createdAt: DateTime.parse(json['created_at']),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }
}
