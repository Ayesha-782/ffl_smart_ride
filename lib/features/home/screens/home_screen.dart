import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/ride_request.dart';
import '../../../core/models/ride_session.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/profile_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/models/reports_models.dart';
import '../../reports/screens/reports_screen.dart';
import '../../rides/data/ride_repository.dart';
import '../../rides/screens/available_requests_screen.dart';
import '../../rides/screens/create_request_screen.dart';
import '../../rides/screens/driver_priority_queue_screen.dart';
import '../../rides/widgets/active_session_card.dart';
import '../../rides/widgets/no_session_open_card.dart';
import '../../rides/widgets/notifications_sheet.dart';
import '../../rides/widgets/session_prompt_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = SupabaseService.instance.client;
  final _authRepository = AuthRepository();
  final _rideRepository = RideRepository();
  final _reportsRepository = ReportsRepository();

  UserProfile? _profile;
  RideSession? _activeSession;
  RideRequest? _activeRideOffer;
  MonthlyCo2Summary? _impactSummary;
  UserSessionStatus _sessionStatus = const UserSessionStatus(
    responseType: UserSessionResponseType.none,
  );

  StreamSubscription? _notifSubscription;
  StreamSubscription? _requestsSubscription;
  Timer? _pollTimer;
  Timer? _tickerTimer;
  int _unreadNotifCount = 0;

  bool _loading = true;
  bool _hasAutoPrompted = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _loadUnreadNotifications();
    _loadActiveRideOffer();
    _setupStreams();

    // Auto-poll every 3 seconds for instant multi-device reactivity
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadActiveRideOffer();
        _loadUnreadNotifications();
        _loadImpactSummary();
      }
    });

    // 1-second countdown ticker for the 5-minute decision timer
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _activeRideOffer != null) {
        if (_activeRideOffer!.remainingConfirmationSeconds <= 0 || _activeRideOffer!.isConfirmationExpired) {
          _handleExpiredOffer();
        } else {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickerTimer?.cancel();
    _requestsSubscription?.cancel();
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _setupStreams() {
    _notifSubscription = _rideRepository.streamMyNotifications().listen((_) {
      if (mounted) _loadUnreadNotifications();
    });

    _requestsSubscription = _rideRepository.streamRideRequests().listen((_) {
      if (mounted) _loadActiveRideOffer();
    });
  }

  Future<void> _loadUnreadNotifications() async {
    final count = await _rideRepository.getUnreadNotificationCount();
    if (mounted) {
      setState(() => _unreadNotifCount = count);
    }
  }

  Future<void> _loadActiveRideOffer() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final requests = await _rideRepository.getMyRideRequests();
      var offer = requests.where((r) => (r.status == 'accepted' || r.status == 'pending_confirmation') && r.driverId != null).firstOrNull;
      if (offer != null && offer.driver == null && offer.driverId != null) {
        final driverProf = await _authRepository.getProfile(offer.driverId!);
        if (driverProf != null) {
          offer = offer.copyWith(driver: driverProf);
        }
      }
      if (mounted) {
        setState(() => _activeRideOffer = offer);
      }
    } catch (_) {}
  }

  Future<void> _loadImpactSummary() async {
    try {
      final summary = await _reportsRepository.getMonthlyCo2Summary();
      if (mounted) {
        setState(() => _impactSummary = summary);
      }
    } catch (_) {}
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProfile(),
      _loadActiveSession(),
      _loadUnreadNotifications(),
      _loadActiveRideOffer(),
      _loadImpactSummary(),
    ]);
  }

  String _getEmployeeFullName() {
    if (_profile != null && _profile!.fullName.trim().isNotEmpty && _profile!.fullName.trim() != 'Colleague') {
      return _profile!.fullName.trim();
    }
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final metaName = user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString();
      if (metaName != null && metaName.trim().isNotEmpty) {
        return metaName.trim();
      }
      final emailPrefix = user.email?.split('@').first;
      if (emailPrefix != null && emailPrefix.isNotEmpty) {
        return emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
      }
    }
    return 'Employee';
  }

  String _getEmployeeFirstName() {
    final full = _getEmployeeFullName();
    return full.split(' ').first;
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      Map<String, dynamic>? data;
      try {
        data = await _supabase
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
            .eq('id', user.id)
            .maybeSingle();
      } catch (_) {
        data = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
      }

      if (!mounted) return;

      final metaFullName = user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          '';

      if (data != null) {
        final profile = UserProfile.fromJson(data);
        final resolvedName = (profile.fullName.trim().isNotEmpty && profile.fullName != 'Colleague')
            ? profile.fullName
            : (metaFullName.isNotEmpty ? metaFullName : profile.fullName);

        setState(() {
          _profile = profile.copyWith(
            fullName: resolvedName.isNotEmpty ? resolvedName : _getEmployeeFullName(),
          );
          _loading = false;
        });
      } else {
        final metaEmpId = user.userMetadata?['employee_id']?.toString() ?? '';
        final metaPhone = user.userMetadata?['phone']?.toString();
        final metaVehicle = user.userMetadata?['license_plate']?.toString();
        final metaHasVehicle = (user.userMetadata?['has_vehicle'] as bool?) ?? false;

        setState(() {
          _profile = UserProfile(
            id: user.id,
            employeeId: metaEmpId,
            fullName: metaFullName.isNotEmpty ? metaFullName : _getEmployeeFullName(),
            email: user.email,
            phone: metaPhone,
            vehicleNumber: metaVehicle,
            hasVehicle: metaHasVehicle,
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      debugPrint('Profile loading error: $e');
    }
  }

  Future<void> _loadActiveSession() async {
    try {
      final session = await _rideRepository.getLatestActiveSession();
      if (!mounted) return;

      if (session != null) {
        final status = await _rideRepository.getUserSessionResponse(session.id);
        if (!mounted) return;

        setState(() {
          _activeSession = session;
          _sessionStatus = status;
        });

        // Auto-show prompt dialog once if user hasn't responded yet
        if (!status.hasResponded && !_hasAutoPrompted) {
          _hasAutoPrompted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeSession != null) {
              SessionPromptDialog.show(
                context: context,
                session: _activeSession!,
                userProfile: _profile,
                onResponded: _loadActiveSession,
              );
            }
          });
        }
      } else {
        setState(() {
          _activeSession = null;
          _sessionStatus = const UserSessionStatus(
            responseType: UserSessionResponseType.none,
          );
        });
      }
    } catch (e) {
      debugPrint('Session loading error: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authRepository.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.authGate,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleExpiredOffer() async {
    try {
      await _rideRepository.autoReleaseExpiredOffers();
      await _loadAllData();
    } catch (_) {}
  }

  Future<void> _confirmRideFromHome(RideRequest offer) async {
    if (offer.remainingConfirmationSeconds <= 0 || offer.isConfirmationExpired) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The 5-minute confirmation window has expired. Your request has returned to open requests.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      await _handleExpiredOffer();
      return;
    }

    try {
      await _rideRepository.confirmRide(
        rideId: offer.id,
        driverId: offer.driverId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride Confirmed! ✅ Your driver has been notified.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
      await _loadAllData();
    }
  }

  Future<void> _rejectRideFromHome(RideRequest offer) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _rideRepository.rejectRideOffer(
        rideId: offer.id,
        passengerId: user.id,
        driverId: offer.driverId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lift offer declined. Your request is back in the open queue.'),
          backgroundColor: AppColors.info,
        ),
      );
      await _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildActiveRideOfferBanner(RideRequest offer) {
    final remainSec = offer.remainingConfirmationSeconds;
    final isExpired = remainSec <= 0 || offer.isConfirmationExpired;
    final remainM = (remainSec ~/ 60).toString().padLeft(2, '0');
    final remainS = (remainSec % 60).toString().padLeft(2, '0');

    final rawDriverName = offer.driver?.fullName.trim();
    final driverName = (rawDriverName != null && rawDriverName.isNotEmpty && rawDriverName.toLowerCase() != 'colleague')
        ? rawDriverName
        : (offer.driver?.employeeId.isNotEmpty == true ? 'Driver (${offer.driver!.employeeId})' : 'A driver');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? AppColors.error : AppColors.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? AppColors.error : AppColors.primary).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isExpired ? const Color(0xFFFEE2E2) : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_car_filled,
                  color: isExpired ? AppColors.error : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExpired ? 'Ride Offer Expired ⏳' : 'Ride Offer Received! 🚗',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isExpired
                          ? '5-minute decision window has passed'
                          : '$driverName offered you a lift to work',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFFEE2E2)
                      : (remainSec > 60 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpired
                        ? AppColors.error
                        : (remainSec > 60 ? const Color(0xFFF59E0B) : AppColors.error),
                  ),
                ),
                child: Text(
                  isExpired ? '⏳ Expired (00:00)' : '⏳ $remainM:$remainS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isExpired
                        ? AppColors.error
                        : (remainSec > 60 ? const Color(0xFF92400E) : AppColors.error),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Embedded Driver Details
          if (offer.driverId != null)
            ProfileCard(
              profileId: offer.driverId!,
              isDriver: true,
              compact: true,
            ),

          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pickup: ${offer.pickupLocation}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Leaving: ${offer.leavingTime.day}/${offer.leavingTime.month} at ${offer.leavingTime.hour > 12 ? offer.leavingTime.hour - 12 : (offer.leavingTime.hour == 0 ? 12 : offer.leavingTime.hour)}:${offer.leavingTime.minute.toString().padLeft(2, '0')} ${offer.leavingTime.hour >= 12 ? 'PM' : 'AM'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          if (isExpired) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This ride offer timed out and is no longer acceptable. Your request has returned to open requests for other colleagues to offer.',
                      style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Two Big Buttons: Accept / Reject
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectRideFromHome(offer),
                  icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                  label: Text(
                    isExpired ? 'Dismiss' : 'Reject',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExpired ? null : () => _confirmRideFromHome(offer),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Accept Ride', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateRequest() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateRequestScreen(),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your ride request has been posted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAllData();
    }
  }

  Future<void> _openPriorityQueue() async {
    if (_activeSession != null && _sessionStatus.driverAvailability != null) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DriverPriorityQueueScreen(
            session: _activeSession!,
            driverAvailability: _sessionStatus.driverAvailability!,
          ),
        ),
      );
      if (result == true) {
        _loadAllData();
      }
    } else {
      _openAvailableRequests();
    }
  }

  Future<void> _openAvailableRequests({int tabIndex = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AvailableRequestsScreen(initialTabIndex: tabIndex),
      ),
    );
    _loadAllData();
  }

  Future<void> _openMyDrivenRides() async {
    await _openAvailableRequests(tabIndex: 1);
  }

  Future<void> _openMyRideRequests() async {
    await _openAvailableRequests(tabIndex: 2);
  }

  Future<void> _openReportsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ReportsScreen(),
      ),
    );
    if (mounted) {
      _loadImpactSummary();
    }
  }

  Widget _buildDrawer() {
    final name = _getEmployeeFullName();
    final empId = _profile?.employeeId ?? '';
    final vehicleInfo = _profile?.vehicle?.displayName ??
        (_profile?.vehicleNumber != null && _profile!.vehicleNumber!.isNotEmpty
            ? _profile!.vehicleNumber!
            : 'No vehicle registered');

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (empId.isNotEmpty)
                    Text(
                      'ID: $empId',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.directions_car, size: 14, color: AppColors.primaryDark),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vehicleInfo,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.home_outlined, color: AppColors.primary),
              title: const Text('Home Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('I Need a Ride (Post Request)'),
              onTap: () {
                Navigator.pop(context);
                _openCreateRequest();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text("Open Requests (Available Rides)"),
              onTap: () {
                Navigator.pop(context);
                _openPriorityQueue();
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined, color: AppColors.primary),
              title: const Text("Rides I'm Giving (Selected Passengers)"),
              onTap: () {
                Navigator.pop(context);
                _openMyDrivenRides();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text("My Ride Requests (As Passenger)"),
              onTap: () {
                Navigator.pop(context);
                _openMyRideRequests();
              },
            ),
            ListTile(
              leading: const Icon(Icons.eco_outlined, color: AppColors.success),
              title: const Text('Environmental Reports & Stats'),
              onTap: () {
                Navigator.pop(context);
                _openReportsScreen();
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getEmployeeFirstName();
    final totalRides = _impactSummary?.totalMatchesCompleted ?? 0;
    final totalKg = _impactSummary?.totalKgSaved ?? 0.0;
    final fuelSavedLiters = totalKg > 0 ? (totalKg / 2.31) : (totalRides * 0.25);
    final fuelDisplay = fuelSavedLiters > 0
        ? (fuelSavedLiters < 10
            ? '${fuelSavedLiters.toStringAsFixed(1)} L'
            : '${fuelSavedLiters.toStringAsFixed(0)} L')
        : '0 L';
    final co2Display = totalKg > 0
        ? (totalKg >= 1000
            ? '${(totalKg / 1000).toStringAsFixed(2)} t'
            : (totalKg < 10 ? '${totalKg.toStringAsFixed(1)} kg' : '${totalKg.toStringAsFixed(0)} kg'))
        : '0 kg';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Rides I'm Giving / Selected Passengers",
            onPressed: _openMyDrivenRides,
            icon: const Icon(Icons.groups_outlined, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () async {
              await NotificationsSheet.show(
                context,
                onNavigateToRides: _openMyRideRequests,
              );
              _loadUnreadNotifications();
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadNotifCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_unreadNotifCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'logout') _logout();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good day 👋',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _loading ? 'Loading profile...' : 'Welcome, $displayName',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Connect with colleagues for smart, eco-friendly carpooling.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // =============================================================
                // ACTIVE RIDE OFFER ACCEPT / REJECT BANNER (FOR PASSENGERS)
                // =============================================================
                if (_activeRideOffer != null)
                  _buildActiveRideOfferBanner(_activeRideOffer!),

                // =============================================================
                // ACTIVE SESSION CARD (OR EMPTY SCHEDULE CARD)
                // =============================================================
                if (_activeSession != null)
                  ActiveSessionCard(
                    session: _activeSession!,
                    sessionStatus: _sessionStatus,
                    userProfile: _profile,
                    onRefresh: _loadActiveSession,
                    onViewQueue: _openPriorityQueue,
                  )
                else if (!_loading)
                  NoSessionOpenCard(
                    onRefresh: _loadActiveSession,
                  ),

                // Card 1: I Need a Ride
                _ActionCard(
                  icon: Icons.directions_car,
                  title: 'I Need a Ride',
                  subtitle: 'Select your township pickup stop and post a ride request.',
                  backgroundColor: AppColors.primaryLight,
                  onTap: _openCreateRequest,
                ),
                const SizedBox(height: 14),

                // Card 2: I'm Driving
                _ActionCard(
                  icon: Icons.people_alt_outlined,
                  title: "I'm Driving Today",
                  subtitle: 'View pending requests along your route and offer seats.',
                  backgroundColor: AppColors.surface,
                  onTap: _openPriorityQueue,
                ),
                const SizedBox(height: 24),

                // Impact Card
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openReportsScreen,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                            color: Colors.black.withValues(alpha: 0.04),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Ride Share Impact',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'View Reports',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Every shared commute saves fuel and reduces emissions.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _ImpactItem(
                                  icon: Icons.directions_car,
                                  value: '$totalRides',
                                  label: 'Rides Shared',
                                ),
                              ),
                              Expanded(
                                child: _ImpactItem(
                                  icon: Icons.local_gas_station,
                                  value: fuelDisplay,
                                  label: 'Fuel Saved',
                                ),
                              ),
                              Expanded(
                                child: _ImpactItem(
                                  icon: Icons.eco,
                                  value: co2Display,
                                  label: 'CO₂ Saved',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImpactItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ImpactItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
