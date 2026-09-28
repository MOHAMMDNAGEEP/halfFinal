import 'package:flutter/material.dart';
import 'package:shahin_app/repositories/auth_repository.dart';
import 'package:shahin_app/repositories/vehicle_repository.dart';
import 'package:shahin_app/models/vehicle_type_model.dart';
import 'package:shahin_app/screens/customer/home_screen.dart';
import 'package:shahin_app/screens/driver/kyc_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  final String phoneNumber;
  const CreateProfileScreen({super.key, required this.phoneNumber});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final AuthRepository _authRepo = AuthRepository();
  final VehicleRepository _vehicleRepo = VehicleRepository();
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();

  String _role = 'customer';
  String? _selectedVehicleTypeId;
  List<VehicleTypeModel> _vehicleTypes = [];
  bool _loading = false;
  bool _loadingTypes = true;

  @override
  void initState() {
    super.initState();
    _fetchVehicleTypes();
  }

  Future<void> _fetchVehicleTypes() async {
    try {
      final types = await _vehicleRepo.getActiveVehicleTypes();
      setState(() {
        _vehicleTypes = types;
        _loadingTypes = false;
      });
    } catch (e) {
      setState(() => _loadingTypes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل أنواع المركبات: $e')),
      );
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _authRepo.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('خطأ في الجلسة')));
      return;
    }

    if (_role == 'driver' && _selectedVehicleTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار نوع المركبة')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _authRepo.upsertUserProfile(
        userId: user.id,
        phone: widget.phoneNumber,
        fullName: _fullNameController.text.trim(),
        city: _cityController.text.trim(),
        role: _role,
        vehicleTypeId: _role == 'driver' ? _selectedVehicleTypeId : null,
      );

      if (!mounted) return;
      if (_role == 'customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverKycScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ الملف الشخصي: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إكمال الملف الشخصي')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: widget.phoneNumber,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'الرجاء إدخال الاسم' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'المدينة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'الرجاء إدخال المدينة'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر دورك:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('عميل'),
                      value: 'customer',
                      groupValue: _role,
                      onChanged: (val) => setState(() => _role = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('سائق'),
                      value: 'driver',
                      groupValue: _role,
                      onChanged: (val) => setState(() => _role = val!),
                    ),
                  ),
                ],
              ),
              if (_role == 'driver') ...[
                const SizedBox(height: 16),
                _loadingTypes
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _selectedVehicleTypeId,
                        decoration: const InputDecoration(
                          labelText: 'نوع المركبة',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                        items: _vehicleTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type.id,
                            child: Text(type.name),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedVehicleTypeId = val),
                        validator: (val) =>
                            val == null ? 'الرجاء اختيار نوع المركبة' : null,
                      ),
              ],
              const SizedBox(height: 30),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('متابعة'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
