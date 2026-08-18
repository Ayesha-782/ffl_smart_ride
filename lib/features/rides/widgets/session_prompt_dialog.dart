import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/ride_session.dart';
import '../../../core/models/user_profile.dart';
import '../data/ride_repository.dart';

class SessionPromptDialog extends StatefulWidget {
  final RideSession session;
  final UserProfile? userProfile;
  final VoidCallback onResponded;

  const SessionPromptDialog({
    super.key,
    required this.session,
    this.userProfile,
    required this.onResponded,
  });

  static Future<void> show({
    required BuildContext context,
    required RideSession session,
    UserProfile? userProfile,
    required VoidCallback onResponded,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SessionPromptDialog(
        session: session,
        userProfile: userProfile,
        onResponded: onResponded,
      ),
    );
  }

  @override
  State<SessionPromptDialog> createState() => _SessionPromptDialogState();
}

class _SessionPromptDialogState extends State<SessionPromptDialog> {
  final _rideRepository = RideRepository();
  bool _isLoading = false;
  bool _showSeatPicker = false;
  late int _seatsOffered;

  @override
  void initState() {
    super.initState();
    // Default from vehicle capacity or 3
    final cap = widget.userProfile?.vehicle?.capacity ?? 3;
    _seatsOffered = cap > 0 ? cap : 3;
  }

  Future<void> _respondAsPassenger() async {
    setState(() => _isLoading = true);
    try {
      await _rideRepository.joinPassengerLog(sessionId: widget.session.id);
      if (!mounted) return;

      Navigator.pop(context);
      widget.onResponded();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You joined the passenger queue! Drivers will see your request.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _respondAsDriver() async {
    setState(() => _isLoading = true);
    try {
      await _rideRepository.setDriverAvailability(
        sessionId: widget.session.id,
        seatsOffered: _seatsOffered,
      );
      if (!mounted) return;

      Navigator.pop(context);
      widget.onResponded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offering $_seatsOffered seats! You can now view waiting colleagues.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppExceptions.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVehicle = widget.userProfile?.hasVehicle ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_filled,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.session.slotDisplayName} Open! 🚗',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Are you riding or do you need a lift today?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_showSeatPicker) ...[
              // Seat count selection view
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'How many seats can you offer?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          onPressed: _seatsOffered > 1
                              ? () => setState(() => _seatsOffered--)
                              : null,
                          icon: const Icon(Icons.remove),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: AppColors.primaryDark,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '$_seatsOffered',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: _seatsOffered < 8
                              ? () => setState(() => _seatsOffered++)
                              : null,
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vehicle: ${widget.userProfile?.vehicle?.displayName ?? widget.userProfile?.vehicleNumber ?? "Registered Car"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _showSeatPicker = false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _respondAsDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Confirm Seats',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Primary Choice Buttons
              Row(
                children: [
                  // Button 1: I'm Riding (Driver)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (hasVehicle) {
                                setState(() => _showSeatPicker = true);
                              } else {
                                // Direct offer 1 seat
                                _respondAsDriver();
                              }
                            },
                      icon: const Icon(Icons.directions_car),
                      label: const Text(
                        "I'm Riding",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Button 2: I Want Lift (Passenger)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _respondAsPassenger,
                      icon: const Icon(Icons.hail),
                      label: const Text(
                        'I Want Lift',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Decide Later',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
