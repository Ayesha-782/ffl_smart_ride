import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/validators.dart';
import '../../auth/widgets/auth_card.dart';
import '../../auth/widgets/auth_header.dart';
import '../../auth/widgets/auth_primary_button.dart';
import '../../auth/widgets/auth_section_card.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../data/registration_repository.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _homeAddressController = TextEditingController();

  // Vehicle Controllers
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _licensePlateController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasVehicle = true;
  String _selectedVehicleType = 'Car';

  final _registrationRepository = RegistrationRepository();
  final List<String> _vehicleTypes = ['Car', 'Motorbike', 'SUV', 'Van'];

  @override
  void dispose() {
    _fullNameController.dispose();
    _employeeIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _homeAddressController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final registrationData = RegistrationData(
        fullName: _fullNameController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        homeAddress: _homeAddressController.text.trim(),
        hasVehicle: _hasVehicle,
        vehicleType: _hasVehicle ? _selectedVehicleType : null,
        make: _hasVehicle ? _makeController.text.trim() : null,
        model: _hasVehicle ? _modelController.text.trim() : null,
        licensePlate: _hasVehicle ? _licensePlateController.text.trim() : null,
      );

      final response = await _registrationRepository.registerUser(registrationData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Account created successfully! Welcome to FFL Smart Ride.'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );

      // If user session is active immediately, route to /home
      if (response.session != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Please check your work email to confirm your account.'),
                ),
              ],
            ),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;

      final message = AppExceptions.getErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Create Employee Account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Sign In',
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: AuthCard(
              maxWidth: 620,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header
                    const AuthHeader(
                      title: 'Join Employee Ride Share 🚗',
                      subtitle: 'Register once to request rides as a passenger or offer seats as a driver.',
                      badgeText: 'EMPLOYEE REGISTRATION',
                      icon: Icons.person_add_alt_1_rounded,
                    ),
                    const SizedBox(height: 28),

                    // ==========================================
                    // 2. SECTION 1: EMPLOYEE DETAILS
                    // ==========================================
                    AuthSectionCard(
                      title: 'Employee Details',
                      icon: Icons.badge_outlined,
                      subtitle: 'Basic contact and company identification',
                      child: Column(
                        children: [
                          AuthTextField(
                            controller: _fullNameController,
                            label: 'Full Name',
                            hint: 'e.g. Muhammad Ali',
                            prefixIcon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: Validators.validateFullName,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 14),
                          AuthTextField(
                            controller: _employeeIdController,
                            label: 'Employee / National ID',
                            hint: 'e.g. FFL-10492',
                            prefixIcon: Icons.badge_outlined,
                            textCapitalization: TextCapitalization.characters,
                            validator: Validators.validateEmployeeId,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 14),
                          AuthTextField(
                            controller: _emailController,
                            label: 'Work Email Address',
                            hint: 'employee@ffl.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.validateEmail,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 14),
                          AuthTextField(
                            controller: _phoneController,
                            label: 'Phone / WhatsApp Number',
                            hint: '0300-1234567',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: Validators.validatePhone,
                            enabled: !_isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 3. SECTION 2: ACCOUNT SECURITY
                    // ==========================================
                    AuthSectionCard(
                      title: 'Account Security',
                      icon: Icons.security_outlined,
                      subtitle: 'Set a secure password for your account',
                      child: Column(
                        children: [
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'At least 6 characters',
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            validator: Validators.validatePassword,
                            enabled: !_isLoading,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                            ),
                          ),
                          const SizedBox(height: 14),
                          AuthTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            prefixIcon: Icons.lock_clock_outlined,
                            obscureText: _obscureConfirmPassword,
                            validator: (val) => Validators.validateConfirmPassword(val, _passwordController.text),
                            enabled: !_isLoading,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 4. SECTION 3: RESIDENTIAL ADDRESS
                    // ==========================================
                    AuthSectionCard(
                      title: 'Home Address',
                      icon: Icons.home_rounded,
                      subtitle: 'Used for ride request pickup and resident stop matching',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuthTextField(
                            controller: _homeAddressController,
                            label: 'Home Address',
                            hint: 'e.g. House 14, Street 3, D Type',
                            prefixIcon: Icons.home_outlined,
                            maxLines: 2,
                            validator: (val) => Validators.validateRequired(val, 'Home address'),
                            enabled: !_isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 5. SECTION 4: VEHICLE INFO (DRIVER)
                    // ==========================================
                    AuthSectionCard(
                      title: 'Vehicle Information (Optional)',
                      icon: Icons.directions_car_filled_outlined,
                      subtitle: 'Enable if you plan to offer carpool seats',
                      trailing: Switch.adaptive(
                        value: _hasVehicle,
                        activeTrackColor: AppColors.primary,
                        onChanged: _isLoading ? null : (val) => setState(() => _hasVehicle = val),
                      ),
                      child: AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _hasVehicle ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        secondChild: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You are registering as a Passenger only. You can add a vehicle later.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        firstChild: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedVehicleType,
                              decoration: _dropdownDecoration('Vehicle Type', Icons.category_outlined),
                              items: _vehicleTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type, style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: _isLoading ? null : (type) {
                                if (type != null) {
                                  setState(() => _selectedVehicleType = type);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: AuthTextField(
                                    controller: _makeController,
                                    label: 'Vehicle Make',
                                    hint: 'e.g. Toyota',
                                    prefixIcon: Icons.branding_watermark_outlined,
                                    textCapitalization: TextCapitalization.words,
                                    validator: (val) => _hasVehicle ? Validators.validateRequired(val, 'Make') : null,
                                    enabled: !_isLoading,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AuthTextField(
                                    controller: _modelController,
                                    label: 'Model / Variant',
                                    hint: 'e.g. Corolla',
                                    prefixIcon: Icons.model_training_outlined,
                                    textCapitalization: TextCapitalization.words,
                                    validator: (val) => _hasVehicle ? Validators.validateRequired(val, 'Model') : null,
                                    enabled: !_isLoading,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            AuthTextField(
                              controller: _licensePlateController,
                              label: 'License Plate / Vehicle Number',
                              hint: 'e.g. LEA-2024 or ABC-123',
                              prefixIcon: Icons.pin_outlined,
                              textCapitalization: TextCapitalization.characters,
                              validator: (val) => Validators.validateLicensePlate(val, isRequired: _hasVehicle),
                              enabled: !_isLoading,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ==========================================
                    // 6. SUBMIT BUTTON
                    // ==========================================
                    AuthPrimaryButton(
                      text: 'Complete Registration',
                      isLoading: _isLoading,
                      icon: Icons.how_to_reg_rounded,
                      onPressed: _register,
                    ),
                    const SizedBox(height: 20),

                    // 7. Sign In Link
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
