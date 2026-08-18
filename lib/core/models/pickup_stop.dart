class PickupStop {
  final String id;
  final String name;
  final int stopOrder; // Proximity order along the township-to-factory route (e.g. 1, 2, 3...)
  final String description;
  final double? latitude;
  final double? longitude;

  const PickupStop({
    required this.id,
    required this.name,
    required this.stopOrder,
    required this.description,
    this.latitude,
    this.longitude,
  });

  factory PickupStop.fromJson(Map<String, dynamic> json) {
    return PickupStop(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      stopOrder: (json['stop_order'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stop_order': stopOrder,
      'description': description,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Official township & plant predefined pickup locations
  static const List<PickupStop> defaultStops = [
    PickupStop(
      id: 'stop_d_type',
      name: 'D Type',
      stopOrder: 1,
      description: 'D Type Residential Quarters',
    ),
    PickupStop(
      id: 'stop_e_type',
      name: 'E Type',
      stopOrder: 2,
      description: 'E Type Residential Quarters',
    ),
    PickupStop(
      id: 'stop_c_type',
      name: 'C Type',
      stopOrder: 3,
      description: 'C Type Residential Quarters',
    ),
    PickupStop(
      id: 'stop_management_club',
      name: 'Management Club / Mess',
      stopOrder: 4,
      description: 'Executive Management Club & Officers Mess',
    ),
    PickupStop(
      id: 'stop_gate_3',
      name: 'Gate 3 (Factory Gate)',
      stopOrder: 5,
      description: 'Factory Gate 3 Entrance',
    ),
    PickupStop(
      id: 'stop_ccr_1',
      name: 'CCR-1',
      stopOrder: 6,
      description: 'Central Control Room 1',
    ),
    PickupStop(
      id: 'stop_ccr_2',
      name: 'CCR-2',
      stopOrder: 7,
      description: 'Central Control Room 2',
    ),
  ];
}
