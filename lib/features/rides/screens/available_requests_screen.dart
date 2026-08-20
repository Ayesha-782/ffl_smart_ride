import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/ride_request.dart';
import '../../../core/widgets/profile_card.dart';
import '../data/ride_repository.dart';
import '../widgets/notifications_sheet.dart';
import 'create_request_screen.dart';

class AvailableRequestsScreen extends StatefulWidget {
  final int initialTabIndex;
  const AvailableRequestsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AvailableRequestsScreen> createState() => _AvailableRequestsScreenState();
}

class _AvailableRequestsScreenState extends State<AvailableRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _rideRepository = RideRepository();
  late TabController _tabController;
  StreamSubscription? _streamSubscription;
  StreamSubscription? _notifSubscription;
  Timer? _pollTimer;
  Timer? _tickerTimer;

  List<RideRequest> _openRequests = [];
  List<RideRequest> _drivenRides = [];
  List<RideRequest> _myRequests = [];
  final Set<String> _inFlightAcceptIds = {};
  int _unreadNotifCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _loadRequests();
    _loadUnreadNotifications();
    _setupRealtimeSubscription();

    // Auto-sync polling every 3 seconds for instant multi-device reactivity
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadRequests(silent: true);
        _loadUnreadNotifications();
      }
    });

    // 1-second UI ticker for live 5-minute countdown display and auto-expiry sweep
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final hasAcceptedMy = _myRequests.any((r) => r.status == 'accepted');
        final hasAcceptedDriven = _drivenRides.any((r) => r.status == 'accepted');
        if (hasAcceptedMy || hasAcceptedDriven) {
          final hasExpired = _myRequests.any((r) => r.status == 'accepted' && (r.remainingConfirmationSeconds <= 0 || r.isConfirmationExpired)) ||
                             _drivenRides.any((r) => r.status == 'accepted' && (r.remainingConfirmationSeconds <= 0 || r.isConfirmationExpired));
          if (hasExpired) {
            _loadRequests(silent: true);
          } else {
            setState(() {});
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _pollTimer?.cancel();
    _streamSubscription?.cancel();
    _notifSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _streamSubscription = _rideRepository.streamRideRequests().listen((_) {
      if (mounted) {
        _loadRequests(silent: true);
      }
    });

    _notifSubscription = _rideRepository.streamMyNotifications().listen((_) {
      if (mounted) {
        _loadUnreadNotifications();
      }
    });
  }

  Future<void> _loadUnreadNotifications() async {
    final count = await _rideRepository.getUnreadNotificationCount();
    if (mounted) {
      setState(() => _unreadNotifCount = count);
    }
  }

  Future<void> _loadRequests({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      // NOTE: autoReleaseExpiredOffers is intentionally NOT called here.
      // It was resetting accepted rides back to pending every 3 seconds.
      // The 5-minute expiry is handled by the Supabase updated_at trigger instead.

      final results = await Future.wait([
        _rideRepository.getAvailableRequests(excludeCurrentUser: true),
        _rideRepository.getMyDrivenRides(),
        _rideRepository.getMyRideRequests(),
      ]);

      if (!mounted) return;
      setState(() {
        _openRequests = results[0];
        _drivenRides = results[1];
        _myRequests = results[2];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppExceptions.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _acceptRide(RideRequest ride) async {
    if (_inFlightAcceptIds.contains(ride.id)) return;

    setState(() => _inFlightAcceptIds.add(ride.id));

    try {
      await _rideRepository.acceptRide(
        rideId: ride.id,
        passengerId: ride.passengerId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lift offered! The passenger has been notified to review and confirm.'),
          backgroundColor: AppColors.success,
        ),
      );

      await _loadRequests();
      _tabController.animateTo(1); // Switch to "Rides I'm Giving"
    } catch (e) {
      if (!mounted) return;

      final errorMsg = AppExceptions.getErrorMessage(e);
      final isConflict = errorMsg.toLowerCase().contains('already been accepted') ||
          errorMsg.toLowerCase().contains('no longer available');

      if (isConflict) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Ride Request Taken', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: const Text(
              'This ride request was just accepted by another colleague.\n\nThe list of open requests has been refreshed.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }

      await _loadRequests();
    } finally {
      if (mounted) {
        setState(() => _inFlightAcceptIds.remove(ride.id));
      }
    }
  }

  Future<void> _confirmRide(RideRequest ride) async {
    if (ride.remainingConfirmationSeconds <= 0 || ride.isConfirmationExpired) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The 5-minute confirmation window has expired. Your request has returned to open requests.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      await _loadRequests();
      return;
    }

    try {
      await _rideRepository.confirmRide(
        rideId: ride.id,
        driverId: ride.driverId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride confirmed! Your driver has been notified.'),
          backgroundColor: AppColors.success,
        ),
      );

      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
      await _loadRequests();
    }
  }

  Future<void> _completeRide(RideRequest ride) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Trip'),
        content: const Text('Mark this carpool trip as completed? This will update environmental CO2 savings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete Trip'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _rideRepository.completeRide(
        rideId: ride.id,
        passengerId: ride.passengerId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip marked as completed! 🌿'),
          backgroundColor: AppColors.success,
        ),
      );

      await _loadRequests();
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

  Future<void> _cancelRideOffer(RideRequest ride) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride Offer'),
        content: const Text('Are you sure you want to cancel your offer? The request will return to the open pool for other colleagues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Offer'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Offer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _rideRepository.cancelRideOffer(
        rideId: ride.id,
        passengerId: ride.passengerId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer cancelled. Request returned to available queue.'),
          backgroundColor: AppColors.success,
        ),
      );

      await _loadRequests();
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

  Future<void> _cancelMyRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride Request'),
        content: const Text('Are you sure you want to cancel this pickup request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _rideRepository.cancelRideRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride request cancelled.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadRequests();
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

  Future<void> _deleteRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Request'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this request record from your history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistically remove from the local list immediately for instant UI feedback
    setState(() {
      _myRequests.removeWhere((r) => r.id == requestId);
    });

    try {
      await _rideRepository.deleteRideRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request deleted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      // Refresh list from Supabase to ensure consistency
      await _loadRequests(silent: true);
    } catch (e) {
      if (!mounted) return;
      // Restore the item on failure by reloading
      await _loadRequests(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${AppExceptions.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _navigateToCreate() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateRequestScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadRequests();
      _tabController.animateTo(2); // Switch to "My Requests" tab
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} $hour:$minute $period';
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = const Color(0xFFEAF8EF);
        fg = AppColors.primary;
        label = 'CONFIRMED';
        break;
      case 'accepted':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'OFFERED (AWAITING CONFIRMATION)';
        break;
      case 'completed':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        label = 'COMPLETED';
        break;
      case 'cancelled':
        bg = const Color(0xFFF1F5F9);
        fg = AppColors.textMuted;
        label = 'CANCELLED';
        break;
      case 'expired':
        bg = const Color(0xFFFEE2E2);
        fg = AppColors.error;
        label = 'EXPIRED (SLOT PASSED)';
        break;
      case 'pending':
      default:
        bg = AppColors.primaryLight;
        fg = AppColors.primaryDark;
        label = 'PENDING (OPEN)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OPEN REQUESTS (FOR DRIVERS TO ACCEPT)
  // ---------------------------------------------------------------------------
  Widget _buildOpenRequestCard(RideRequest ride) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Embedded Passenger Profile Card with Name, ID, Phone and Stop
            ProfileCard(
              profileId: ride.passengerId,
              profile: ride.passenger,
              isDriver: false,
              pickupStopName: ride.pickupLocation,
              houseAddress: ride.officeLocation,
              compact: true,
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Pickup & Destination Details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Pickup: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: ride.pickupLocation,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (ride.pickupStopOrder != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Stop #${ride.pickupStopOrder}',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.business_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Destination: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: ride.officeLocation,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Leaving: ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      TextSpan(
                        text: _formatDateTime(ride.leavingTime),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (ride.additionalNote != null && ride.additionalNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: ${ride.additionalNote}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final isInFlight = _inFlightAcceptIds.contains(ride.id);
                return SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: isInFlight ? null : () => _acceptRide(ride),
                    icon: isInFlight
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.directions_car, size: 18),
                    label: Text(
                      isInFlight ? 'Offering Ride...' : 'Offer Ride / Accept Passenger',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: RIDES I'M GIVING (DRIVING ROSTER / ACCEPTED PASSENGERS)
  // ---------------------------------------------------------------------------
  Widget _buildDrivenRideCard(RideRequest ride) {
    final remainSec = ride.remainingConfirmationSeconds;
    final isExpired = (ride.status == 'accepted' || ride.status == 'pending_confirmation') && (remainSec <= 0 || ride.isConfirmationExpired);
    final remainM = (remainSec ~/ 60).toString().padLeft(2, '0');
    final remainS = (remainSec % 60).toString().padLeft(2, '0');

    final passenger = ride.passenger;
    final rawPassengerName = passenger?.fullName.trim();
    final passengerName = (rawPassengerName != null && rawPassengerName.isNotEmpty && rawPassengerName.toLowerCase() != 'colleague')
        ? rawPassengerName
        : (passenger?.employeeId != null && passenger!.employeeId.isNotEmpty ? 'Employee (${passenger.employeeId})' : 'Passenger');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ride.status == 'confirmed' ? AppColors.primary : AppColors.border,
          width: ride.status == 'confirmed' ? 1.5 : 1.0,
        ),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.drive_eta, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giving Lift To $passengerName',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text('Assigned Passenger', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                _buildStatusChip(ride.status),
              ],
            ),
            const Divider(height: 20),

            // Embedded Passenger Profile Card
            ProfileCard(
              profileId: ride.passengerId,
              isDriver: false,
              pickupStopName: ride.pickupLocation,
              houseAddress: ride.officeLocation,
              compact: true,
            ),

            if (ride.status == 'accepted' || ride.status == 'pending_confirmation') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isExpired ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isExpired ? AppColors.error : const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
                      size: 18,
                      color: isExpired ? AppColors.error : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isExpired
                            ? 'Offer expired. Passenger did not confirm within 5 minutes. Request is returning to open pool.'
                            : 'Awaiting passenger confirmation ($remainM:$remainS remaining)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired ? AppColors.error : const Color(0xFF92400E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (ride.status == 'confirmed') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF065F46)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Passenger Confirmed! ✅ Ready for trip.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Departure: ${_formatDateTime(ride.leavingTime)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),

            const SizedBox(height: 16),
            if (ride.status == 'confirmed')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelRideOffer(ride),
                      icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                      label: const Text('Cancel Offer', style: TextStyle(color: AppColors.error, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completeRide(ride),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Complete Ride', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelRideOffer(ride),
                  icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                  label: const Text('Cancel Offer', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: MY RIDE REQUESTS (AS PASSENGER)
  // ---------------------------------------------------------------------------
  Widget _buildMyRequestCard(RideRequest ride) {
    final hasDriver = ride.driverId != null && (ride.status == 'accepted' || ride.status == 'confirmed');
    final isAccepted = ride.status == 'accepted';
    final isCancelled = ride.status == 'cancelled';
    final isCompleted = ride.status == 'completed';
    final isSlotOrStatusExpired = ride.status == 'expired' || ride.isExpired;

    // Calculate 5-minute confirmation countdown
    final remainSec = ride.remainingConfirmationSeconds;
    final isExpired = isAccepted && (remainSec <= 0 || ride.isConfirmationExpired);
    final remainM = (remainSec ~/ 60).toString().padLeft(2, '0');
    final remainS = (remainSec % 60).toString().padLeft(2, '0');

    final showDeleteOption = isCancelled || isCompleted || isSlotOrStatusExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: (isExpired || isSlotOrStatusExpired)
              ? AppColors.error.withValues(alpha: 0.7)
              : (hasDriver ? AppColors.primary : AppColors.border),
          width: hasDriver ? 1.5 : 1.0,
        ),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.person_pin_circle, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Pickup Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text('Submitted Request', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                _buildStatusChip(isSlotOrStatusExpired && ride.status == 'pending' ? 'expired' : ride.status),
                if (showDeleteOption)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    tooltip: 'Delete Request',
                    onPressed: () => _deleteRequest(ride.id),
                    padding: const EdgeInsets.only(left: 6),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const Divider(height: 20),

            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Pickup: ${ride.pickupLocation}', style: const TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.business_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Destination: ${ride.officeLocation}', style: const TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Leaving: ${_formatDateTime(ride.leavingTime)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),

            // Embedded Driver Profile Card when accepted or confirmed
            if (ride.driverId != null && (isAccepted || ride.status == 'confirmed')) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final driver = ride.driver;
                  final rawDriverName = driver?.fullName.trim();
                  final driverName = (rawDriverName != null && rawDriverName.isNotEmpty && rawDriverName.toLowerCase() != 'colleague')
                      ? rawDriverName
                      : (driver?.employeeId != null && driver!.employeeId.isNotEmpty ? 'Driver (${driver.employeeId})' : 'Driver');

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              ride.status == 'confirmed' ? 'Confirmed Driver ($driverName):' : '$driverName Offered a Lift! Review details:',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ProfileCard(
                          profileId: ride.driverId!,
                          isDriver: true,
                          compact: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // 5-Minute Confirmation Timer Banner
            if (isAccepted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFFEE2E2)
                      : (remainSec > 60 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isExpired
                        ? AppColors.error
                        : (remainSec > 60 ? const Color(0xFFF59E0B) : AppColors.error),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpired ? Icons.timer_off_outlined : Icons.timer,
                      size: 22,
                      color: isExpired
                          ? AppColors.error
                          : (remainSec > 60 ? const Color(0xFFB45309) : AppColors.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        !isExpired
                            ? 'Please confirm within $remainM:$remainS, or this ride offer will be released back to other colleagues.'
                            : 'Confirmation window expired. Returning request to available queue...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExpired
                              ? AppColors.error
                              : (remainSec > 60 ? const Color(0xFF92400E) : AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            if (isAccepted) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancelMyRequest(ride.id),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isExpired ? 'Dismiss' : 'Decline / Cancel',
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isExpired ? null : () => _confirmRide(ride),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Confirm Ride', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (ride.status == 'pending' && !isSlotOrStatusExpired) ...[
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelMyRequest(ride.id),
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                  label: const Text('Cancel Request', style: TextStyle(color: AppColors.error, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else if (showDeleteOption) ...[
              // Delete permanently option for expired, cancelled or completed requests
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _deleteRequest(ride.id),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  label: Text(
                    isCancelled
                        ? 'Delete Cancelled Request'
                        : (isSlotOrStatusExpired
                            ? 'Delete Expired Request'
                            : 'Delete Completed Record'),
                    style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadRequests(),
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 90),
          Icon(icon, size: 68, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Center(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          if (action != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Commute Ride Requests'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          // Badged Notifications Bell
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.primary),
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
            tooltip: 'Notifications',
            onPressed: () async {
              await NotificationsSheet.show(
                context,
                onNavigateToRides: () {
                  _tabController.animateTo(2); // Switch to My Requests
                },
              );
              _loadUnreadNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            tooltip: 'Create Pickup Request',
            onPressed: _navigateToCreate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadRequests(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Text('Open Requests'),
                  if (_openRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_openRequests.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text("Rides I'm Giving"),
                  if (_drivenRides.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_drivenRides.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                children: [
                  const Text('My Requests'),
                  if (_myRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_myRequests.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Open Requests
                _openRequests.isEmpty
                    ? _buildEmptyState(
                        title: 'No pending ride requests',
                        subtitle: 'There are currently no active ride requests from colleagues.',
                        icon: Icons.directions_car_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadRequests(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _openRequests.length,
                          itemBuilder: (context, index) => _buildOpenRequestCard(_openRequests[index]),
                        ),
                      ),

                // Tab 2: Rides I'm Giving (Driving Roster)
                _drivenRides.isEmpty
                    ? _buildEmptyState(
                        title: 'No accepted passengers yet',
                        subtitle: 'When you accept a colleague\'s ride request, they will appear here.',
                        icon: Icons.people_outline,
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadRequests(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _drivenRides.length,
                          itemBuilder: (context, index) => _buildDrivenRideCard(_drivenRides[index]),
                        ),
                      ),

                // Tab 3: My Requests (As Passenger)
                _myRequests.isEmpty
                    ? _buildEmptyState(
                        title: 'You have no ride requests',
                        subtitle: 'Create a pickup request to get lifts from colleagues.',
                        icon: Icons.history_edu_outlined,
                        action: _navigateToCreate,
                        actionLabel: 'Create Pickup Request',
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadRequests(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _myRequests.length,
                          itemBuilder: (context, index) => _buildMyRequestCard(_myRequests[index]),
                        ),
                      ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('I Need a Ride'),
      ),
    );
  }
}
