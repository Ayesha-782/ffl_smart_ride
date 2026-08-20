import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../data/admin_repository.dart';

class AddUserDialog extends StatefulWidget {
  final AdminRepository adminRepository;
  final VoidCallback onUserAdded;

  const AddUserDialog({
    super.key,
    required this.adminRepository,
    required this.onUserAdded,
  });

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController(text: 'FFLSmartRide2025!');

  bool _hasVehicle = false;
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  int _capacity = 3;
  String _vehicleType = 'Car';

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _employeeIdController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic>? vehicleDetails;
      if (_hasVehicle) {
        vehicleDetails = {
          'vehicle_type': _vehicleType,
          'make': _makeController.text.trim(),
          'model': _modelController.text.trim(),
          'license_plate': _plateController.text.trim().toUpperCase(),
          'color': _colorController.text.trim().isNotEmpty
              ? _colorController.text.trim()
              : 'White',
          'capacity': _capacity,
        };
      }

      await widget.adminRepository.addUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        houseAddress: _addressController.text.trim(),
        nationalId: _nationalIdController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        vehicleDetails: vehicleDetails,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onUserAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Employee registered successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 750),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pre-Register Employee',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Creates Auth login & profile securely',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Basic Info
                _buildSectionHeader('Employee Information'),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nameController,
                        label: 'Full Name *',
                        hint: 'e.g. Sadia Tariq',
                        validator: Validators.validateFullName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _employeeIdController,
                        label: 'Employee ID *',
                        hint: 'e.g. FFL-1042',
                        validator: Validators.validateEmployeeId,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        label: 'Company Email *',
                        hint: 'sadia@ffl.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number *',
                        hint: '0300-1234567',
                        keyboardType: TextInputType.phone,
                        validator: Validators.validatePhone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nationalIdController,
                        label: 'National ID / CNIC *',
                        hint: '35201-1234567-1',
                        keyboardType: TextInputType.number,
                        validator: Validators.validateCnic,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _addressController,
                        label: 'Township House Address *',
                        hint: 'Sector A, House #14',
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Please enter valid house address'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _passwordController,
                  label: 'Initial Temporary Password *',
                  hint: 'Min 6 characters',
                  obscureText: true,
                  validator: Validators.validatePassword,
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('Vehicle Registration'),
                const SizedBox(height: 8),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Register as Carpool Driver (Owns Vehicle)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: const Text(
                    'Allows offering seats in scheduled ride shifts',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  value: _hasVehicle,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _hasVehicle = val),
                ),

                if (_hasVehicle) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _makeController,
                          label: 'Vehicle Make *',
                          hint: 'e.g. Toyota, Honda',
                          validator: (v) => _hasVehicle && (v == null || v.trim().length < 2)
                              ? 'Make is required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _modelController,
                          label: 'Model / Year *',
                          hint: 'e.g. Corolla 2021',
                          validator: (v) => _hasVehicle && (v == null || v.trim().length < 2)
                              ? 'Model is required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _plateController,
                          label: 'License Plate *',
                          hint: 'e.g. LEA-4920',
                          validator: (v) => _hasVehicle
                              ? Validators.validateLicensePlate(v, isRequired: true)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _colorController,
                          label: 'Color',
                          hint: 'e.g. Silver',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _vehicleType,
                          decoration: InputDecoration(
                            labelText: 'Vehicle Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Car', child: Text('Car / Sedan')),
                            DropdownMenuItem(value: 'SUV', child: Text('SUV / Crossover')),
                            DropdownMenuItem(value: 'Van', child: Text('Van / Microbus')),
                            DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
                          ],
                          onChanged: (v) => setState(() => _vehicleType = v ?? 'Car'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _capacity,
                          decoration: InputDecoration(
                            labelText: 'Passenger Capacity',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 Seat')),
                            DropdownMenuItem(value: 2, child: Text('2 Seats')),
                            DropdownMenuItem(value: 3, child: Text('3 Seats (Standard)')),
                            DropdownMenuItem(value: 4, child: Text('4 Seats')),
                            DropdownMenuItem(value: 6, child: Text('6 Seats (Van)')),
                          ],
                          onChanged: (v) => setState(() => _capacity = v ?? 3),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSubmitting ? 'Registering...' : 'Create Employee Account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
