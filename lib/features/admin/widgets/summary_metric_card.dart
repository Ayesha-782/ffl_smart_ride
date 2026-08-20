import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconBgColor;
  final Color? iconColor;
  final Gradient? gradient;

  const SummaryMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconBgColor,
    this.iconColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: gradient != null
                      ? Colors.white.withOpacity(0.85)
                      : AppColors.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gradient != null
                      ? Colors.white.withOpacity(0.2)
                      : (iconBgColor ?? AppColors.primaryLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: gradient != null
                      ? Colors.white
                      : (iconColor ?? AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: gradient != null ? Colors.white : AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: gradient != null
                    ? Colors.white.withOpacity(0.8)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: gradient == null
            ? Border.all(color: AppColors.border.withOpacity(0.7))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: cardContent,
    );
  }
}
