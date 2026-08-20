import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_profile.dart';
import '../../admin/screens/admin_dashboard_shell.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return _UserProfileRouter(userId: session.user.id);
        }

        return const LoginScreen();
      },
    );
  }
}

class _UserProfileRouter extends StatefulWidget {
  final String userId;

  const _UserProfileRouter({required this.userId});

  @override
  State<_UserProfileRouter> createState() => _UserProfileRouterState();
}

class _UserProfileRouterState extends State<_UserProfileRouter> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void didUpdateWidget(covariant _UserProfileRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .maybeSingle();

      if (response != null) {
        final data = Map<String, dynamic>.from(response);

        // Fetch vehicle safely if user has vehicle flag
        if (data['has_vehicle'] == true) {
          try {
            final vehicleRes = await client
                .from('vehicles')
                .select('*')
                .eq('user_id', widget.userId)
                .maybeSingle();
            if (vehicleRes != null) {
              data['vehicles'] = [vehicleRes];
            }
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _profile = UserProfile.fromJson(data);
            _isLoading = false;
          });
        }
      } else {
        // Fallback default profile if row is not populated yet
        if (mounted) {
          setState(() {
            _profile = UserProfile(
              id: widget.userId,
              employeeId: 'EMP',
              fullName: 'User',
              role: 'user',
              isActive: true,
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading profile & permissions...',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load user profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _fetchProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Sign Out', style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const LoginScreen();
    }

    // Check account status
    if (!profile.isActive) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, size: 48, color: AppColors.error),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Account Deactivated',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your FFL Smart Ride account has been disabled by the administrator. Please contact Employee Services for assistance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Return to Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Role-based routing: Admin / Super Admin -> AdminDashboardShell; User -> HomeScreen
    if (profile.isAdmin) {
      return AdminDashboardShell(userProfile: profile);
    }

    return const HomeScreen();
  }
}
