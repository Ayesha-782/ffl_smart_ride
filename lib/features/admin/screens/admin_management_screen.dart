import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_profile.dart';
import '../data/admin_repository.dart';

class AdminManagementScreen extends StatefulWidget {
  final AdminRepository adminRepository;
  final UserProfile currentUserProfile;

  const AdminManagementScreen({
    super.key,
    required this.adminRepository,
    required this.currentUserProfile,
  });

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  bool _isLoading = true;
  List<UserProfile> _allUsers = [];
  List<UserProfile> _adminUsers = [];
  List<UserProfile> _regularUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.adminRepository.fetchAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = list;
          _adminUsers = list.where((u) => u.isAdmin).toList();
          _regularUsers = list.where((u) => !u.isAdmin && u.isActive).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openPromoteAdminDialog() {
    UserProfile? selectedUser;
    String search = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredCandidates = _regularUsers.where((u) {
            if (search.isEmpty) return true;
            return u.fullName.toLowerCase().contains(search.toLowerCase()) ||
                (u.email?.toLowerCase().contains(search.toLowerCase()) ?? false) ||
                u.employeeId.toLowerCase().contains(search.toLowerCase());
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Promote Employee to Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select an active employee to grant Admin permissions. Admins can view analytics and pre-register employees.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search candidate employees...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => setDialogState(() => search = val),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: filteredCandidates.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No eligible active users found')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredCandidates.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final u = filteredCandidates[index];
                              final isSelected = selectedUser?.id == u.id;

                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: AppColors.primaryLight,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('ID: ${u.employeeId} • ${u.email}'),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                                    : null,
                                onTap: () => setDialogState(() => selectedUser = u),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: selectedUser == null
                    ? null
                    : () async {
                        Navigator.of(ctx).pop();
                        await _promoteUser(selectedUser!);
                      },
                child: const Text('Promote to Admin'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _promoteUser(UserProfile user) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Promoting ${user.fullName} to admin...')),
      );

      await widget.adminRepository.addAdmin(user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('${user.fullName} is now an Admin!'),
          ),
        );
        _loadAdmins();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to promote user: $e'),
          ),
        );
      }
    }
  }

  Future<void> _demoteAdmin(UserProfile user) async {
    if (user.role == 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('Super Admin accounts cannot be demoted directly.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Demote Admin to Regular User?'),
        content: Text(
          'Are you sure you want to revoke Admin privileges for ${user.fullName} (${user.email})? They will revert back to standard employee permissions.',
          style: const TextStyle(fontSize: 14),
        ),
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
            child: const Text('Demote to User'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demoting ${user.fullName}...')),
      );

      await widget.adminRepository.removeAdmin(user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('${user.fullName} has been reverted to regular employee role.'),
          ),
        );
        _loadAdmins();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to demote admin: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Admin Access Control',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SUPER ADMIN EXCLUSIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7E22CE),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Promote registered employees to Administrators and manage role hierarchies',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _openPromoteAdminDialog,
                icon: const Icon(Icons.security, size: 18),
                label: const Text(
                  'Promote New Admin',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 2. ADMIN LIST TABLE
          _buildAdminListCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAdminListCard() {
    if (_isLoading) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

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
                Text(
                  '${_adminUsers.length} Active System Administrators',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Hardened Server-Side RLS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _adminUsers.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: Color(0xFFF1F5F9),
            ),
            itemBuilder: (context, index) {
              final admin = _adminUsers[index];
              final isSelf = admin.id == widget.currentUserProfile.id;
              final isSuperAdmin = admin.role == 'super_admin';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSuperAdmin ? const Color(0xFFF3E8FF) : const Color(0xFFE0F2FE),
                      child: Icon(
                        isSuperAdmin ? Icons.workspace_premium : Icons.admin_panel_settings,
                        size: 20,
                        color: isSuperAdmin ? const Color(0xFF7E22CE) : const Color(0xFF0369A1),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Admin Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                admin.fullName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${admin.employeeId} • ${admin.email}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),

                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSuperAdmin ? const Color(0xFFF3E8FF) : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isSuperAdmin ? 'Super Admin' : 'Admin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSuperAdmin ? const Color(0xFF7E22CE) : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Demote Action Button
                    if (!isSelf && !isSuperAdmin) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () => _demoteAdmin(admin),
                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                        label: const Text('Demote', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ] else ...[
                      const SizedBox(width: 80),
                    ],
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
