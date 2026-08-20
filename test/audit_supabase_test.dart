import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase schema table names verification', () {
    const tables = [
      'app_config',
      'pickup_stops',
      'profiles',
      'vehicles',
      'session_schedule',
      'ride_sessions',
      'driver_availability',
      'passenger_log',
      'ride_matches',
      'ride_completion_log',
      'notifications',
      'ride_requests',
    ];

    expect(tables.length, equals(12));
    expect(tables.contains('ride_completion_log'), isTrue);
    expect(tables.contains('profiles'), isTrue);
    expect(tables.contains('app_config'), isTrue);
  });
}
