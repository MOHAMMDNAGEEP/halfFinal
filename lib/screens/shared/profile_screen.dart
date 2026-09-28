import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shahin_app/core/config/supabase_config.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final bool isDriver; // true = سائق (يمكنه فقط عرض البيانات وتغيير الصورة)

  const ProfileScreen({super.key, required this.isDriver});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepo = AuthRepository();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  String? _fullName;
  String? _phone;
  String? _city;
  String? _profileImageUrl;
  String? _approvalStatus;
  String? _vehicleTypeName;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _authRepo.getCurrentUser();
    if (user == null) return;

    try {
      final data = await SupabaseConfig.client
          .from('users')
          .select('full_name, phone, city, profile_image_url')
          .eq('id', user.id)
          .single();

      setState(() {
        _fullName = data['full_name'];
        _phone = data['phone'];
        _city = data['city'];
        _profileImageUrl = data['profile_image_url'];
      });

      if (widget.isDriver) {
        final driverData = await SupabaseConfig.client
            .from('driver_profiles')
            .select('approval_status, vehicle_type:vehicle_type_id(name)')
            .eq('user_id', user.id)
            .single();

        setState(() {
          _approvalStatus = driverData['approval_status'];
          _vehicleTypeName = driverData['vehicle_type']?['name'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الملف: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = _authRepo.getCurrentUser();
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await SupabaseConfig.client.from('users').update({
        'full_name': _fullName,
        'city': _city,
      }).eq('id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الملف الشخصي')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحديث: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final user = _authRepo.getCurrentUser();
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final fileName = '${user.id}_profile.jpg';
      await SupabaseConfig.client.storage.from('driver-docs').upload(
            fileName,
            File(image.path),
            fileOptions: const FileOptions(upsert: true), // يسمح بتغيير الصورة أكثر من مرة
          );

      final url =
          '${SupabaseConfig.client.storage.from('driver-docs').getPublicUrl(fileName)}?t=${DateTime.now().millisecondsSinceEpoch}';

      await SupabaseConfig.client.from('users').update({
        'profile_image_url': url,
      }).eq('id', user.id);

      setState(() => _profileImageUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير الصورة بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تغيير الصورة: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // صورة الملف
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _changePhoto,
                        child: const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // رقم الهاتف (معطل دائمًا)
              TextFormField(
                initialValue: _phone,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),

              // الاسم (معطل للسائق)
              TextFormField(
                initialValue: _fullName,
                enabled: !widget.isDriver,
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                  hintText:
                      widget.isDriver ? 'يمكن للأدمن فقط تعديل الاسم' : null,
                ),
                onSaved: (val) => _fullName = val,
                validator: widget.isDriver
                    ? null
                    : (v) =>
                        v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // المدينة (معطلة للسائق)
              TextFormField(
                initialValue: _city,
                enabled: !widget.isDriver,
                decoration: InputDecoration(
                  labelText: 'المدينة',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_city),
                  hintText:
                      widget.isDriver ? 'يمكن للأدمن فقط تعديل المدينة' : null,
                ),
                onSaved: (val) => _city = val,
              ),
              const SizedBox(height: 16),

              // معلومات خاصة بالسائق
              if (widget.isDriver) ...[
                TextFormField(
                  initialValue: _vehicleTypeName ?? 'غير محدد',
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'نوع المركبة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping),
                    hintText: 'لتغيير المركبة، اطلب من الأدمن',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _approvalStatus ?? 'pending',
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'حالة التوثيق',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.verified),
                  ),
                ),
                const SizedBox(height: 16),
                // رسالة للسائق
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لتعديل الاسم، المدينة، أو نوع المركبة، يرجى التواصل مع الإدارة.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // زر الحفظ (للعميل فقط)
              if (!widget.isDriver)
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('حفظ التعديلات'),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
