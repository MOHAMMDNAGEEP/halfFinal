import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// الإشعارات: حفظ توكن الجهاز في حساب المستخدم، وعرض الإشعار والتطبيق مفتوح.
/// أما والتطبيق مغلق أو في الخلفية فيعرضه نظام أندرويد تلقائياً.
class NotificationService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static bool _ready = false;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _msgSub;

  /// تُستدعى مرة واحدة عند تشغيل التطبيق (أي خطأ هنا لا يوقف التطبيق)
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return;
    }

    final auth = SupabaseConfig.client.auth;
    if (auth.currentUser != null) _register();
    auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _register();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _stop();
      }
    });
  }

  static Future<void> _register() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(); // يظهر طلب الإذن في أندرويد 13+
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);

      _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen(_saveToken);
      _msgSub?.cancel();
      _msgSub = FirebaseMessaging.onMessage.listen(_showInApp);
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      await SupabaseConfig.client
          .rpc('register_fcm_token', params: {'p_token': token});
    } catch (e) {
      debugPrint('save token failed: $e');
    }
  }

  static void _stop() {
    _tokenSub?.cancel();
    _msgSub?.cancel();
    _tokenSub = null;
    _msgSub = null;
  }

  /// نمسح التوكن من الحساب قبل تسجيل الخروج
  static Future<void> clearToken() async {
    try {
      final uid = SupabaseConfig.client.auth.currentUser?.id;
      if (uid == null) return;
      await SupabaseConfig.client
          .from('users')
          .update({'fcm_token': null}).eq('id', uid);
    } catch (_) {}
  }

  /// إشعار وصل والتطبيق مفتوح: نعرضه كشريط أعلى الشاشة
  static void _showInApp(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.title != null)
                Text(n.title!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              if (n.body != null) Text(n.body!),
            ],
          ),
        ),
      );
  }
}
