import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/ride_slot.dart';
import '../../../core/models/user_profile.dart';
import '../../auth/data/auth_repository.dart';
import '../data/ride_repository.dart';

class _PickupLocationOption {
  final String id;
  final String label;
  final String pickupText;
  final int stopOrder;
  final IconData icon;

  const _PickupLocationOption({
    required this.id,
    required this.label,
    required this.pickupText,
    required this.stopOrder,
    this.icon = Icons.location_on_outlined,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PickupLocationOption && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  RideSlot _selectedSlot = RideSlot.slots[0];
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 30);
  bool _loading = false;

  final _rideRepository = RideRepository();
  final _authRepository = AuthRepository();

  UserProfile? _userProfile;
  List<_PickupLocationOption> _pickupOptions = [];
  _PickupLocationOption? _selectedPickupOption;
  _PickupLocationOption? _selectedDestinationOption;

  DateTime get _leavingTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  @override
  void initState() {
    super.initState();
    _buildOptionsAndPrepopulate();
    _loadUserProfile();
    _initDefaultSlotAndTime();
  }

  void _initDefaultSlotAndTime() {
    final now = DateTime.now();
    final tod = TimeOfDay(hour: now.hour, minute: now.minute);
    final activeSlot = RideSlot.getMatchingSlot(tod);

    if (activeSlot != null) {
      _selectedSlot = activeSlot;
      _selectedDate = now;
      // Round up to next 15-min interval inside this slot
      final currentMinutes = now.hour * 60 + now.minute;
      final slotEndMinutes = activeSlot.end.hour * 60 + activeSlot.end.minute;
      int nextMin = ((currentMinutes + 14) ~/ 15) * 15;
      if (nextMin > slotEndMinutes) nextMin = slotEndMinutes;
      _selectedTime = TimeOfDay(hour: nextMin ~/ 60, minute: nextMin % 60);
    } else {
      // Find upcoming slot today or tomorrow morning
      final currentMinutes = now.hour * 60 + now.minute;
      if (currentMinutes < 7 * 60) {
        _selectedSlot = RideSlot.slots[0]; // Morning
        _selectedDate = now;
        _selectedTime = const TimeOfDay(hour: 7, minute: 30);
      } else if (currentMinutes < 12 * 60 + 30) {
        _selectedSlot = RideSlot.slots[1]; // Lunch
        _selectedDate = now;
        _selectedTime = const TimeOfDay(hour: 12, minute: 30);
      } else if (currentMinutes < 16 * 60 + 30) {
        _selectedSlot = RideSlot.slots[2]; // Evening
        _selectedDate = now;
        _selectedTime = const TimeOfDay(hour: 16, minute: 30);
      } else {
        // Tomorrow morning
        _selectedSlot = RideSlot.slots[0];
        _selectedDate = now.add(const Duration(days: 1));
        _selectedTime = const TimeOfDay(hour: 7, minute: 30);
      }
    }
  }

  void _buildOptionsAndPrepopulate() {
    final options = <_PickupLocationOption>[];

    // 1. Current saved residential address from registration profile
    if (_userProfile?.homeAddress != null && _userProfile!.homeAddress!.trim().isNotEmpty) {
      final addr = _userProfile!.homeAddress!.trim();
      options.add(_PickupLocationOption(
        id: 'saved_home',
        label: 'My Saved Residence ($addr)',
        pickupText: addr,
        stopOrder: _userProfile?.pickupStopOrder ?? 1,
        icon: Icons.home_rounded,
      ));
    }

    // 2. Specific requested locations:
    options.addAll(const [
      _PickupLocationOption(
        id: 'd_type',
        label: 'D Type',
        pickupText: 'D Type',
        stopOrder: 1,
        icon: Icons.cottage_outlined,
      ),
      _PickupLocationOption(
        id: 'e_type',
        label: 'E Type',
        pickupText: 'E Type',
        stopOrder: 2,
        icon: Icons.apartment_outlined,
      ),
      _PickupLocationOption(
        id: 'c_type',
        label: 'C Type',
        pickupText: 'C Type',
        stopOrder: 3,
        icon: Icons.house_outlined,
      ),
      _PickupLocationOption(
        id: 'management_club_mess',
        label: 'Management Club / Mess',
        pickupText: 'Management Club / Mess',
        stopOrder: 4,
        icon: Icons.restaurant_outlined,
      ),
      _PickupLocationOption(
        id: 'gate_3',
        label: 'Gate 3 (Factory Gate)',
        pickupText: 'Gate 3 (Factory Gate)',
        stopOrder: 5,
        icon: Icons.meeting_room_outlined,
      ),
      _PickupLocationOption(
        id: 'ccr_1',
        label: 'CCR-1',
        pickupText: 'CCR-1',
        stopOrder: 6,
        icon: Icons.computer_outlined,
      ),
      _PickupLocationOption(
        id: 'ccr_2',
        label: 'CCR-2',
        pickupText: 'CCR-2',
        stopOrder: 7,
        icon: Icons.computer_outlined,
      ),
    ]);

    setState(() {
      _pickupOptions = options;
      if (_selectedPickupOption == null || !_pickupOptions.contains(_selectedPickupOption)) {
        _selectedPickupOption = _pickupOptions.first;
      }
      if (_selectedDestinationOption == null || !_pickupOptions.contains(_selectedDestinationOption)) {
        _selectedDestinationOption = _pickupOptions.firstWhere(
          (opt) => opt.id == 'gate_3',
          orElse: () => _pickupOptions.length > 4 ? _pickupOptions[4] : _pickupOptions.last,
        );
      }
    });
  }

  void _swapPickupAndDestination() {
    setState(() {
      final tempOption = _selectedPickupOption;
      _selectedPickupOption = _selectedDestinationOption;
      _selectedDestinationOption = tempOption;
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final prof = await _authRepository.getMyProfile();
      if (prof != null && mounted) {
        setState(() {
          _userProfile = prof;
        });
        _buildOptionsAndPrepopulate();
      }
    } catch (_) {}
  }

  void _onTimeSelected(TimeOfDay time) {
    setState(() {
      _selectedTime = time;
    });
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: _selectedDate.isBefore(DateTime.now()) ? DateTime.now() : _selectedDate,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final pickup = _selectedPickupOption?.pickupText.trim() ?? '';
    final destination = _selectedDestinationOption?.pickupText.trim() ?? '';

    if (pickup.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pickup and destination locations.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedPickupOption?.id == _selectedDestinationOption?.id ||
        pickup.toLowerCase() == destination.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup and Destination cannot be the same location. Please select different points.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final departure = _leavingTime;

    if (!RideSlot.isDateTimeInAnySlot(departure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected departure time is outside operating slots.\n\nAllowed commute slots:\n${RideSlot.formattedSlotsSummary}',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (departure.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot request a ride in a past time slot. Please choose an upcoming slot or date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _rideRepository.createRideRequest(
        pickupLocation: pickup,
        officeLocation: destination,
        pickupStopOrder: _selectedPickupOption?.stopOrder ?? 1,
        leavingTime: departure,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride request submitted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      final message = AppExceptions.getErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isTomorrow(DateTime d) {
    final tom = DateTime.now().add(const Duration(days: 1));
    return d.year == tom.year && d.month == tom.month && d.day == tom.day;
  }

  @override
  Widget build(BuildContext context) {
    final isSameLocation = _selectedPickupOption != null &&
        _selectedDestinationOption != null &&
        _selectedPickupOption!.id == _selectedDestinationOption!.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('I Need a Ride'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Ride Request',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // 1. PICKUP LOCATION DROPDOWN
                // ==========================================
                if (_pickupOptions.isNotEmpty)
                  DropdownButtonFormField<_PickupLocationOption>(
                    initialValue: _selectedPickupOption,
                    isExpanded: true,
                    decoration: _inputDecoration('Pickup Location', Icons.location_on_outlined),
                    validator: (opt) {
                      if (opt == null) return 'Please select a pickup location';
                      if (opt.id == _selectedDestinationOption?.id) {
                        return 'Pickup cannot be the same as destination';
                      }
                      return null;
                    },
                    items: _pickupOptions.map((option) {
                      return DropdownMenuItem<_PickupLocationOption>(
                        value: option,
                        child: Row(
                          children: [
                            Icon(option.icon, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.label,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (opt) {
                      if (opt != null) {
                        setState(() {
                          _selectedPickupOption = opt;
                        });
                      }
                    },
                  ),
                const SizedBox(height: 12),

                // Swap Pickup & Destination Direction Button
                Center(
                  child: InkWell(
                    onTap: _swapPickupAndDestination,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_vert, size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Swap Direction (2-Way Flow)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ==========================================
                // 2. DESTINATION LOCATION DROPDOWN
                // ==========================================
                if (_pickupOptions.isNotEmpty)
                  DropdownButtonFormField<_PickupLocationOption>(
                    initialValue: _selectedDestinationOption,
                    isExpanded: true,
                    decoration: _inputDecoration('Destination Location', Icons.flag_outlined),
                    validator: (opt) {
                      if (opt == null) return 'Please select a destination location';
                      if (opt.id == _selectedPickupOption?.id) {
                        return 'Destination cannot be the same as pickup';
                      }
                      return null;
                    },
                    items: _pickupOptions.map((option) {
                      return DropdownMenuItem<_PickupLocationOption>(
                        value: option,
                        child: Row(
                          children: [
                            Icon(option.icon, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.label,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (opt) {
                      if (opt != null) {
                        setState(() {
                          _selectedDestinationOption = opt;
                        });
                      }
                    },
                  ),

                if (isSameLocation) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pickup and destination locations cannot be identical.',
                            style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // ==========================================
                // 3. TRAVEL DATE SELECTOR
                // ==========================================
                InkWell(
                  onTap: _loading ? null : _chooseDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Travel Date',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}${_isToday(_selectedDate) ? ' (Today)' : (_isTomorrow(_selectedDate) ? ' (Tomorrow)' : '')}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Change Date',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ==========================================
                // 4. ACTIVE SLOT DISPLAY (READ-ONLY, SYSTEM-CONTROLLED)
                // ==========================================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded, size: 20, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Slot',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedSlot.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Auto',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ==========================================
                // 5. DEPARTURE TIME SELECTION (STEP 2: WITHIN SLOT)
                // ==========================================
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.access_time_filled, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Departure Time',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedSlot.getIntervals().map((time) {
                          final isSelected = _selectedTime.hour == time.hour &&
                              _selectedTime.minute == time.minute;

                          return InkWell(
                            onTap: _loading ? null : () => _onTimeSelected(time),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                RideSlot.formatTimeOfDay(time),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF8EF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Scheduled: ${RideSlot.formatTimeOfDay(_selectedTime)} • ${_selectedSlot.displayName}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'ℹ Unaccepted requests automatically expire once their operating slot ends.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
