import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/models/user_profile.dart';
import '../data/admin_repository.dart';
import 'admin_management_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_report_screen.dart';
import 'user_management_screen.dart';

class AdminDashboardShell extends StatefulWidget {
  final UserProfile userProfile;
  final AdminRepository? adminRepository;

  const AdminDashboardShell({
    super.key,
    required this.userProfile,
    this.adminRepository,
  });

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  late final AdminRepository _adminRepository;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _adminRepository = widget.adminRepository ?? AdminRepository();
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of the Admin Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.userProfile.isSuperAdmin;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    // Navigation items
    final navItems = <_NavItem>[
      const _NavItem(title: 'Overview & Analytics', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
      const _NavItem(title: 'User Management', icon: Icons.people_outline, activeIcon: Icons.people),
      if (isSuperAdmin)
        const _NavItem(title: 'Admin Access', icon: Icons.security_outlined, activeIcon: Icons.security),
      const _NavItem(title: 'Reports & Export', icon: Icons.description_outlined, activeIcon: Icons.description),
    ];

    // Gated screens
    final screens = <Widget>[
      AdminOverviewScreen(
        adminRepository: _adminRepository,
        onNavigateToReports: () {
          final reportsIdx = isSuperAdmin ? 3 : 2;
          setState(() => _selectedIndex = reportsIdx);
        },
      ),
      UserManagementScreen(
        adminRepository: _adminRepository,
        currentUserProfile: widget.userProfile,
      ),
      if (isSuperAdmin)
        AdminManagementScreen(
          adminRepository: _adminRepository,
          currentUserProfile: widget.userProfile,
        ),
      AdminReportScreen(
        adminRepository: _adminRepository,
      ),
    ];

    final clampedIndex = _selectedIndex.clamp(0, screens.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildTopAppBar(isDesktop),
      body: isDesktop
          ? Row(
              children: [
                _buildSidebar(navItems, clampedIndex),
                Expanded(
                  child: screens[clampedIndex],
                ),
              ],
            )
          : screens[clampedIndex],
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: clampedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              backgroundColor: Colors.white,
              indicatorColor: AppColors.primaryLight,
              destinations: navItems
                  .map((item) => NavigationDestination(
                        icon: Icon(item.icon, color: AppColors.textSecondary),
                        selectedIcon: Icon(item.activeIcon, color: AppColors.primary),
                        label: item.title,
                      ))
                  .toList(),
            ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(bool isDesktop) {
    final isSuper = widget.userProfile.isSuperAdmin;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.electric_car, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FFL SMART RIDE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'ADMINISTRATION PORTAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Role Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSuper ? const Color(0xFFF3E8FF) : const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSuper ? const Color(0xFFD8B4FE) : const Color(0xFFBAE6FD),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuper ? Icons.workspace_premium : Icons.shield,
                size: 14,
                color: isSuper ? const Color(0xFF7E22CE) : const Color(0xFF0369A1),
              ),
              const SizedBox(width: 4),
              Text(
                isSuper ? 'Super Admin' : 'Admin',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSuper ? const Color(0xFF7E22CE) : const Color(0xFF0369A1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Admin User Info
        if (isDesktop) ...[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.userProfile.fullName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                widget.userProfile.email ?? '',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],

        // Sign Out Button
        IconButton(
          tooltip: 'Sign Out of Admin Portal',
          icon: const Icon(Icons.logout, color: AppColors.textMuted, size: 20),
          onPressed: _handleSignOut,
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSidebar(List<_NavItem> navItems, int activeIndex) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = index == activeIndex;

                return InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: 20,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FFL ESG Certified',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Zero-Emission Initiative',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
  });
}
