class RideSession {
  final String id;
  final DateTime sessionDate;
  final String slot; // 'morning', 'afternoon', 'evening'
  final String status; // 'open', 'closed'
  final DateTime? createdAt;

  const RideSession({
    required this.id,
    required this.sessionDate,
    required this.slot,
    this.status = 'open',
    this.createdAt,
  });

  factory RideSession.fromJson(Map<String, dynamic> json) {
    return RideSession(
      id: json['id'] as String? ?? '',
      sessionDate: json['session_date'] != null
          ? (DateTime.tryParse(json['session_date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      slot: json['slot'] as String? ?? 'morning',
      status: json['status'] as String? ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_date': '${sessionDate.year.toString().padLeft(4, '0')}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}',
      'slot': slot,
      'status': status,
    };
  }

  String get slotDisplayName {
    switch (slot.toLowerCase()) {
      case 'morning':
        return 'Morning Commute (To Factory)';
      case 'afternoon':
        return 'Afternoon Shift (Mid-day)';
      case 'evening':
        return 'Evening Return (To Township)';
      default:
        return slot;
    }
  }

  bool get isOpen => status.toLowerCase() == 'open';
}
