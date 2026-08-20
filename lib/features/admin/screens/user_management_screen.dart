import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_profile.dart';
import '../data/admin_repository.dart';
import '../widgets/add_user_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  final AdminRepository adminRepository;
  final UserProfile currentUserProfile;

  const UserManagementScreen({
    super.key,
    required this.adminRepository,
    required this.currentUserProfile,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _roleFilter = 'all';
  bool? _activeFilter;

  bool _isLoading = true;
  List<UserProfile> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.adminRepository.fetchAllUsers(
        searchQuery: _searchController.text.trim(),
        roleFilter: _roleFilter,
        activeFilter: _activeFilter,
      );
      if (mounted) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openAddUserModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddUserDialog(
        adminRepository: widget.adminRepository,
        onUserAdded: _loadUsers,
      ),
    );
  }

  Future<void> _toggleUserStatus(UserProfile user) async {
    final isDeactivating = user.isActive;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(isDeactivating ? 'Deactivate Employee?' : 'Reactivate Employee?'),
        content: Text(
          isDeactivating
              ? 'Are you sure you want to deactivate ${user.fullName} (${user.email})? They will be barred from signing in, but their historical ride records and CO₂ contributions will remain permanently preserved.'
              : 'Restore platform login access for ${user.fullName}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDeactivating ? AppColors.error : AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isDeactivating ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.adminRepository.removeUser(
        user.id,
        deactivate: isDeactivating,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isDeactivating ? AppColors.error : AppColors.success,
            content: Text(
              isDeactivating
                  ? '${user.fullName} has been deactivated. Historical ride logs preserved.'
                  : '${user.fullName} reactivated successfully.',
            ),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update status: $e'),
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
          // 1. TOOLBAR & HEADER
          _buildHeader(),
          const SizedBox(height: 20),

          // 2. SEARCH & FILTER BAR
          _buildSearchAndFilters(),
          const SizedBox(height: 20),

          // 3. USER TABLE / LIST
          _buildUsersTable(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
              'Employee User Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage registered employees, pre-register staff, and monitor active statuses',
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
          onPressed: _openAddUserModal,
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text(
            'Pre-Register Employee',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by employee name, email, employee ID, or CNIC...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadUsers();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onSubmitted: (_) => _loadUsers(),
                  onChanged: (val) {
                    if (val.isEmpty) _loadUsers();
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loadUsers,
                child: const Text('Search', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Filter Role: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              _buildFilterChip('All Roles', 'all', _roleFilter == 'all', (s) {
                setState(() => _roleFilter = s);
                _loadUsers();
              }),
              const SizedBox(width: 6),
              _buildFilterChip('Employees (Users)', 'user', _roleFilter == 'user', (s) {
                setState(() => _roleFilter = s);
                _loadUsers();
              }),
              const SizedBox(width: 6),
              _buildFilterChip('Admins', 'admin', _roleFilter == 'admin', (s) {
                setState(() => _roleFilter = s);
                _loadUsers();
              }),
              const Spacer(),
              const Text(
                'Status: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('All', style: TextStyle(fontSize: 12)),
                selected: _activeFilter == null,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _activeFilter = null);
                    _loadUsers();
                  }
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Active', style: TextStyle(fontSize: 12)),
                selected: _activeFilter == true,
                onSelected: (sel) {
                  setState(() => _activeFilter = sel ? true : null);
                  _loadUsers();
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Deactivated', style: TextStyle(fontSize: 12)),
                selected: _activeFilter == false,
                onSelected: (sel) {
                  setState(() => _activeFilter = sel ? false : null);
                  _loadUsers();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected, Function(String) onSelected) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (sel) {
        if (sel) onSelected(value);
      },
    );
  }

  Widget _buildUsersTable() {
    if (_isLoading) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.7)),
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'No employees match your search criteria',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Try changing search keywords or active status filters.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
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
                  '${_users.length} Employees Found',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  'Showing latest registrations first',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: Color(0xFFF1F5F9),
            ),
            itemBuilder: (context, index) {
              final u = _users[index];
              final isSelf = u.id == widget.currentUserProfile.id;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar / Initials
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: u.isActive
                          ? (u.hasVehicle ? AppColors.primaryLight : AppColors.surface)
                          : const Color(0xFFF1F5F9),
                      child: Text(
                        u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: u.isActive
                              ? (u.hasVehicle ? AppColors.primary : AppColors.textPrimary)
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // User Details
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                u.fullName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: u.isActive ? AppColors.textPrimary : AppColors.textMuted,
                                ),
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
                            'ID: ${u.employeeId} • ${u.email ?? "No Email"}${u.phone != null ? " • ${u.phone}" : ""}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          if (u.homeAddress != null && u.homeAddress!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '📍 ${u.homeAddress}',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted.withOpacity(0.8)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Vehicle Pill
                    Expanded(
                      flex: 2,
                      child: u.hasVehicle && u.vehicle != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.directions_car, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${u.vehicle!.make} ${u.vehicle!.model}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${u.vehicle!.licensePlate} • ${u.vehicle!.capacity} seats',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            )
                          : const Text(
                              'Commuter (Passenger)',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                    ),

                    // Role Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleBgColor(u.role),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getRoleLabel(u.role),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getRoleTextColor(u.role),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Active Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: u.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: u.isActive ? AppColors.success : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            u.isActive ? 'Active' : 'Disabled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: u.isActive ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Deactivate / Reactivate Action
                    if (!isSelf && !(widget.currentUserProfile.role == 'admin' && u.isAdmin)) ...[
                      IconButton(
                        tooltip: u.isActive ? 'Deactivate Employee' : 'Reactivate Employee',
                        icon: Icon(
                          u.isActive ? Icons.block : Icons.replay,
                          color: u.isActive ? AppColors.error : AppColors.success,
                          size: 20,
                        ),
                        onPressed: () => _toggleUserStatus(u),
                      ),
                    ] else ...[
                      const SizedBox(width: 48),
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

  String _getRoleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      default:
        return 'Employee';
    }
  }

  Color _getRoleBgColor(String role) {
    switch (role) {
      case 'super_admin':
        return const Color(0xFFF3E8FF);
      case 'admin':
        return const Color(0xFFE0F2FE);
      default:
        return AppColors.surface;
    }
  }

  Color _getRoleTextColor(String role) {
    switch (role) {
      case 'super_admin':
        return const Color(0xFF7E22CE);
      case 'admin':
        return const Color(0xFF0369A1);
      default:
        return AppColors.textSecondary;
    }
  }
}
