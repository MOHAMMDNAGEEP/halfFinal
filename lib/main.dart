import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/screens/splash/splash_screen.dart';
import 'package:shahin_app/widgets/connectivity_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const ShahinApp());
}

class ShahinApp extends StatelessWidget {
  const ShahinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نجـيـب',
      debugShowCheckedModeBanner: false,
      // اللغة العربية واتجاه الواجهة من اليمين لليسار
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // شريط تنبيه عند انقطاع الإنترنت يظهر في كل الشاشات
      builder: (context, child) =>
          ConnectivityBanner(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/splash': (context) => const SplashScreen(),
      },
    );
  }
}
