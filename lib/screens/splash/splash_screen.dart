import 'package:flutter/material.dart';
import 'package:shahin_app/widgets/app_logo.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'package:shahin_app/screens/onboarding/onboarding_screen.dart';
import 'package:shahin_app/screens/auth/login_screen.dart';
import 'package:shahin_app/screens/auth/create_profile_screen.dart';
import 'package:shahin_app/screens/customer/home_screen.dart';
import 'package:shahin_app/screens/driver/home_screen.dart';
import 'package:shahin_app/screens/driver/kyc_screen.dart';
import 'package:shahin_app/screens/shared/blocked_screen.dart';
import 'package:shahin_app/core/config/supabase_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthRepository _authRepo = AuthRepository();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = _authRepo.getCurrentUser();
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    final profile = await _authRepo.fetchUserProfile(user.id);
    if (profile == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CreateProfileScreen(phoneNumber: user.phone!),
        ),
      );
      return;
    }

    if (profile.status == 'blocked' || profile.status == 'suspended') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BlockedScreen()),
      );
      return;
    }

    if (!profile.isOnboarded) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    if (profile.role == 'customer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
      );
    } else if (profile.role == 'driver') {
      final driver = await SupabaseConfig.client
          .from('driver_profiles')
          .select('approval_status')
          .eq('user_id', user.id)
          .maybeSingle();
      if (driver?['approval_status'] == 'approved') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverKycScreen()),
        );
      }
    } else {
      await _authRepo.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(size: 140),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('جاري التحميل...'),
          ],
        ),
      ),
    );
  }
}
