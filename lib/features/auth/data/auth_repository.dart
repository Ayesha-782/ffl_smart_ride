import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/supabase_service.dart';

class AuthRepository {
  SupabaseClient get _supabase => SupabaseService.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isAuthenticated => currentUser != null && currentSession != null;

  /// Stream of authentication state changes (handles auto-refresh, login, logout, token refresh)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Fetch user profile by user ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select('''
            *,
            vehicles (
              id,
              vehicle_type,
              make,
              model,
              license_plate,
              capacity
            )
          ''')
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        return UserProfile.fromJson(data);
      }

      final fallbackData = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (fallbackData != null) {
        return UserProfile.fromJson(fallbackData);
      }
    } catch (_) {}
    return null;
  }

  /// Alias for compatibility
  Future<UserProfile?> getProfile(String userId) => getUserProfile(userId);

  /// Fetch current logged-in user profile
  Future<UserProfile?> getMyProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return getUserProfile(user.id);
  }

  /// Sign In with Email & Password
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return response;
  }

  /// Sign Out and fully purge local session
  Future<void> signOut() async {
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email.trim());
  }
}
