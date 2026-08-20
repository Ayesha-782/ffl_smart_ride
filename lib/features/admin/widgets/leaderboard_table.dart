import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/admin_repository.dart';

class LeaderboardTable extends StatelessWidget {
  final String title;
  final String roleBadge;
  final IconData icon;
  final List<LeaderboardEntry> entries;
  final bool isLoading;

  const LeaderboardTable({
    super.key,
    required this.title,
    required this.roleBadge,
    required this.icon,
    required this.entries,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$roleBadge contributions from audit log',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${entries.length} ranked',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 36, color: AppColors.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    const Text(
                      'No completed rides recorded yet',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final item = entries[index];
                final rank = index + 1;

                Color rankColor = AppColors.textMuted;
                Color rankBg = AppColors.surface;

                if (rank == 1) {
                  rankColor = const Color(0xFFD97706);
                  rankBg = const Color(0xFFFEF3C7);
                } else if (rank == 2) {
                  rankColor = const Color(0xFF475569);
                  rankBg = const Color(0xFFE2E8F0);
                } else if (rank == 3) {
                  rankColor = const Color(0xFFB45309);
                  rankBg = const Color(0xFFFFEDD5);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      // Rank Badge
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rankBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: rankColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.employeeId.isNotEmpty
                                  ? 'ID: ${item.employeeId} • ${item.email}'
                                  : item.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stats Pills
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.rideCount} rides',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.co2SavedKg.toStringAsFixed(1)} kg CO₂ | ${item.fuelSavedLiters.toStringAsFixed(1)} L',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
