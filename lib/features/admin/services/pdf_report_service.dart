import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/admin_repository.dart';

class PdfReportService {
  /// Generates a PDF document bytes for the sustainability and ride metrics report
  static Future<Uint8List> generateReportBytes({
    required AdminDashboardSummary summary,
    required List<LeaderboardEntry> topDrivers,
    required List<LeaderboardEntry> topPassengers,
    required String periodLabel,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#0D9488'); // Jade Teal
    final darkTeal = PdfColor.fromHex('#0F766E');
    final softBg = PdfColor.fromHex('#F2F8F6');
    final textDark = PdfColor.fromHex('#0F172A');
    final textMuted = PdfColor.fromHex('#64748B');
    final borderGray = PdfColor.fromHex('#E2E8F0');

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}'
        : 'All Time Records';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // 1. HEADER SECTION
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: softBg,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: borderGray),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FFL SMART RIDE',
                      style: pw.TextStyle(
                        color: darkTeal,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sustainability & Carpool Analytics Report',
                      style: pw.TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Scope: $periodLabel ($dateRangeStr)',
                      style: pw.TextStyle(color: textMuted, fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.Text(
                        'OFFICIAL AUDIT',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(color: textMuted, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // 2. EXECUTIVE SUMMARY CARDS GRID
          pw.Text(
            'Executive Sustainability Summary',
            style: pw.TextStyle(color: textDark, fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),

          pw.Row(
            children: [
              _buildSummaryCard(
                title: 'Total Completed Rides',
                value: summary.totalCompletedRides.toString(),
                subtitle: 'Verified Carpool Trips',
                accentColor: darkTeal,
              ),
              pw.SizedBox(width: 8),
              _buildSummaryCard(
                title: 'Total CO2 Saved',
                value: '${summary.totalCo2SavedKg.toStringAsFixed(1)} kg',
                subtitle: '(${summary.totalCo2SavedTons.toStringAsFixed(3)} Metric Tons)',
                accentColor: PdfColor.fromHex('#059669'),
              ),
              pw.SizedBox(width: 8),
              _buildSummaryCard(
                title: 'Total Fuel Saved',
                value: '${summary.totalFuelSavedLiters.toStringAsFixed(1)} L',
                subtitle: 'Est. Petrol Conserved',
                accentColor: PdfColor.fromHex('#D97706'),
              ),
              pw.SizedBox(width: 8),
              _buildSummaryCard(
                title: 'Active Employees',
                value: '${summary.activeUsers} / ${summary.totalRegisteredUsers}',
                subtitle: 'Registered Participants',
                accentColor: PdfColor.fromHex('#2563EB'),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // 3. TOP DRIVERS LEADERBOARD
          pw.Text(
            'Top Driver Contributors (Rides Given)',
            style: pw.TextStyle(color: textDark, fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildLeaderboardTable(
            entries: topDrivers,
            roleTitle: 'Driver',
            primaryColor: darkTeal,
          ),

          pw.SizedBox(height: 20),

          // 4. TOP PASSENGERS LEADERBOARD
          pw.Text(
            'Top Passenger Contributors (Rides Taken)',
            style: pw.TextStyle(color: textDark, fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildLeaderboardTable(
            entries: topPassengers,
            roleTitle: 'Passenger',
            primaryColor: primaryColor,
          ),

          pw.SizedBox(height: 24),

          // 5. FOOTER / CERTIFICATION
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderGray),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FFL Smart Ride Environmental Management System',
                  style: pw.TextStyle(color: textMuted, fontSize: 9),
                ),
                pw.Text(
                  'Verified from immutable audit logs (ride_completion_log)',
                  style: pw.TextStyle(color: textMuted, fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(color: PdfColor.fromHex('#64748B'), fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(color: accentColor, fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle,
              style: pw.TextStyle(color: PdfColor.fromHex('#94A3B8'), fontSize: 7),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildLeaderboardTable({
    required List<LeaderboardEntry> entries,
    required String roleTitle,
    required PdfColor primaryColor,
  }) {
    if (entries.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Center(
          child: pw.Text('No completed trips recorded in this period.',
              style: pw.TextStyle(color: PdfColor.fromHex('#94A3B8'), fontSize: 9)),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
          children: [
            _tableHeader('#', flex: 1),
            _tableHeader('Employee Name', flex: 4),
            _tableHeader('Employee ID', flex: 3),
            _tableHeader('Rides', flex: 2, alignRight: true),
            _tableHeader('CO2 Saved (kg)', flex: 3, alignRight: true),
            _tableHeader('Fuel Saved (L)', flex: 3, alignRight: true),
          ],
        ),
        // Rows
        ...entries.asMap().entries.map((item) {
          final index = item.key + 1;
          final e = item.value;
          return pw.TableRow(
            children: [
              _tableCell(index.toString(), flex: 1),
              _tableCell(e.name, flex: 4, isBold: true),
              _tableCell(e.employeeId.isNotEmpty ? e.employeeId : '-', flex: 3),
              _tableCell(e.rideCount.toString(), flex: 2, alignRight: true),
              _tableCell(e.co2SavedKg.toStringAsFixed(2), flex: 3, alignRight: true),
              _tableCell(e.fuelSavedLiters.toStringAsFixed(2), flex: 3, alignRight: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeader(String text, {int flex = 1, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#475569'),
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text, {int flex = 1, bool isBold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#0F172A'),
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Downloads or opens print preview directly
  static Future<void> downloadOrPrintReport({
    required AdminDashboardSummary summary,
    required List<LeaderboardEntry> topDrivers,
    required List<LeaderboardEntry> topPassengers,
    required String periodLabel,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdfBytes = await generateReportBytes(
      summary: summary,
      topDrivers: topDrivers,
      topPassengers: topPassengers,
      periodLabel: periodLabel,
      startDate: startDate,
      endDate: endDate,
    );

    final filename = 'FFL_Smart_Ride_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }
}
