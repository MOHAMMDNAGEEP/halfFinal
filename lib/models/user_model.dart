class UserModel {
  final String id;
  final String phone;
  final String? fullName;
  final String role;
  final String status;
  final String? city;
  final String? profileImageUrl;
  final bool isOnboarded;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.phone,
    this.fullName,
    required this.role,
    required this.status,
    this.city,
    this.profileImageUrl,
    required this.isOnboarded,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      phone: json['phone'],
      fullName: json['full_name'],
      role: json['role'],
      status: json['status'],
      city: json['city'],
      profileImageUrl: json['profile_image_url'],
      isOnboarded: json['is_onboarded'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
