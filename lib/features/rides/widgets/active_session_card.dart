import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/ride_session.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/profile_card.dart';
import '../data/ride_repository.dart';
import '../screens/driver_my_ride_screen.dart';
import 'session_prompt_dialog.dart';

class ActiveSessionCard extends StatelessWidget {
  final RideSession session;
  final UserSessionStatus sessionStatus;
  final UserProfile? userProfile;
  final VoidCallback onRefresh;
  final VoidCallback onViewQueue;

  const ActiveSessionCard({
    super.key,
    required this.session,
    required this.sessionStatus,
    this.userProfile,
    required this.onRefresh,
    required this.onViewQueue,
  });

  Future<void> _handleDriverCancel(BuildContext context) async {
    final da = sessionStatus.driverAvailability;
    if (da == null) return;

    final user = SupabaseService.instance.client.auth.currentUser;
    if (user == null) return;

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

    final rideRepo = RideRepository();
    try {
      if (choice == 'switch_to_passenger') {
        await rideRepo.switchDriverToPassenger(
          sessionId: session.id,
          userId: user.id,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are now placed in the passenger waiting queue!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (choice == 'cancel_only') {
        await rideRepo.cancelDriverAvailabilityById(da.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your ride offering has been cancelled.'),
            backgroundColor: AppColors.info,
          ),
        );
      }

      onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handlePassengerCancel(BuildContext context) async {
    final pl = sessionStatus.passengerLog;
    if (pl == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Lift Request'),
        content: const Text(
          'Are you sure you want to remove yourself from the waiting queue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Waiting'),
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

    final rideRepo = RideRepository();
    try {
      await rideRepo.cancelPassengerRequest(pl.id);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your lift request has been cancelled.'),
          backgroundColor: AppColors.info,
        ),
      );

      onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openMyRideScreen(BuildContext context) async {
    final da = sessionStatus.driverAvailability;
    if (da == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverMyRideScreen(
          session: session,
          driverAvailability: da,
        ),
      ),
    );

    onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    switch (sessionStatus.responseType) {
      case UserSessionResponseType.none:
        return _buildUnrespondedCard(context);
      case UserSessionResponseType.driver:
        return _buildDriverCard(context);
      case UserSessionResponseType.passenger:
        return _buildPassengerCard(context);
      case UserSessionResponseType.matched:
        return _buildMatchedCard(context);
    }
  }

  // 1. Unresponded Banner
  Widget _buildUnrespondedCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF5EEAD4), size: 8),
                    SizedBox(width: 6),
                    Text(
                      'ACTIVE SESSION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                session.slotDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Ride Session is Open! 🚗',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Are you driving today or do you need a lift to the plant?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    SessionPromptDialog.show(
                      context: context,
                      session: session,
                      userProfile: userProfile,
                      onResponded: onRefresh,
                    );
                  },
                  icon: const Icon(Icons.touch_app, size: 18),
                  label: const Text(
                    'Respond Now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Active Driver Card
  Widget _buildDriverCard(BuildContext context) {
    final da = sessionStatus.driverAvailability;
    final remaining = da?.seatsRemaining ?? 0;
    final offered = da?.seatsOffered ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 1.5),
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
                radius: 18,
                child: Icon(Icons.directions_car, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "You're Offering Seats Today",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      session.slotDisplayName,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$remaining of $offered Seats Left',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openMyRideScreen(context),
                  icon: const Icon(Icons.manage_accounts, size: 18),
                  label: const Text('Manage My Ride'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _handleDriverCancel(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Active Passenger Queue Card
  Widget _buildPassengerCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                child: Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'In Waiting Queue (Lift Requested)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Session: ${session.slotDisplayName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Drivers along your route are matching passengers right now. You will receive an instant notification once confirmed.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _handlePassengerCancel(context),
              icon: const Icon(Icons.close, size: 16, color: AppColors.error),
              label: const Text(
                'Cancel Request',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Confirmed Match Card
  Widget _buildMatchedCard(BuildContext context) {
    final match = sessionStatus.rideMatch;
    final driver = match?.driver;
    final passenger = match?.passenger;
    final isDriver = userProfile?.id == match?.driverId;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'RIDE MATCHED',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                session.slotDisplayName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isDriver) ...[
            ProfileCard(
              profileId: match?.passengerId,
              profile: passenger,
              isDriver: false,
            ),
          ] else ...[
            ProfileCard(
              profileId: match?.driverId,
              profile: driver,
              isDriver: true,
            ),
          ],
        ],
      ),
    );
  }
}
