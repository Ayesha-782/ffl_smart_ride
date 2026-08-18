class SessionSchedule {
  final String id;
  final String slot; // 'morning', 'afternoon', 'evening'
  final String opensAt; // '06:30:00'
  final String closesAt; // '08:30:00'
  final bool isActive;

  const SessionSchedule({
    required this.id,
    required this.slot,
    required this.opensAt,
    required this.closesAt,
    this.isActive = true,
  });

  factory SessionSchedule.fromJson(Map<String, dynamic> json) {
    return SessionSchedule(
      id: json['id'] as String? ?? '',
      slot: json['slot'] as String? ?? 'morning',
      opensAt: json['opens_at'] as String? ?? '06:30:00',
      closesAt: json['closes_at'] as String? ?? '08:30:00',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slot': slot,
      'opens_at': opensAt,
      'closes_at': closesAt,
      'is_active': isActive,
    };
  }

  String get slotDisplayName {
    switch (slot.toLowerCase()) {
      case 'morning':
        return 'Morning Commute';
      case 'afternoon':
        return 'Afternoon Shift';
      case 'evening':
        return 'Evening Return';
      default:
        return slot;
    }
  }

  String get timeWindowFormatted {
    // Convert 06:30:00 -> 6:30 AM
    String formatTime(String time) {
      final parts = time.split(':');
      if (parts.length < 2) return time;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts[1];
      final ampm = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:$m $ampm';
    }

    return '${formatTime(opensAt)} - ${formatTime(closesAt)}';
  }
}
