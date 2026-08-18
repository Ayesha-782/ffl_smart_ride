import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import 'supabase_service.dart';

class NotificationService {
  SupabaseClient get _supabase => SupabaseService.instance.client;

  /// Fetch all notifications for the current authenticated user
  Future<List<AppNotification>> getMyNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list.map((json) => AppNotification.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id);
  }

  /// Stream unread notifications count
  Stream<int> streamUnreadCount() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value(0);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .map((list) => list.where((n) => n['is_read'] == false).length);
  }

  /// Real-time stream of user notifications
  Stream<List<AppNotification>> streamNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return const Stream.empty();

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => AppNotification.fromJson(json)).toList());
  }
}
