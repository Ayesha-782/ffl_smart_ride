import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/validators.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';
import '../../registration/screens/registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authRepository.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.user == null) {
        throw Exception('Login failed. Please verify your credentials.');
      }

      // Route through AuthGate for role-based dashboard redirection
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.authGate,
        (route) => false,
      );
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

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your registered work email to receive password reset instructions.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Work Email Address',
                  hintText: 'employee@ffl.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isResetting
                  ? null
                  : () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Please enter a valid work email address'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isResetting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await _authRepository.resetPassword(email);
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Password reset link sent to your email.'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isResetting = false);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(AppExceptions.getErrorMessage(e)),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
              child: isResetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Link'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48, // 48 = vertical padding (24*2)
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AuthCard(
                      maxWidth: 460,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              // 1. Branding Header
                              const AuthHeader(
                                title: 'Welcome Back 👋',
                                subtitle: 'Sign in to access your employee commute & carpooling portal.',
                                badgeText: 'FFL SMART RIDE',
                                icon: Icons.directions_car_rounded,
                              ),
                              const SizedBox(height: 28),

                              // 2. Email Field
                              AuthTextField(
                                controller: _emailController,
                                label: 'Work Email',
                                hint: 'employee@ffl.com',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                                },
                                validator: Validators.validateEmail,
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 18),

                              // 3. Password Field with Visibility Toggle
                              AuthTextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                label: 'Password',
                                hint: '••••••••',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                validator: Validators.validatePassword,
                                enabled: !_isLoading,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                ),
                              ),
                              const SizedBox(height: 8),

                              // 4. Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),

                              // 5. Sign In Action Button
                              AuthPrimaryButton(
                                text: 'Sign In',
                                isLoading: _isLoading,
                                icon: Icons.login_rounded,
                                onPressed: _login,
                              ),
                              const SizedBox(height: 24),

                              // 6. Visual Divider
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: AppColors.border)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: AppColors.border)),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // 7. Create Account Link
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const RegistrationScreen(),
                                          ),
                                        );
                                      },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text.rich(
                                  TextSpan(
                                    text: "Don't have an account? ",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Create Account',
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
                            ],
                          ),
                        ),
                      ),

                      // Footer note for corporate security
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'FFL Smart Ride • Internal Factory Commute Portal',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
  }
}
