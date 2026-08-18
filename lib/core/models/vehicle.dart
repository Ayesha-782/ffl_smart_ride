class Vehicle {
  final String id;
  final String userId;
  final String vehicleType; // e.g. 'Car', 'Motorbike', 'SUV', 'Van'
  final String make;        // e.g. 'Toyota', 'Honda', 'Suzuki'
  final String model;       // e.g. 'Corolla', 'Civic', 'Alto'
  final String licensePlate;// e.g. 'LEA-2024'
  final String? color;
  final int capacity;
  final DateTime? createdAt;

  const Vehicle({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.make,
    required this.model,
    required this.licensePlate,
    this.color,
    this.capacity = 3,
    this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? 'Car',
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      licensePlate: json['license_plate'] as String? ?? '',
      color: json['color'] as String?,
      capacity: (json['capacity'] as num?)?.toInt() ?? 3,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'vehicle_type': vehicleType,
      'make': make,
      'model': model,
      'license_plate': licensePlate.toUpperCase().trim(),
      if (color != null) 'color': color,
      'capacity': capacity,
    };
  }

  String get displayName => '$make $model ($licensePlate)';
}
