import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://xsuhheowslpqizpjljzh.supabase.co';
  static const String anonKey =
      'sb_publishable_poJorT8I7gxpiSttgD6dEg_uFlDXgep';
  static SupabaseClient get client => Supabase.instance.client;
}
