import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../data/admin_repository.dart';
import '../services/pdf_report_service.dart';
import '../widgets/co2_chart_card.dart';
import '../widgets/leaderboard_table.dart';
import '../widgets/rides_bar_chart_card.dart';
import '../widgets/summary_metric_card.dart';
import '../widgets/top_contributors_chart_card.dart';

enum DateRangeFilter {
  allTime,
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  custom,
}

class AdminOverviewScreen extends StatefulWidget {
  final AdminRepository adminRepository;
  final VoidCallback? onNavigateToReports;

  const AdminOverviewScreen({
    super.key,
    required this.adminRepository,
    this.onNavigateToReports,
  });

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  DateRangeFilter _selectedFilter = DateRangeFilter.thisMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;
  AdminDashboardSummary _summary = AdminDashboardSummary.empty();
  List<TimeSeriesPoint> _co2Trends = [];
  List<TimeSeriesPoint> _ridesTrends = [];
  List<LeaderboardEntry> _topDrivers = [];
  List<LeaderboardEntry> _topPassengers = [];

  @override
  void initState() {
    super.initState();
    _applyFilterDates(DateRangeFilter.thisMonth);
    _loadData();
  }

  void _applyFilterDates(DateRangeFilter filter) {
    final now = DateTime.now();
    _selectedFilter = filter;

    switch (filter) {
      case DateRangeFilter.allTime:
        _startDate = null;
        _endDate = null;
        break;
      case DateRangeFilter.today:
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangeFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(monday.year, monday.month, monday.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangeFilter.thisMonth:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case DateRangeFilter.lastMonth:
        _startDate = DateTime(now.year, now.month - 1, 1);
        _endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
        break;
      case DateRangeFilter.custom:
        // Keep custom range
        break;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        widget.adminRepository.fetchDashboardSummary(startDate: _startDate, endDate: _endDate),
        widget.adminRepository.fetchSavingsTrends(startDate: _startDate, endDate: _endDate),
        widget.adminRepository.fetchRidesTrends(startDate: _startDate, endDate: _endDate),
        widget.adminRepository.fetchDriverLeaderboard(limit: 10, startDate: _startDate, endDate: _endDate),
        widget.adminRepository.fetchPassengerLeaderboard(limit: 10, startDate: _startDate, endDate: _endDate),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as AdminDashboardSummary;
          _co2Trends = results[1] as List<TimeSeriesPoint>;
          _ridesTrends = results[2] as List<TimeSeriesPoint>;
          _topDrivers = results[3] as List<LeaderboardEntry>;
          _topPassengers = results[4] as List<LeaderboardEntry>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime(now.year, now.month, 1),
        end: _endDate ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = DateRangeFilter.custom;
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadData();
    }
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case DateRangeFilter.allTime:
        return 'All Time';
      case DateRangeFilter.today:
        return 'Today';
      case DateRangeFilter.thisWeek:
        return 'This Week';
      case DateRangeFilter.thisMonth:
        return 'This Month';
      case DateRangeFilter.lastMonth:
        return 'Last Month';
      case DateRangeFilter.custom:
        if (_startDate != null && _endDate != null) {
          return '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}';
        }
        return 'Custom Range';
    }
  }

