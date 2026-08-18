import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/driver_availability.dart';
import '../../../core/models/ride_match.dart';
import '../../../core/models/ride_session.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/profile_card.dart';
import '../data/ride_repository.dart';
import 'driver_priority_queue_screen.dart';

class DriverMyRideScreen extends StatefulWidget {
  final RideSession session;
  final DriverAvailability driverAvailability;

  const DriverMyRideScreen({
    super.key,
    required this.session,
    required this.driverAvailability,
  });

  @override
  State<DriverMyRideScreen> createState() => _DriverMyRideScreenState();
}

class _DriverMyRideScreenState extends State<DriverMyRideScreen> {
  final _rideRepository = RideRepository();
  final _supabase = SupabaseService.instance.client;

  List<RideMatch> _matchedPassengers = [];
  bool _loading = true;
  late DriverAvailability _availability;

  @override
  void initState() {
    super.initState();
    _availability = widget.driverAvailability;
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _loading = true);
    try {
      final updatedAvailability =
          await _rideRepository.getMyDriverAvailability(widget.session.id);
      if (updatedAvailability != null) {
        _availability = updatedAvailability;
      }

      final matches = await _rideRepository.getMyDriverMatches(widget.session.id);

      if (!mounted) return;
      setState(() {
        _matchedPassengers = matches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _cancelSinglePassenger(RideMatch match) async {
    final passengerName = match.passenger?.fullName ?? 'this passenger';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Passenger Match'),
        content: Text(
          'Are you sure you want to cancel the ride for $passengerName? They will be returned to the waiting queue.',
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
            child: const Text('Cancel Match'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _rideRepository.cancelMatch(match.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match with $passengerName cancelled. 1 seat freed up.'),
          backgroundColor: AppColors.info,
        ),
      );

      _loadMatches();
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

  Future<void> _handleCancelEntireRide() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Show follow-up cancellation prompt: "Do you need a lift instead?"
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ride Offering'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancelling will notify all your matched passengers and return them to the waiting queue.',
            ),
            SizedBox(height: 16),
            Text(
              'Do you need a lift instead as a passenger?',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'dismiss'),
            child: const Text('Keep Driving'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            onPressed: () => Navigator.pop(ctx, 'cancel_only'),
            child: const Text('Cancel Only'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, 'switch_to_passenger'),
            child: const Text('Yes, I Need Lift'),
          ),
        ],
      ),
    );

    if (choice == null || choice == 'dismiss') return;

    try {
      if (choice == 'switch_to_passenger') {
        await _rideRepository.switchDriverToPassenger(
          sessionId: widget.session.id,
          userId: user.id,
        );
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride cancelled. You are now in the passenger waiting queue!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (choice == 'cancel_only') {
        await _rideRepository.cancelDriverAvailabilityById(_availability.id);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your ride offering has been cancelled.'),
            backgroundColor: AppColors.info,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
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

  Future<void> _handleCompleteRide() async {
    final confirmedPassengers = _matchedPassengers.where((m) => m.isConfirmed).toList();
    if (confirmedPassengers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot complete trip: Passenger(s) have not confirmed the ride offer yet.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final count = confirmedPassengers.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.eco, color: AppColors.success),
            SizedBox(width: 8),
            Text('Complete Commute Trip'),
          ],
        ),
        content: Text(
          'Mark this carpool trip as completed for $count confirmed passenger${count == 1 ? '' : 's'}?\n\nThis will calculate the CO2 emissions saved and record them permanently in the company environmental audit log.',
        ),
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
            child: const Text('Complete & Save CO2'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final res = await _rideRepository.completeDriverSessionRide(widget.session.id);
      final num? numSaved = res['kg_co2_saved'] is num ? (res['kg_co2_saved'] as num) : null;
      final kgSaved = numSaved?.toDouble() ?? (count * 2.5 * 0.12);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip completed! Saved ${kgSaved.toStringAsFixed(2)} kg CO2 🌿'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openQueue() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverPriorityQueueScreen(
          session: widget.session,
          driverAvailability: _availability,
        ),
      ),
    );

    if (result == true) {
      _loadMatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiclePlate = _availability.driver?.vehicleNumber ?? 'Registered Car';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.session.slotDisplayName} - My Ride'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ride Overview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(Icons.directions_car, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.session.slotDisplayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Vehicle: $vehiclePlate',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Offered', '${_availability.seatsOffered} Seats'),
                            Container(width: 1, height: 30, color: AppColors.border),
                            _buildStatItem('Matched', '${_matchedPassengers.length} Passengers'),
                            Container(width: 1, height: 30, color: AppColors.border),
                            _buildStatItem('Remaining', '${_availability.seatsRemaining} Left'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Matched Passengers Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Matched Passengers (${_matchedPassengers.length})',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_availability.seatsRemaining > 0)
                        TextButton.icon(
                          onPressed: _openQueue,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Passengers'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_matchedPassengers.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.people_outline, size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          const Text(
                            'No passengers matched yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Browse the waiting queue to pick colleagues along your route.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openQueue,
                            icon: const Icon(Icons.queue),
                            label: const Text('Open Priority Queue'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _matchedPassengers.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final m = _matchedPassengers[i];
                        final p = m.passenger;

                        return ProfileCard(
                          profileId: m.passengerId,
                          profile: p,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: m.isConfirmed ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: m.isConfirmed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                                child: Text(
                                  m.isConfirmed ? 'Confirmed ✅' : 'Awaiting ⏳',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: m.isConfirmed ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () => _cancelSinglePassenger(m),
                                icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                                tooltip: 'Cancel this passenger',
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 28),

                  if (_matchedPassengers.isNotEmpty) ...[
                    Builder(
                      builder: (ctx) {
                        final confirmedCount = _matchedPassengers.where((m) => m.isConfirmed).length;
                        final hasConfirmed = confirmedCount > 0;

                        return SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: hasConfirmed ? _handleCompleteRide : null,
                            icon: const Icon(Icons.check_circle_outline, size: 20),
                            label: Text(
                              hasConfirmed
                                  ? 'Complete Trip ($confirmedCount Confirmed Passenger${confirmedCount == 1 ? '' : 's'}) 🌿'
                                  : 'Awaiting Passenger Confirmation ⏳',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasConfirmed ? AppColors.primary : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: hasConfirmed ? 2 : 0,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Cancel Entire Ride Button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _handleCancelEntireRide,
                      icon: const Icon(Icons.cancel, color: AppColors.error),
                      label: const Text(
                        'Cancel Entire Ride',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
