import 'package:flutter/material.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'package:shahin_app/screens/auth/create_profile_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final AuthRepository _authRepo = AuthRepository();
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;

  void _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رمز التحقق')));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await _authRepo.verifyOTP(widget.phoneNumber, otp);
      if (!mounted) return;
      if (user != null) {
        final profile = await _authRepo.fetchUserProfile(user.id);
        if (profile != null && profile.isOnboarded) {
          Navigator.pushReplacementNamed(context, '/splash');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CreateProfileScreen(phoneNumber: widget.phoneNumber),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('رمز التحقق غير صحيح: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الرقم')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sms, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            Text(
              'أدخل رمز التحقق المرسل إلى ${widget.phoneNumber}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'مثال: 123456',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('تأكيد'),
                  ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إعادة إرسال الرمز'),
            ),
          ],
        ),
      ),
    );
  }
}
