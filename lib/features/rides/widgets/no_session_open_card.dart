import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class NoSessionOpenCard extends StatelessWidget {
  final VoidCallback onRefresh;

  const NoSessionOpenCard({
    super.key,
    required this.onRefresh,
  });

  String _getNextSessionHint() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final currentMinutes = hour * 60 + minute;

    if (currentMinutes < 6 * 60 + 30) {
      return 'Next session: Morning Commute opens at 06:30 AM';
    } else if (currentMinutes < 13 * 60 + 30) {
      return 'Next session: Afternoon Shift opens at 01:30 PM';
    } else if (currentMinutes < 16 * 60 + 30) {
      return 'Next session: Evening Return opens at 04:30 PM';
    } else {
      return 'Next session: Morning Commute tomorrow at 06:30 AM';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, color: AppColors.textSecondary, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'SESSIONS SCHEDULED',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                tooltip: 'Check for Open Session',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'No Active Ride Session Right Now',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getNextSessionHint(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Daily Shift Commute Windows
          const Text(
            'Daily Commute Windows (Township ↔ Factory):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          _buildShiftRow(
            icon: Icons.wb_twilight,
            title: 'Morning Commute',
            time: '07:00 AM – 09:00 AM',
            color: const Color(0xFFE65100),
          ),
          const SizedBox(height: 8),
          _buildShiftRow(
            icon: Icons.wb_sunny,
            title: 'Lunch / Afternoon',
            time: '12:30 PM – 02:30 PM',
            color: const Color(0xFFF57C00),
          ),
          const SizedBox(height: 8),
          _buildShiftRow(
            icon: Icons.nights_stay,
            title: 'Evening Return',
            time: '04:30 PM – 05:30 PM',
            color: const Color(0xFF303F9F),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftRow({
    required IconData icon,
    required String title,
    required String time,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          time,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
