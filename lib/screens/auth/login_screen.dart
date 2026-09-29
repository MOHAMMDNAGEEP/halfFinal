import 'package:flutter/material.dart';
import 'package:shahin_app/widgets/app_logo.dart';
import 'package:shahin_app/widgets/sudan_flag.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'package:shahin_app/screens/auth/otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthRepository _authRepo = AuthRepository();
  final TextEditingController _phoneController = TextEditingController();
  String _countryCode = '+249';
  bool _loading = false;

  void _sendOTP() async {
    final phoneNumber = '$_countryCode${_phoneController.text.trim()}';
    if (_phoneController.text.trim().isEmpty ||
        _phoneController.text.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم هاتف صحيح')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _authRepo.sendOTP(phoneNumber);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(phoneNumber: phoneNumber),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل إرسال رمز التحقق: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 110),
            const SizedBox(height: 30),
            const Text(
              'أدخل رقم هاتفك للمتابعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // رقم الهاتف يبقى من اليسار لليمين (كود الدولة ثم الرقم)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: _countryCode,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        // علم السودان للكود +249، وأيقونة عامة لأي كود آخر
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _countryCode.trim() == '+249'
                              ? const SudanFlag()
                              : const Icon(Icons.flag, size: 20),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                      onChanged: (val) => setState(() => _countryCode = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _sendOTP,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إرسال رمز التحقق'),
                  ),
          ],
        ),
      ),
    );
  }
}
