import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppExceptions {
  /// Converts raw Supabase/Postgrest/network errors into human-readable user messages
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_grant')) {
        return 'Incorrect email or password. Please verify and try again.';
      }
      if (msg.contains('user already registered') ||
          msg.contains('already exists')) {
        return 'An account with this email already exists. Please sign in.';
      }
      if (msg.contains('email_rate_limit_exceeded') ||
          msg.contains('over_email_send_rate_limit') ||
          msg.contains('email rate limit') ||
          msg.contains('rate limit exceeded')) {
        return 'Email rate limit reached (Free tier allows 3-4 confirmation emails/hour). To fix: In your Supabase Dashboard, go to Authentication -> Providers -> Email and turn OFF "Confirm email" for instant registration.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Please check your email and verify your account to proceed.';
      }
      if (msg.contains('network') || msg.contains('timeout')) {
        return 'Network error. Please check your internet connection.';
      }
      return error.message;
    }

    if (error is PostgrestException) {
      final details = error.details?.toString().toLowerCase() ?? '';
      final msg = error.message.toLowerCase();

      if (details.contains('employee_id') || msg.contains('employee_id')) {
        return 'This Employee ID is already registered to another account.';
      }
      if (details.contains('license_plate') || msg.contains('license_plate')) {
        return 'This Vehicle Number / License Plate is already registered.';
      }
      if (details.contains('duplicate key') || msg.contains('duplicate')) {
        return 'A record with this information already exists in the system.';
      }
      return error.message;
    }

    if (error is SocketException) {
      return 'No internet connection. Please verify your network and try again.';
    }

    final str = error.toString();
    if (str.contains('SocketException') || str.contains('Failed host lookup')) {
      return 'Unable to reach the server. Please check your internet connection.';
    }

    return 'An unexpected error occurred: ${str.replaceAll('Exception: ', '')}';
  }
}
