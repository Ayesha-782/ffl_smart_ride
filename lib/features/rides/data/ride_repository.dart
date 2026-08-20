import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/models/driver_availability.dart';
import '../../../core/models/passenger_log.dart';
import '../../../core/models/priority_passenger.dart';
import '../../../core/models/ride_match.dart';
import '../../../core/models/ride_request.dart';
import '../../../core/models/ride_session.dart';
import '../../../core/models/ride_slot.dart';
import '../../../core/models/session_schedule.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/supabase_service.dart';

final Random _idRandom = Random.secure();

/// Generates a RFC 4122 version 4 UUID.
///
/// Written out rather than pulling in the `uuid` package: this is the only
/// place the project needs one, and adding a dependency for it is not worth it.
String generateClientRequestId() {
  final bytes = List<int>.generate(16, (_) => _idRandom.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

enum UserSessionResponseType { none, driver, passenger, matched }

class UserSessionStatus {
  final UserSessionResponseType responseType;
  final DriverAvailability? driverAvailability;
  final PassengerLog? passengerLog;
  final RideMatch? rideMatch;

  const UserSessionStatus({
    required this.responseType,
    this.driverAvailability,
    this.passengerLog,
    this.rideMatch,
  });

  bool get hasResponded => responseType != UserSessionResponseType.none;
}

class RideRepository {
  SupabaseClient get _supabase => SupabaseService.instance.client;

  // ===========================================================================
  // 1. RIDE SESSIONS (Multiple-Times-Daily: Morning, Afternoon, Evening)
  // ===========================================================================

  String get currentSlotName {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    if (minutes < 12 * 60 + 30) {
      return 'morning';
    } else if (minutes < 16 * 60 + 30) {
      return 'afternoon';
    } else {
      return 'evening';
    }
  }

  Future<RideSession?> getLatestActiveSession() async {
    final dateStr =
        '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    final data = await _supabase
        .from('ride_sessions')
        .select()
        .eq('session_date', dateStr)
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return RideSession.fromJson(data);
  }

  Future<RideSession> getOpenSession({
    String? slot,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final dateStr =
        '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    final targetSlot = slot ?? currentSlotName;

    final existing = await _supabase
        .from('ride_sessions')
        .select()
        .eq('session_date', dateStr)
        .eq('slot', targetSlot)
        .maybeSingle();

    if (existing != null) {
      return RideSession.fromJson(existing);
    }

    final created = await _supabase
        .from('ride_sessions')
        .insert({
          'session_date': dateStr,
          'slot': targetSlot,
          'status': 'open',
        })
        .select()
        .single();

    return RideSession.fromJson(created);
  }

  Future<List<SessionSchedule>> getSessionSchedules() async {
    final response = await _supabase
        .from('session_schedule')
        .select()
        .eq('is_active', true)
        .order('opens_at', ascending: true);

    final list = response as List<dynamic>;
    return list.map((json) => SessionSchedule.fromJson(json as Map<String, dynamic>)).toList();
  }

  Stream<List<RideSession>> streamOpenSessions() {
    return _supabase
        .from('ride_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'open')
        .order('session_date', ascending: false)
        .map((list) => list.map((json) => RideSession.fromJson(json)).toList());
  }

  // ===========================================================================
  // 2. USER SESSION RESPONSE STATUS
  // ===========================================================================

  Future<UserSessionStatus> getUserSessionResponse(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const UserSessionStatus(responseType: UserSessionResponseType.none);
    }

    // 1. Check if user is registered as Driver first
    final driver = await _supabase
        .from('driver_availability')
        .select()
        .eq('session_id', sessionId)
        .eq('driver_id', user.id)
        .eq('status', 'active')
        .maybeSingle();

    if (driver != null) {
      return UserSessionStatus(
        responseType: UserSessionResponseType.driver,
        driverAvailability: DriverAvailability.fromJson(driver),
      );
    }

    // 2. Check if user is matched as Passenger in this session
    final match = await _supabase
        .from('ride_matches')
        .select('''
          *,
          driver:profiles!ride_matches_driver_id_fkey (
            id,
            employee_id,
            full_name,
            phone,
            vehicle_number
          ),
          passenger:profiles!ride_matches_passenger_id_fkey (
            id,
            employee_id,
            full_name,
            phone,
            home_address,
            pickup_stop_id,
            pickup_stop_order
          )
        ''')
        .eq('session_id', sessionId)
        .eq('status', 'active')
        .eq('passenger_id', user.id)
        .maybeSingle();

    if (match != null) {
      return UserSessionStatus(
        responseType: UserSessionResponseType.matched,
        rideMatch: RideMatch.fromJson(match),
      );
    }

    // 3. Check if user registered as Passenger (waiting queue)
    final passenger = await _supabase
        .from('passenger_log')
        .select()
        .eq('session_id', sessionId)
        .eq('passenger_id', user.id)
        .eq('status', 'waiting')
        .maybeSingle();

    if (passenger != null) {
      return UserSessionStatus(
        responseType: UserSessionResponseType.passenger,
        passengerLog: PassengerLog.fromJson(passenger),
      );
    }

    return const UserSessionStatus(responseType: UserSessionResponseType.none);
  }

  // ===========================================================================
  // 3. NEAREST-PASSENGER PRIORITY QUEUE & ATOMIC ASSIGNMENT
  // ===========================================================================

  Future<List<PriorityPassenger>> getPriorityQueue({
    required String sessionId,
    required String driverId,
  }) async {
    final response = await _supabase.rpc(
      'get_priority_queue',
      params: {
        'p_session_id': sessionId,
        'p_driver_id': driverId,
      },
    );

    final list = response as List<dynamic>;
    return list
        .map((json) => PriorityPassenger.fromJson(json as Map<String, dynamic>))
        .where((p) => p.status.toLowerCase() == 'waiting' && p.passengerId != driverId)
        .toList();
  }

  Future<void> assignPassengers({
    required String sessionId,
    required String driverId,
    required List<String> passengerIds,
  }) async {
    if (passengerIds.isEmpty) {
      throw Exception('Please select at least one passenger to offer a lift.');
    }

    await _supabase.rpc(
      'assign_passengers',
      params: {
        'p_session_id': sessionId,
        'p_driver_id': driverId,
        'p_passenger_ids': passengerIds,
      },
    );
  }

  Stream<List<Map<String, dynamic>>> streamPassengerLogChanges(String sessionId) {
    return _supabase
        .from('passenger_log')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId);
  }

  Stream<List<Map<String, dynamic>>> streamSessionMatches(String sessionId) {
    return _supabase
        .from('ride_matches')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId);
  }

  // ===========================================================================
  // 4. DRIVER AVAILABILITY & MY RIDE
  // ===========================================================================

  Future<DriverAvailability> setDriverAvailability({
    required String sessionId,
    required int seatsOffered,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    if (seatsOffered <= 0) {
      throw Exception('Seats offered must be greater than 0');
    }

    final data = await _supabase
        .from('driver_availability')
        .upsert(
          {
            'session_id': sessionId,
            'driver_id': user.id,
            'seats_offered': seatsOffered,
            'seats_remaining': seatsOffered,
            'status': 'active',
          },
          onConflict: 'session_id, driver_id',
        )
        .select('''
          *,
          profiles!driver_availability_driver_id_fkey (
            id,
            employee_id,
            full_name,
            phone,
            vehicle_number,
            pickup_stop_order
          )
        ''')
        .single();

    return DriverAvailability.fromJson(data);
  }

  Future<DriverAvailability?> getMyDriverAvailability(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('driver_availability')
        .select()
        .eq('session_id', sessionId)
        .eq('driver_id', user.id)
        .eq('status', 'active')
        .maybeSingle();

    if (data == null) return null;
    return DriverAvailability.fromJson(data);
  }

  /// Fetches all active passengers matched with the driver for this session
  Future<List<RideMatch>> getMyDriverMatches(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('ride_matches')
        .select('''
          *,
          passenger:profiles!ride_matches_passenger_id_fkey (
            id,
            employee_id,
            full_name,
            phone,
            home_address,
            pickup_stop_id,
            pickup_stop_order
          )
        ''')
        .eq('session_id', sessionId)
        .eq('driver_id', user.id)
        .inFilter('status', ['active', 'confirmed', 'pending_confirmation'])
        .order('matched_at', ascending: true);

    final list = response as List<dynamic>;
    return list.map((json) => RideMatch.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Marks all confirmed matches for the driver in this session as completed,
  /// permanently calculating and recording CO2 savings into ride_completion_log
  Future<Map<String, dynamic>> completeDriverSessionRide(String sessionId) async {
    final response = await _supabase.rpc(
      'complete_driver_session_ride',
      params: {'p_session_id': sessionId},
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {'success': true};
  }

  /// Passenger confirms a shift session match
  Future<void> confirmPassengerMatch(String matchId) async {
    await _supabase.rpc(
      'confirm_passenger_match',
      params: {'p_match_id': matchId},
    );
  }

  /// Passenger declines a shift session match
  Future<void> rejectPassengerMatch(String matchId) async {
    await _supabase.rpc(
      'reject_passenger_match',
      params: {'p_match_id': matchId},
    );
  }

  // ===========================================================================
  // 5. CANCELLATION & DRIVER-TO-PASSENGER SWITCHING
  // ===========================================================================

  /// Cancels a specific match: resets passenger to waiting queue and increments driver seats_remaining
  Future<void> cancelMatch(String matchId) async {
    await _supabase.rpc(
      'cancel_match',
      params: {'p_match_id': matchId},
    );
  }

  /// Cancels entire driver availability and re-queues all matched passengers
  Future<void> cancelDriverAvailabilityById(String driverAvailabilityId) async {
    await _supabase.rpc(
      'cancel_driver_availability',
      params: {'p_driver_availability_id': driverAvailabilityId},
    );
  }

  /// Cancels driver offering and switches user into passenger waiting log
  Future<String> switchDriverToPassenger({
    required String sessionId,
    required String userId,
  }) async {
    final response = await _supabase.rpc(
      'switch_driver_to_passenger',
      params: {
        'p_session_id': sessionId,
        'p_user_id': userId,
      },
    );
    return response.toString();
  }

  /// Self-cancel by an unmatched passenger
  Future<void> cancelPassengerRequest(String passengerLogId) async {
    await _supabase.rpc(
      'cancel_passenger_request',
      params: {'p_passenger_log_id': passengerLogId},
    );
  }

  // ===========================================================================
  // 6. PASSENGER LOG (WAITING QUEUE)
  // ===========================================================================

  Future<PassengerLog> joinPassengerLog({
    required String sessionId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    final data = await _supabase
        .from('passenger_log')
        .upsert(
          {
            'session_id': sessionId,
            'passenger_id': user.id,
            'status': 'waiting',
            'requested_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'session_id, passenger_id',
        )
        .select('''
          *,
          profiles!passenger_log_passenger_id_fkey (
            id,
            employee_id,
            full_name,
            phone,
            home_address,
            pickup_stop_id,
            pickup_stop_order
          )
        ''')
        .single();

    return PassengerLog.fromJson(data);
  }

  Future<PassengerLog?> getMyPassengerLog(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('passenger_log')
        .select()
        .eq('session_id', sessionId)
        .eq('passenger_id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return PassengerLog.fromJson(data);
  }

  /// Auto-expires any pending ride requests whose departure time or slot window has passed without being accepted
  Future<void> autoExpirePastRequests() async {
    try {
      final nowUtc = DateTime.now().toUtc();
      await _supabase
          .from('ride_requests')
          .update({
            'status': 'expired',
            'updated_at': nowUtc.toIso8601String(),
          })
          .eq('status', 'pending')
          .lt('leaving_time', nowUtc.toIso8601String());
    } catch (_) {}
  }

  /// Whether [error] is a unique violation on the idempotency key specifically.
  ///
  /// Matched on the index name as well as the SQLSTATE, so that a unique
  /// violation on some *other* constraint is not mistaken for a duplicate
  /// submission and quietly swallowed.
  bool _isDuplicateClientRequestId(Object error) {
    if (error is PostgrestException) {
      if (error.code != '23505') return false;
      final detail = '${error.message} ${error.details ?? ''}'.toLowerCase();
      return detail.contains('client_request_id');
    }
    return false;
  }

  /// Creates an ad-hoc ride request.
  ///
  /// [clientRequestId] is an idempotency key. A retry carrying the same key
  /// collides with `uq_ride_requests_client_request_id` and the existing row is
  /// returned instead of a second request being created.
  ///
  /// **Pass a stable key to actually get idempotency.** When omitted, a fresh
  /// key is generated per call, which protects against a retry *inside* this
  /// method but not against the caller invoking it twice — a double-tapped
  /// button sends two different keys and still creates two requests. Callers
  /// that want that covered should generate one key with
  /// [generateClientRequestId] when the compose screen opens and pass the same
  /// value on every attempt.
  Future<RideRequest> createRideRequest({
    required String pickupLocation,
    required String officeLocation,
    required DateTime leavingTime,
    int? pickupStopOrder,
    String? additionalNote,
    double? pickupLatitude,
    double? pickupLongitude,
    double? officeLatitude,
    double? officeLongitude,
    String? clientRequestId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    if (!RideSlot.isDateTimeInAnySlot(leavingTime)) {
      throw Exception(
        'Ride requests can only be scheduled within official operating slots:\n${RideSlot.formattedSlotsSummary}',
      );
    }

    final requestKey = clientRequestId ?? generateClientRequestId();

    final payload = <String, dynamic>{
      'passenger_id': user.id,
      'pickup_location': pickupLocation.trim(),
      'office_location': officeLocation.trim(),
      if (pickupStopOrder != null) 'pickup_stop_order': pickupStopOrder,
      'leaving_time': leavingTime.toIso8601String(),
      if (additionalNote != null && additionalNote.isNotEmpty)
        'additional_note': additionalNote.trim(),
      'status': 'pending',
      if (pickupLatitude != null) 'pickup_latitude': pickupLatitude,
      if (pickupLongitude != null) 'pickup_longitude': pickupLongitude,
      if (officeLatitude != null) 'office_latitude': officeLatitude,
      if (officeLongitude != null) 'office_longitude': officeLongitude,
      'client_request_id': requestKey,
    };

    try {
      final data = await _supabase
          .from('ride_requests')
          .insert(payload)
          .select()
          .single();

      return RideRequest.fromJson(data);
    } catch (e) {
      final errStr = e.toString().toLowerCase();

      // The key already landed: this is a retry of a request that in fact
      // succeeded, so return what was created rather than creating a second one.
      if (_isDuplicateClientRequestId(e)) {
        final existing = await _supabase
            .from('ride_requests')
            .select()
            .eq('client_request_id', requestKey)
            .maybeSingle();

        if (existing != null) {
          return RideRequest.fromJson(existing);
        }
        rethrow;
      }
      // If pickup_stop_order or coordinate columns don't exist yet on remote schema, fallback to base columns
      if (errStr.contains('pickup_stop_order') ||
          errStr.contains('schema cache') ||
          errStr.contains('column')) {
        final fallbackPayload = <String, dynamic>{
          'passenger_id': user.id,
          'pickup_location': pickupLocation.trim(),
          'office_location': officeLocation.trim(),
          'leaving_time': leavingTime.toIso8601String(),
          if (additionalNote != null && additionalNote.isNotEmpty)
            'additional_note': additionalNote.trim(),
          'status': 'pending',
        };

        final fallbackData = await _supabase
            .from('ride_requests')
            .insert(fallbackPayload)
            .select()
            .single();

        return RideRequest.fromJson(fallbackData);
      }
      rethrow;
    }
  }

  Future<List<RideRequest>> _populateMissingProfiles(List<RideRequest> requests) async {
    final missingPassengerIds = requests
        .where((r) => r.passenger == null && r.passengerId.isNotEmpty)
        .map((r) => r.passengerId)
        .toSet()
        .toList();

    final missingDriverIds = requests
        .where((r) => r.driver == null && r.driverId != null && r.driverId!.isNotEmpty)
        .map((r) => r.driverId!)
        .toSet()
        .toList();

    final allUserIds = {...missingPassengerIds, ...missingDriverIds}.toList();
    if (allUserIds.isEmpty) return requests;

    final profileMap = <String, UserProfile>{};
    try {
      final profilesData = await _supabase
          .from('profiles')
          .select('id, employee_id, full_name, phone, home_address, pickup_stop_id, pickup_stop_order, office_location, vehicle_number')
          .inFilter('id', allUserIds) as List<dynamic>;

      for (final json in profilesData) {
        final prof = UserProfile.fromJson(json as Map<String, dynamic>);
        profileMap[prof.id] = prof;
      }
    } catch (_) {
      try {
        final fallbackData = await _supabase
            .from('profiles')
            .select('*')
            .inFilter('id', allUserIds) as List<dynamic>;

        for (final json in fallbackData) {
          final prof = UserProfile.fromJson(json as Map<String, dynamic>);
          profileMap[prof.id] = prof;
        }
      } catch (e) {
        debugPrint('_populateMissingProfiles fallback error: $e');
      }
    }

    return requests.map((r) {
      UserProfile? pass = r.passenger;
      UserProfile? driv = r.driver;

      if (pass == null && profileMap.containsKey(r.passengerId)) {
        pass = profileMap[r.passengerId];
      }
      if (driv == null && r.driverId != null && profileMap.containsKey(r.driverId)) {
        driv = profileMap[r.driverId];
      }

      if (pass != r.passenger || driv != r.driver) {
        return r.copyWith(passenger: pass, driver: driv);
      }
      return r;
    }).toList();
  }

  Future<List<RideRequest>> getAvailableRequests({bool excludeCurrentUser = false}) async {
    final user = _supabase.auth.currentUser;

    // 1. Sweep and return any expired 5-minute offers back to open requests
    await autoReleaseExpiredOffers();

    // 2. Sweep and expire any unaddressed past-slot requests
    await autoExpirePastRequests();

    List<RideRequest> resultList = [];

    try {
      var query = _supabase
          .from('ride_requests')
          .select('''
            *,
            passenger:profiles!ride_requests_passenger_id_fkey (
              id,
              employee_id,
              full_name,
              phone,
              home_address,
              pickup_stop_id,
              pickup_stop_order,
              office_location,
              vehicle_number
            )
          ''')
          .eq('status', 'pending')
          .isFilter('driver_id', null);

      if (excludeCurrentUser && user != null) {
        query = query.neq('passenger_id', user.id);
      }

      final response = await query.order('leaving_time', ascending: true);
      final list = response as List<dynamic>;

      resultList = list
          .map((json) => RideRequest.fromJson(json as Map<String, dynamic>))
          .where((req) => req.status == 'pending' && req.driverId == null && !req.isSlotExpired)
          .toList();
    } catch (_) {
      var fallbackQuery = _supabase
          .from('ride_requests')
          .select()
          .eq('status', 'pending')
          .isFilter('driver_id', null);

      if (excludeCurrentUser && user != null) {
        fallbackQuery = fallbackQuery.neq('passenger_id', user.id);
      }

      final response = await fallbackQuery.order('leaving_time', ascending: true);
      final list = response as List<dynamic>;

      resultList = list
          .map((json) => RideRequest.fromJson(json as Map<String, dynamic>))
          .where((req) => req.status == 'pending' && req.driverId == null && !req.isSlotExpired)
          .toList();
    }

    return _populateMissingProfiles(resultList);
  }

  /// Fetches all ad-hoc requests created by the current logged-in employee
  Future<List<RideRequest>> getMyRideRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // Sweep and expire any unaddressed past-slot requests
    await autoExpirePastRequests();

    List<RideRequest> resultList = [];

    try {
      final response = await _supabase
          .from('ride_requests')
          .select('''
            *,
            driver:profiles!ride_requests_driver_id_fkey (
              id,
              employee_id,
              full_name,
              phone,
              vehicle_number
            ),
            passenger:profiles!ride_requests_passenger_id_fkey (
              id,
              employee_id,
              full_name,
              phone,
              home_address,
              office_location,
              vehicle_number
            )
          ''')
          .eq('passenger_id', user.id)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      resultList = list.map((json) => RideRequest.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      final fallbackResponse = await _supabase
          .from('ride_requests')
          .select()
          .eq('passenger_id', user.id)
          .order('created_at', ascending: false);

      final list = fallbackResponse as List<dynamic>;
      resultList = list.map((json) => RideRequest.fromJson(json as Map<String, dynamic>)).toList();
    }

    return _populateMissingProfiles(resultList);
  }

  /// Fetches all rides where the current user is the accepting driver
  Future<List<RideRequest>> getMyDrivenRides() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    List<RideRequest> resultList = [];

    try {
      final response = await _supabase
          .from('ride_requests')
          .select('''
            *,
            passenger:profiles!ride_requests_passenger_id_fkey (
              id,
              employee_id,
              full_name,
              phone,
              home_address,
              pickup_stop_id,
              pickup_stop_order,
              office_location
            )
          ''')
          .eq('driver_id', user.id)
          .inFilter('status', ['accepted', 'pending_confirmation', 'confirmed'])
          .order('leaving_time', ascending: true);

      final list = response as List<dynamic>;
      resultList = list.map((json) => RideRequest.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      final fallbackResponse = await _supabase
          .from('ride_requests')
          .select()
          .eq('driver_id', user.id)
          .inFilter('status', ['accepted', 'pending_confirmation', 'confirmed'])
          .order('leaving_time', ascending: true);

      final list = fallbackResponse as List<dynamic>;
      resultList = list.map((json) => RideRequest.fromJson(json as Map<String, dynamic>)).toList();
    }

    return _populateMissingProfiles(resultList);
  }

  /// Cancels an ad-hoc ride request (Passenger cancels)
  Future<void> cancelRideRequest(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    await _supabase
        .from('ride_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId)
        .eq('passenger_id', user.id);
  }

  /// Accepts a ride request with a 5-minute confirmation deadline.
  ///
  /// Delegates entirely to the `accept_ride_request` RPC, which locks the row
  /// with `SELECT ... FOR UPDATE` so that two drivers accepting the same
  /// request are serialised, and raises if the request is no longer pending.
  ///
  /// There is deliberately no client-side fallback. A read-then-write from the
  /// client cannot be made race-free, and the previous implementation never
  /// checked whether its own UPDATE matched a row — so the losing driver of a
  /// race saw a silent success. If the RPC fails, the error surfaces to the
  /// caller rather than degrading to an unsafe path.
  ///
  /// The RPC inserts the passenger notification itself; doing it here as well
  /// would deliver two notifications per accept.
  Future<void> acceptRide({
    required String rideId,
    required String passengerId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('You must be logged in to accept rides.');
    if (user.id == passengerId) throw Exception('You cannot accept your own ride request.');

    await _supabase.rpc(
      'accept_ride_request',
      params: {'p_ride_id': rideId},
    );
  }

  /// Passenger confirms the driver's ride offer.
  ///
  /// Delegates entirely to the `confirm_ride_request` RPC, which locks the row,
  /// verifies the caller owns it and that it is in `accepted` status, enforces
  /// the 5-minute deadline (reverting the request to the open queue when it has
  /// lapsed) and notifies the driver.
  ///
  /// The previous client-side pre-checks re-implemented the deadline logic
  /// against the client clock, and the `catch (_)` fallback wrote `confirmed`
  /// directly — bypassing the deadline entirely whenever the RPC errored. Both
  /// are deliberately gone.
  ///
  /// [driverId] is retained for source compatibility with existing callers; the
  /// RPC resolves the driver from the row itself.
  Future<void> confirmRide({
    required String rideId,
    String? driverId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to confirm rides.');
    }

    await _supabase.rpc(
      'confirm_ride_request',
      params: {'p_ride_id': rideId},
    );
  }

  /// Driver marks the ride as completed.
  ///
  /// Delegates entirely to the `complete_ride_request` RPC. The "must be
  /// confirmed" guard previously lived only here in Dart, which meant anyone
  /// calling the API directly could complete an unconfirmed ride; it has been
  /// moved into the RPC (see `database/supabase_schema.sql`) so the rule holds
  /// regardless of how the write arrives.
  ///
  /// [passengerId] is retained for source compatibility with existing callers;
  /// the RPC resolves the passenger from the row and notifies them itself.
  Future<void> completeRide({
    required String rideId,
    String? passengerId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User is not authenticated');

    await _supabase.rpc(
      'complete_ride_request',
      params: {'p_ride_id': rideId},
    );
  }

  /// Driver cancels their ride offer, returning the request back to the open queue.
  ///
  /// Delegates entirely to the `cancel_ride_offer` RPC, which verifies the
  /// caller is the assigned driver, clears the offer and notifies the passenger.
  /// The previous `catch (_)` fallback wrote the same transition from the client
  /// and is deliberately gone.
  ///
  /// [passengerId] is retained for source compatibility with existing callers;
  /// the RPC resolves the passenger from the row and notifies them itself.
  Future<void> cancelRideOffer({
    required String rideId,
    required String passengerId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to cancel a ride offer.');
    }

    await _supabase.rpc(
      'cancel_ride_offer',
      params: {'p_ride_id': rideId},
    );
  }

  /// Passenger declines/rejects a driver's ride offer, returning the request back to the open queue
  Future<void> rejectRideOffer({
    required String rideId,
    required String passengerId,
    String? driverId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('ride_requests')
        .update({
          'driver_id': null,
          'status': 'pending',
          'confirmation_deadline': null,
        })
        .eq('id', rideId)
        .eq('passenger_id', user.id);

    if (driverId != null) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final passengerName = profile?['full_name'] ?? 'The passenger';

        await _supabase.from('notifications').insert({
          'user_id': driverId,
          'ride_id': rideId,
          'title': 'Ride Offer Declined',
          'message': '$passengerName was unable to accept your lift offer. The request is back in the open queue.',
          'type': 'ride_cancelled',
          'is_read': false,
        });
      } catch (_) {}
    }
  }

  /// Permanently deletes a cancelled or completed ride request (Passenger only)
  Future<void> deleteRideRequest(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }

    try {
      await _supabase
          .from('ride_requests')
          .delete()
          .eq('id', requestId)
          .eq('passenger_id', user.id);
    } catch (e) {
      debugPrint('deleteRideRequest error: $e');
      rethrow;
    }
  }

  /// Automatically expires unconfirmed matches and ride requests after 5 minutes
  Future<void> expireUnconfirmedMatches() async {
    try {
      await _supabase.rpc('expire_unconfirmed_matches');
    } catch (_) {
      // Fallback local release if RPC not present
      await autoReleaseExpiredOffers();
    }
  }

  /// Automatically resets accepted ride offers if unconfirmed after 5 minutes
  Future<void> autoReleaseExpiredOffers() async {
    try {
      final nowUtc = DateTime.now().toUtc();

      List<dynamic> accepted;
      try {
        accepted = await _supabase
            .from('ride_requests')
            .select('id, passenger_id, driver_id, confirmation_deadline, updated_at, created_at')
            .eq('status', 'accepted') as List<dynamic>;
      } catch (_) {
        return;
      }

      for (final item in accepted) {
        final deadlineStr = item['confirmation_deadline'] as String?;
        final deadline = deadlineStr != null ? DateTime.tryParse(deadlineStr)?.toUtc() : null;
        final effectiveTime = (DateTime.tryParse(item['updated_at']?.toString() ?? '') ??
                               DateTime.tryParse(item['created_at']?.toString() ?? ''))?.toUtc();

        final isExpired = deadline != null
            ? nowUtc.isAfter(deadline)
            : (effectiveTime != null && nowUtc.difference(effectiveTime).inSeconds >= 300);

        if (isExpired) {
          final rideId = item['id'] as String;
          final passengerId = item['passenger_id'] as String?;
          final driverId = item['driver_id'] as String?;

          await _supabase
              .from('ride_requests')
              .update({
                'driver_id': null,
                'status': 'pending',
                'confirmation_deadline': null,
                'updated_at': nowUtc.toIso8601String(),
              })
              .eq('id', rideId)
              .eq('status', 'accepted');

          if (passengerId != null) {
            await _supabase.from('notifications').insert({
              'user_id': passengerId,
              'ride_id': rideId,
              'title': 'Ride Offer Expired ⏳',
              'message': 'The 5-minute confirmation window expired. Your request is now back in the open requests queue.',
              'type': 'ride_expired',
              'is_read': false,
            });
          }

          if (driverId != null) {
            await _supabase.from('notifications').insert({
              'user_id': driverId,
              'ride_id': rideId,
              'title': 'Ride Offer Expired ⏳',
              'message': 'The passenger did not confirm within 5 minutes. The ride request has returned to the open queue.',
              'type': 'ride_expired',
              'is_read': false,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('autoReleaseExpiredOffers error: $e');
    }
  }

  // ===========================================================================
  // 6. NOTIFICATIONS
  // ===========================================================================

  /// Fetches all notifications for the current authenticated user
  Future<List<AppNotification>> getMyNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final list = response as List<dynamic>;
      return list.map((json) => AppNotification.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getMyNotifications error: $e');
      return [];
    }
  }

  /// Gets the count of unread notifications
  Future<int> getUnreadNotificationCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      final list = response as List<dynamic>;
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  /// Marks a specific notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', user.id);
    } catch (_) {}
  }

  /// Marks all notifications for the current user as read
  Future<void> markAllNotificationsAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (_) {}
  }

  /// Realtime stream of notifications for the current user
  Stream<List<Map<String, dynamic>>> streamMyNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id);
  }

  /// Realtime stream of ride_requests table
  Stream<List<Map<String, dynamic>>> streamRideRequests() {
    return _supabase.from('ride_requests').stream(primaryKey: ['id']);
  }
}
