import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/models/vehicle_type_model.dart';

class VehicleRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<VehicleTypeModel>> getActiveVehicleTypes() async {
    final data = await _client
        .from('vehicle_types')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List)
        .map((json) => VehicleTypeModel.fromJson(json))
        .toList();
  }
}