  Future<void> _handleDownloadPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating official PDF report...')),
      );

      await PdfReportService.downloadOrPrintReport(
        summary: _summary,
        topDrivers: _topDrivers,
        topPassengers: _topPassengers,
        periodLabel: _getFilterLabel(),
        startDate: _startDate,
        endDate: _endDate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to generate report: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;
    final isTablet = screenWidth >= 700 && screenWidth < 1100;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP TOOLBAR & DATE FILTER
            _buildToolbar(),
            const SizedBox(height: 20),

            // 2. SUMMARY CARDS
            _buildSummaryCardsGrid(isDesktop, isTablet),
            const SizedBox(height: 24),

            // 3. CHARTS GRID
            if (isDesktop) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Co2ChartCard(dataPoints: _co2Trends, isLoading: _isLoading),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: RidesBarChartCard(dataPoints: _ridesTrends, isLoading: _isLoading),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TopContributorsChartCard(
                contributors: _topDrivers.isNotEmpty ? _topDrivers : _topPassengers,
                isLoading: _isLoading,
              ),
            ] else ...[
              Co2ChartCard(dataPoints: _co2Trends, isLoading: _isLoading),
              const SizedBox(height: 16),
              RidesBarChartCard(dataPoints: _ridesTrends, isLoading: _isLoading),
              const SizedBox(height: 16),
              TopContributorsChartCard(
                contributors: _topDrivers.isNotEmpty ? _topDrivers : _topPassengers,
                isLoading: _isLoading,
              ),
            ],
            const SizedBox(height: 24),

            // 4. LEADERBOARDS (DRIVERS & PASSENGERS FROM RIDE_COMPLETION_LOG)
            if (isDesktop) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LeaderboardTable(
                      title: 'Top Drivers',
                      roleBadge: 'Driver (Seats Shared)',
                      icon: Icons.drive_eta,
                      entries: _topDrivers,
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: LeaderboardTable(
                      title: 'Top Passengers',
                      roleBadge: 'Passenger (Rides Taken)',
                      icon: Icons.person_pin_circle,
                      entries: _topPassengers,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ] else ...[
              LeaderboardTable(
                title: 'Top Drivers',
                roleBadge: 'Driver (Seats Shared)',
                icon: Icons.drive_eta,
                entries: _topDrivers,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              LeaderboardTable(
                title: 'Top Passengers',
                roleBadge: 'Passenger (Rides Taken)',
                icon: Icons.person_pin_circle,
                entries: _topPassengers,
                isLoading: _isLoading,
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview & Analytics',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Real-time carpool environmental impact & audit statistics',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filter Dropdown / Segment
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DateRangeFilter>(
                  value: _selectedFilter,
                  icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                  items: const [
                    DropdownMenuItem(value: DateRangeFilter.thisMonth, child: Text('This Month')),
                    DropdownMenuItem(value: DateRangeFilter.lastMonth, child: Text('Last Month')),
                    DropdownMenuItem(value: DateRangeFilter.thisWeek, child: Text('This Week')),
                    DropdownMenuItem(value: DateRangeFilter.today, child: Text('Today')),
                    DropdownMenuItem(value: DateRangeFilter.allTime, child: Text('All Time')),
                    DropdownMenuItem(value: DateRangeFilter.custom, child: Text('Custom Date...')),
                  ],
                  onChanged: (filter) {
                    if (filter == DateRangeFilter.custom) {
                      _selectCustomDateRange();
                    } else if (filter != null) {
                      setState(() => _applyFilterDates(filter));
                      _loadData();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Download PDF Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _handleDownloadPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text(
                'Download Report',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCardsGrid(bool isDesktop, bool isTablet) {
    final cards = [
      SummaryMetricCard(
        title: 'Completed Rides',
        value: _summary.totalCompletedRides.toString(),
        subtitle: 'Verified Carpool Trips',
        icon: Icons.check_circle_outline,
        iconBgColor: AppColors.primaryLight,
        iconColor: AppColors.primary,
      ),
      SummaryMetricCard(
        title: 'CO₂ Saved',
        value: '${_summary.totalCo2SavedKg.toStringAsFixed(1)} kg',
        subtitle: '${_summary.totalCo2SavedTons.toStringAsFixed(3)} Metric Tons',
        icon: Icons.eco,
        gradient: AppColors.ecoGradient,
      ),
      SummaryMetricCard(
        title: 'Fuel Saved',
        value: '${_summary.totalFuelSavedLiters.toStringAsFixed(1)} L',
        subtitle: 'Avg @ 0.08 L/km',
        icon: Icons.local_gas_station,
        iconBgColor: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
      ),
      SummaryMetricCard(
        title: 'Active Users',
        value: '${_summary.activeUsers} / ${_summary.totalRegisteredUsers}',
        subtitle: 'Employees on Platform',
        icon: Icons.people_alt_outlined,
        iconBgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );
    } else if (isTablet) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        children: cards,
      );
    } else {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: c,
                ))
            .toList(),
      );
    }
  }
}
