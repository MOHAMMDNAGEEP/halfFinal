class VehicleTypeModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? capacity;
  final String category;
  final double basePricePerKm;
  final bool isActive;

  VehicleTypeModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.capacity,
    required this.category,
    required this.basePricePerKm,
    required this.isActive,
  });

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      capacity: json['capacity'],
      category: json['category'],
      basePricePerKm: json['base_price_per_km']?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
    );
  }
}
