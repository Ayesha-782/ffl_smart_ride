class AppNotification {
  final String id;
  final String userId;
  final String? rideId;
  final String title;
  final String message;
  final String type; // 'ride_confirmed', 'ride_cancelled', 'reminder'
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    this.rideId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      rideId: json['ride_id'] as String?,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (rideId != null) 'ride_id': rideId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
    };
  }
}
