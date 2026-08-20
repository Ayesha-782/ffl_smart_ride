import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../data/admin_repository.dart';
import '../services/pdf_report_service.dart';
import 'admin_overview_screen.dart';

class AdminReportScreen extends StatefulWidget {
  final AdminRepository adminRepository;

  const AdminReportScreen({
    super.key,
    required this.adminRepository,
  });

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  DateRangeFilter _selectedFilter = DateRangeFilter.thisMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;
  AdminDashboardSummary _summary = AdminDashboardSummary.empty();
  List<LeaderboardEntry> _topDrivers = [];
  List<LeaderboardEntry> _topPassengers = [];

  @override
  void initState() {
    super.initState();
    _applyFilterDates(DateRangeFilter.thisMonth);
    _loadReportData();
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
        break;
    }
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.adminRepository.fetchDashboardSummary(startDate: _startDate, endDate: _endDate),
        widget.adminRepository.fetchDriverLeaderboard(limit: 10, startDate: _startDate, endDate: _endDate),
        widget.adminRepository.fetchPassengerLeaderboard(limit: 10, startDate: _startDate, endDate: _endDate),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as AdminDashboardSummary;
          _topDrivers = results[1] as List<LeaderboardEntry>;
          _topPassengers = results[2] as List<LeaderboardEntry>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      _loadReportData();
    }
  }

  String _getFilterLabel() {
    switch (_selectedFilter) {
      case DateRangeFilter.allTime:
        return 'All Time Records';
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
          return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
        }
        return 'Custom Date Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOOLBAR
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Audit & Sustainability Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Export verified corporate PDF reports with environmental impact and leaderboard data',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
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
                      DropdownMenuItem(value: DateRangeFilter.allTime, child: Text('All Time Records')),
                      DropdownMenuItem(value: DateRangeFilter.custom, child: Text('Custom Date...')),
                    ],
                    onChanged: (filter) {
                      if (filter == DateRangeFilter.custom) {
                        _selectCustomDateRange();
                      } else if (filter != null) {
                        setState(() => _applyFilterDates(filter));
                        _loadReportData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. INTERACTIVE PDF VIEWER
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PdfPreview(
                      build: (format) => PdfReportService.generateReportBytes(
                        summary: _summary,
                        topDrivers: _topDrivers,
                        topPassengers: _topPassengers,
                        periodLabel: _getFilterLabel(),
                        startDate: _startDate,
                        endDate: _endDate,
                      ),
                      allowPrinting: true,
                      allowSharing: true,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      pdfFileName: 'FFL_Smart_Ride_Audit_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
                      loadingWidget: const Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
