import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shahin_app/core/config/supabase_config.dart';

/// شريط تنبيه أعلى التطبيق يظهر عندما لا يوجد اتصال فعلي بالإنترنت،
/// ويختفي تلقائياً عند عودة الاتصال. يعمل في كل شاشات التطبيق.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _offline = false;
  bool _checking = false;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  /// نحاول فتح اتصال فعلي بخادم التطبيق (Supabase)، فيكشف حتى حالة
  /// "متصل بشبكة لكن بدون إنترنت" (مثل انتهاء رصيد البيانات).
  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    bool ok;
    try {
      final host = Uri.parse(SupabaseConfig.url).host;
      final socket =
          await Socket.connect(host, 443, timeout: const Duration(seconds: 4));
      socket.destroy();
      ok = true;
    } catch (_) {
      ok = false;
    }
    _checking = false;
    if (!mounted) return;
    _failures = ok ? 0 : _failures + 1;
    final offline = _failures >= 2; // فشلان متتاليان حتى لا يومض الشريط
    if (offline != _offline) setState(() => _offline = offline);
  }

  Widget _banner() {
    if (!_offline) return const SizedBox.shrink();
    return Material(
      color: Colors.red.shade700,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () {
            _failures = 1; // إعادة فحص فورية
            _check();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لا يوجد اتصال بالإنترنت',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        'فعّل بيانات الجوال أو الواي فاي. اضغط لإعادة المحاولة.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الشريط في خانة ثابتة فوق المحتوى حتى لا تُعاد بناء الشاشات عند ظهوره
    return Column(
      children: [
        _banner(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: _offline, // الشريط يغطي منطقة شريط الحالة
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
