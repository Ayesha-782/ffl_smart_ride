import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/driver_availability.dart';
import '../../../core/models/priority_passenger.dart';
import '../../../core/models/ride_session.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/profile_card.dart';
import '../data/ride_repository.dart';

class DriverPriorityQueueScreen extends StatefulWidget {
  final RideSession session;
  final DriverAvailability driverAvailability;

  const DriverPriorityQueueScreen({
    super.key,
    required this.session,
    required this.driverAvailability,
  });

  @override
  State<DriverPriorityQueueScreen> createState() => _DriverPriorityQueueScreenState();
}

class _DriverPriorityQueueScreenState extends State<DriverPriorityQueueScreen> {
  final _rideRepository = RideRepository();
  final _supabase = SupabaseService.instance.client;

  List<PriorityPassenger> _passengers = [];
  final Set<String> _selectedPassengerIds = {};
  bool _loading = true;
  bool _submitting = false;
  late int _seatsRemaining;
  StreamSubscription? _passengerLogSub;
  StreamSubscription? _rideMatchesSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _seatsRemaining = widget.driverAvailability.seatsRemaining;
    _loadQueue();
    _setupRealtime();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadQueue(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _passengerLogSub?.cancel();
    _rideMatchesSub?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    // 1. Listen for passenger log status changes (e.g. joined/waiting/matched)
    _passengerLogSub = _rideRepository
        .streamPassengerLogChanges(widget.session.id)
        .listen((_) {
      if (mounted) {
        _loadQueue(silent: true);
      }
    });

    // 2. Listen for ride_matches insertions/deletions (immediate update when another driver matches)
    _rideMatchesSub = _rideRepository
        .streamSessionMatches(widget.session.id)
        .listen((_) {
      if (mounted) {
        _loadQueue(silent: true);
      }
    });
  }

  Future<void> _loadQueue({bool silent = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (!silent) setState(() => _loading = true);

    try {
      // 1. Refresh driver availability for accurate remaining seats
      final updatedAvailability =
          await _rideRepository.getMyDriverAvailability(widget.session.id);
      if (updatedAvailability != null && mounted) {
        setState(() {
          _seatsRemaining = updatedAvailability.seatsRemaining;
        });
      }

      // 2. Fetch nearest-priority queue
      final queue = await _rideRepository.getPriorityQueue(
        sessionId: widget.session.id,
        driverId: user.id,
      );

      if (!mounted) return;

      // Strictly filter to waiting passengers only
      final waitingQueue = queue
          .where((p) => p.status.toLowerCase() == 'waiting' && p.passengerId != user.id)
          .toList();

      setState(() {
        _passengers = waitingQueue;
        // Clean up selected IDs that are no longer in the queue
        _selectedPassengerIds.removeWhere(
          (id) => !waitingQueue.any((p) => p.passengerId == id),
        );
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
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
  }

  void _togglePassenger(String passengerId) {
    if (_submitting) return; // Optimistic lock while in-flight

    setState(() {
      if (_selectedPassengerIds.contains(passengerId)) {
        _selectedPassengerIds.remove(passengerId);
      } else {
        if (_selectedPassengerIds.length < _seatsRemaining) {
          _selectedPassengerIds.add(passengerId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can select at most $_seatsRemaining passengers with your remaining seats.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _assignSelectedPassengers() async {
    if (_selectedPassengerIds.isEmpty || _submitting) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Optimistically lock button immediately on tap
    setState(() => _submitting = true);

    try {
      await _rideRepository.assignPassengers(
        sessionId: widget.session.id,
        driverId: user.id,
        passengerIds: _selectedPassengerIds.toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully matched ${_selectedPassengerIds.length} colleague${_selectedPassengerIds.length > 1 ? "s" : ""}! 🎉',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _selectedPassengerIds.clear();
      });

      final errorMsg = AppExceptions.getErrorMessage(e);
      final isConflict = errorMsg.toLowerCase().contains('already been matched') ||
          errorMsg.toLowerCase().contains('no longer in the waiting') ||
          errorMsg.toLowerCase().contains('not in the queue');

      if (isConflict) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Passenger Already Matched', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: const Text(
              'One or more of the selected colleagues was just matched by another driver along the route.\n\nThe queue has been refreshed automatically.',
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
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Reload fresh queue
      await _loadQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverStopOrder = _passengers.isNotEmpty
        ? _passengers.first.driverStopOrder
        : (widget.driverAvailability.driver?.pickupStopOrder ?? 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.session.slotDisplayName} Queue'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _loadQueue(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Queue',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Info Banner: Driver's Route & Seats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Your Route: Stop #$driverStopOrder',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ordered by proximity along township route',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _seatsRemaining > 0 ? AppColors.primaryLight : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _seatsRemaining > 0 ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '$_seatsRemaining Seats Left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _seatsRemaining > 0 ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Queue Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _passengers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Waiting Passengers',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'All colleagues for this session are matched or have not requested a lift yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadQueue(),
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _passengers.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final p = _passengers[i];
                            final isSelected = _selectedPassengerIds.contains(p.passengerId);
                            final canSelect = isSelected || _selectedPassengerIds.length < _seatsRemaining;

                            return ProfileCard(
                              profileId: p.passengerId,
                              pickupStopName: p.pickupStopName ?? 'Stop #${p.passengerStopOrder}',
                              houseAddress: p.homeAddress,
                              stopsAway: p.stopsAway,
                              isSelected: isSelected,
                              leading: Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                onChanged: canSelect
                                    ? (_) => _togglePassenger(p.passengerId)
                                    : null,
                              ),
                              onTap: canSelect ? () => _togglePassenger(p.passengerId) : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),

      // Bottom Action Bar: Confirm Match
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedPassengerIds.length} of $_seatsRemaining Selected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Matching will confirm their lift instantly',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _selectedPassengerIds.isNotEmpty && !_submitting
                    ? _assignSelectedPassengers
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Offer Lift (${_selectedPassengerIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
