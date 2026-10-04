import 'package:shahin_app/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/models/user_model.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  User? getCurrentUser() => _client.auth.currentUser;

  Future<void> sendOTP(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone, shouldCreateUser: true);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('حدث خطأ غير متوقع');
    }
  }

  Future<User?> verifyOTP(String phone, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      return response.user;
    } catch (e) {
      throw Exception('رمز التحقق غير صحيح');
    }
  }

  Future<void> signOut() async {
    // نمسح توكن الإشعارات قبل الخروج حتى لا تصل إشعارات الحساب لهذا الجهاز
    await NotificationService.clearToken();
    await _client.auth.signOut();
  }

  Future<UserModel?> fetchUserProfile(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<void> upsertUserProfile({
    required String userId,
    required String phone,
    required String fullName,
    required String city,
    required String role,
    String? vehicleTypeId,
  }) async {
    await _client.from('users').upsert({
      'id': userId,
      'phone': phone,
      'full_name': fullName,
      'city': city,
      'role': role,
      'is_onboarded': true,
      'updated_at': DateTime.now().toIso8601String(),
    });

    if (role == 'driver' && vehicleTypeId != null) {
      await _client.from('driver_profiles').upsert({
        'user_id': userId,
        'vehicle_type_id': vehicleTypeId,
        'approval_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
