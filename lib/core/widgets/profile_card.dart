import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../services/supabase_service.dart';

class ProfileCard extends StatefulWidget {
  final String? profileId;
  final UserProfile? profile;
  final Vehicle? vehicle;
  final bool isDriver;
  final int? seatsOffered;
  final int? seatsRemaining;
  final int? stopsAway;
  final String? pickupStopName;
  final String? houseAddress;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool compact;
  final bool isSelected;

  const ProfileCard({
    super.key,
    this.profileId,
    this.profile,
    this.vehicle,
    this.isDriver = false,
    this.seatsOffered,
    this.seatsRemaining,
    this.stopsAway,
    this.pickupStopName,
    this.houseAddress,
    this.trailing,
    this.leading,
    this.onTap,
    this.compact = false,
    this.isSelected = false,
  });

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  UserProfile? _profile;
  Vehicle? _vehicle;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _vehicle = widget.vehicle ?? widget.profile?.vehicle;

    if (_profile == null && widget.profileId != null) {
      _fetchProfileAndVehicle(widget.profileId!);
    }
  }

  @override
  void didUpdateWidget(covariant ProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != null) {
      _profile = widget.profile;
      _vehicle = widget.vehicle ?? widget.profile?.vehicle;
    } else if (widget.profileId != oldWidget.profileId && widget.profileId != null) {
      _fetchProfileAndVehicle(widget.profileId!);
    }
  }

  Future<void> _fetchProfileAndVehicle(String profileId) async {
    setState(() => _loading = true);
    try {
      final supabase = SupabaseService.instance.client;
      Map<String, dynamic>? data;
      try {
        data = await supabase
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
            .eq('id', profileId)
            .maybeSingle();
      } catch (_) {}

      data ??= await supabase
          .from('profiles')
          .select('*')
          .eq('id', profileId)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        final profile = UserProfile.fromJson(data);
        setState(() {
          _profile = profile;
          _vehicle = profile.vehicle;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _getProximityColor(int stopsAway) {
    if (stopsAway == 0) return AppColors.success;
    if (stopsAway == 1) return AppColors.primary;
    if (stopsAway == 2) return const Color(0xFFE65100);
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    final rawName = _profile?.fullName.trim() ?? '';
    final name = (rawName.isNotEmpty && rawName.toLowerCase() != 'colleague')
        ? rawName
        : (_profile?.employeeId.isNotEmpty == true
            ? 'Employee (${_profile!.employeeId})'
            : (widget.isDriver ? 'Driver' : 'Passenger'));
    final empId = _profile?.employeeId ?? '';
    final phone = _profile?.phone ?? '';
    final address = widget.houseAddress ?? _profile?.homeAddress ?? '';
    final stopOrder = _profile?.pickupStopOrder;
    final stopName = widget.pickupStopName ??
        (stopOrder != null ? 'Stop #$stopOrder' : 'Designated Stop');

    // Vehicle display for driver
    final vMake = _vehicle?.make ?? '';
    final vModel = _vehicle?.model ?? '';
    final vPlate = _vehicle?.licensePlate ?? _profile?.vehicleNumber ?? '';
    final vehicleSummary = vMake.isNotEmpty
        ? '$vMake $vModel'
        : (vPlate.isNotEmpty ? 'Vehicle ($vPlate)' : 'Registered Vehicle');

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected ? AppColors.primary : AppColors.border,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 10),
            ] else ...[
              CircleAvatar(
                radius: widget.compact ? 18 : 22,
                backgroundColor: widget.isDriver
                    ? const Color(0xFFE8F5E9)
                    : AppColors.primaryLight,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : (widget.isDriver ? 'D' : 'P'),
                  style: TextStyle(
                    fontSize: widget.compact ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: widget.isDriver ? AppColors.success : AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name and Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: widget.compact ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.stopsAway != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getProximityColor(widget.stopsAway!).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.stopsAway == 0
                                ? 'Same Stop'
                                : '${widget.stopsAway} Stop${widget.stopsAway == 1 ? "" : "s"} Away',
                            style: TextStyle(
                              color: _getProximityColor(widget.stopsAway!),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (widget.isDriver && widget.seatsOffered != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.seatsRemaining ?? widget.seatsOffered} of ${widget.seatsOffered} Seats',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Row 2: Employee ID & Phone
                  if (empId.isNotEmpty || phone.isNotEmpty)
                    Text(
                      [
                        if (empId.isNotEmpty) 'ID: $empId',
                        if (phone.isNotEmpty) phone,
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 6),

                  // Driver Details (Car make/model & Plate)
                  if (widget.isDriver) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_car, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              vehicleSummary,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (vPlate.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                vPlate.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Passenger Details (Pickup Stop & Home Address)
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            stopOrder != null ? 'Stop #$stopOrder: $stopName' : stopName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.home_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
