import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _users = [];
  List<dynamic> _sessions = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchCurrentTabData();
      }
    });
    _fetchCurrentTabData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentTabData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_tabController.index == 0) {
        final list = await ApiService.getAdminUsers();
        if (mounted) setState(() => _users = list);
      } else {
        final list = await ApiService.getAdminSessions();
        if (mounted) setState(() => _sessions = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 22),
            ),
            const SizedBox(width: 14),
            const Text('Delete Employee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete user "${user['username']}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteAdminUser(user['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee "${user['username']}" deleted'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _forceLogout(dynamic session) async {
    final username = session['user']?['username'] ?? 'User';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 22),
            ),
            const SizedBox(width: 14),
            const Text('Revoke Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          'Force logout $username? Their active session will be invalidated immediately.',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Force Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.revokeAdminSession(session['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session revoked. User logged out.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchCurrentTabData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openUserDialog([dynamic user]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserModal(
        user: user,
        onSaved: () => _fetchCurrentTabData(),
      ),
    );
  }

  Future<void> _downloadBackup() async {
    final url = ApiService.getAdminBackupUrl();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open backup download link'),
            backgroundColor: Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = monthNames[dt.month - 1];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month, $hour:$minute';
    } catch (_) {
      return raw.toString();
    }
  }

  bool _isOnlineNow(dynamic raw) {
    if (raw == null) return false;
    try {
      final dt = DateTime.parse(raw.toString());
      return DateTime.now().toUtc().difference(dt.toUtc()).inMinutes < 5;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int totalAdmins = 0;
    int totalWorkers = 0;
    for (var u in _users) {
      final role = (u['role'] ?? '').toString().toLowerCase();
      if (role == 'admin') {
        totalAdmins++;
      } else {
        totalWorkers++;
      }
    }

    int onlineSessionsCount = 0;
    for (var s in _sessions) {
      if (_isOnlineNow(s['lastActive'])) onlineSessionsCount++;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern Midnight Slate Cockpit
            _buildCockpitHeader(),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error banner if any
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFBE123C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFFBE123C)),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Metrics Overview Grid
                      _buildMetricsGrid(totalAdmins, totalWorkers, onlineSessionsCount),
                      const SizedBox(height: 20),

                      // Navigation Tabs and Search Filter Bar
                      _buildTabBarAndControls(isDark),
                      const SizedBox(height: 16),

                      // Main Container with Table
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(60),
                                child: Center(
                                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                                ),
                              )
                            : _tabController.index == 0
                                ? _buildUsersTable(isDark)
                                : _buildSessionsTable(isDark),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCockpitHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Admin & Security Console',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, size: 12, color: Color(0xFFA5B4FC)),
                                SizedBox(width: 4),
                                Text(
                                  'RBAC & ACCESS CONTROL',
                                  style: TextStyle(
                                    color: Color(0xFFA5B4FC),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Manage staff credentials, PIN codes, granular permissions, branch routing, and active 24h user sessions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _downloadBackup,
                      icon: const Icon(Icons.cloud_download_rounded, size: 18),
                      label: const Text('Export Backup (.xlsx)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF34D399),
                        side: const BorderSide(color: Color(0xFF059669)),
                        backgroundColor: const Color(0xFF059669).withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openUserDialog(),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(int totalAdmins, int totalWorkers, int onlineSessionsCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        final metrics = [
          {
            'label': 'Total Staff',
            'value': '${_users.length}',
            'sub': 'Registered Accounts',
            'icon': Icons.people_alt_rounded,
            'color': const Color(0xFF6366F1),
            'bg': const Color(0xFFEEF2FF),
            'border': const Color(0xFFC7D2FE),
          },
          {
            'label': 'Administrators',
            'value': '$totalAdmins',
            'sub': 'Full System Access',
            'icon': Icons.admin_panel_settings_rounded,
            'color': const Color(0xFF0284C7),
            'bg': const Color(0xFFF0F9FF),
            'border': const Color(0xFFBAE6FD),
          },
          {
            'label': 'Operations Staff',
            'value': '$totalWorkers',
            'sub': 'Standard Operators',
            'icon': Icons.badge_rounded,
            'color': const Color(0xFFF59E0B),
            'bg': const Color(0xFFFFFBEB),
            'border': const Color(0xFFFDE68A),
          },
          {
            'label': 'Online Now',
            'value': '$onlineSessionsCount',
            'sub': 'Active In 5 Mins',
            'icon': Icons.sensors_rounded,
            'color': const Color(0xFF10B981),
            'bg': const Color(0xFFECFDF5),
            'border': const Color(0xFFA7F3D0),
          },
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((m) {
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m['bg'] as Color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: m['border'] as Color),
                        ),
                        child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          m['sub'] as String,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    m['value'] as String,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m['label'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTabBarAndControls(bool isDark) {
    return Row(
      children: [
        // Tab selector pills
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildTabPill(0, Icons.people_alt_rounded, 'Staff Directory (${_users.length})'),
              _buildTabPill(1, Icons.sensors_rounded, 'Active Sessions (${_sessions.length})'),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _tabController.index == 0 ? 'Search staff by name or branch...' : 'Search active user sessions...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _fetchCurrentTabData,
          icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
          tooltip: 'Refresh data',
          style: IconButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.all(11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabPill(int index, IconData icon, String label) {
    final isSelected = _tabController.index == index;
    return InkWell(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTable(bool isDark) {
    final filtered = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final name = (u['username'] ?? '').toString().toLowerCase();
      final branch = (u['branch'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || branch.contains(_searchQuery) || role.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty ? 'No employees found in directory.' : 'No employees matching "$_searchQuery"',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 20,
        columnSpacing: 28,
        headingRowHeight: 48,
        dataRowMinHeight: 58,
        dataRowMaxHeight: 68,
        headingTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
        columns: const [
          DataColumn(label: Text('EMPLOYEE')),
          DataColumn(label: Text('ROLE & BRANCH')),
          DataColumn(label: Text('PERMISSIONS')),
          DataColumn(label: Text('PIN CODE')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('ACTIONS', textAlign: TextAlign.right)),
        ],
        rows: filtered.asMap().entries.map((entry) {
          final idx = entry.key;
          final user = entry.value as Map<String, dynamic>;
          final role = (user['role']?.toString() ?? 'worker').toLowerCase();
          final branch = user['branch']?.toString() ?? 'MAIN';
          final status = user['status']?.toString() ?? 'Active';
          final isActive = status.toLowerCase() == 'active';
          final perms = user['permissions'] as Map<String, dynamic>?;

          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.hovered)) {
                return isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC);
              }
              return idx.isEven
                  ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                  : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFFAFAFA));
            }),
            cells: [
              // Employee Name & Avatar
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: role == 'admin'
                              ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                              : [const Color(0xFF0284C7), const Color(0xFF0369A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          (user['username'] ?? 'U').toString().isNotEmpty ? user['username'][0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      user['username']?.toString() ?? '-',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              // Role & Branch
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: role == 'admin' ? const Color(0xFFEEF2FF) : const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: role == 'admin' ? const Color(0xFFC7D2FE) : const Color(0xFFBAE6FD),
                        ),
                      ),
                      child: Text(
                        role == 'admin' ? 'ADMINISTRATOR' : 'WORKER / OPERATOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: role == 'admin' ? const Color(0xFF4338CA) : const Color(0xFF0284C7),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        branch,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Permissions
              DataCell(
                role == 'admin'
                    ? const Text('Full Superuser', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)))
                    : Wrap(
                        spacing: 4,
                        children: [
                          if (perms?['create'] == true) _buildPermBadge('Create', const Color(0xFF059669)),
                          if (perms?['edit'] == true) _buildPermBadge('Edit', const Color(0xFF0284C7)),
                          if (perms?['delete'] == true) _buildPermBadge('Delete', const Color(0xFFE11D48)),
                          if (perms?['reports'] == true) _buildPermBadge('Reports', const Color(0xFFD97706)),
                        ],
                      ),
              ),

              // PIN Code
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    '••••',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),

              // Status
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: isActive ? const Color(0xFF10B981) : const Color(0xFFE11D48)),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isActive ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: const Color(0xFF6366F1),
                      tooltip: 'Edit employee',
                      onPressed: () => _openUserDialog(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: const Color(0xFFE11D48),
                      tooltip: 'Delete employee',
                      onPressed: () => _deleteUser(user),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPermBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildSessionsTable(bool isDark) {
    final filtered = _sessions.where((s) {
      if (_searchQuery.isEmpty) return true;
      final user = s['user'] ?? {};
      final name = (user['username'] ?? '').toString().toLowerCase();
      final branch = (user['branch'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || branch.contains(_searchQuery) || role.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sensors_off_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty ? 'No active user sessions recorded in the last 24 hours.' : 'No sessions matching "$_searchQuery"',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 20,
        columnSpacing: 32,
        headingRowHeight: 48,
        dataRowMinHeight: 58,
        dataRowMaxHeight: 68,
        headingTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
        columns: const [
          DataColumn(label: Text('USER & IDENTITY')),
          DataColumn(label: Text('BRANCH')),
          DataColumn(label: Text('LOGIN TIME')),
          DataColumn(label: Text('LAST ACTIVITY')),
          DataColumn(label: Text('SESSION CONTROL', textAlign: TextAlign.right)),
        ],
        rows: filtered.asMap().entries.map((entry) {
          final idx = entry.key;
          final session = entry.value as Map<String, dynamic>;
          final user = session['user'] ?? {};
          final isOnline = _isOnlineNow(session['lastActive']);

          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.hovered)) {
                return isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC);
              }
              return idx.isEven
                  ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                  : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFFAFAFA));
            }),
            cells: [
              // User
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: isOnline ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['username']?.toString() ?? 'User',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          (user['role'] ?? 'worker').toString().toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Branch
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    user['branch']?.toString() ?? 'MAIN',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ),

              // Login Time
              DataCell(
                Text(
                  _formatDateTime(session['loginTime']),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                ),
              ),

              // Last Activity
              DataCell(
                isOnline
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Text(
                              'Active Now',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        _formatDateTime(session['lastActive']),
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF64748B)),
                      ),
              ),

              // Force Logout
              DataCell(
                ElevatedButton.icon(
                  onPressed: () => _forceLogout(session),
                  icon: const Icon(Icons.logout_rounded, size: 14),
                  label: const Text('Revoke Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F2),
                    foregroundColor: const Color(0xFFE11D48),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _UserModal extends StatefulWidget {
  final dynamic user;
  final VoidCallback onSaved;

  const _UserModal({this.user, required this.onSaved});

  @override
  State<_UserModal> createState() => _UserModalState();
}

class _UserModalState extends State<_UserModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _pinController;
  late String _role;
  late String _branch;
  late String _status;

  bool _permCreate = true;
  bool _permEdit = false;
  bool _permDelete = false;
  bool _permReports = false;

  bool _isSaving = false;
  String? _dialogError;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _usernameController = TextEditingController(text: u?['username'] ?? '');
    _pinController = TextEditingController(text: '');
    _role = u?['role']?.toString().toLowerCase() == 'admin' ? 'admin' : 'worker';
    _branch = u?['branch'] ?? 'MAIN';
    _status = u?['status'] ?? 'Active';

    final perms = u?['permissions'] as Map<String, dynamic>?;
    if (perms != null) {
      _permCreate = perms['create'] == true;
      _permEdit = perms['edit'] == true;
      _permDelete = perms['delete'] == true;
      _permReports = perms['reports'] == true;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.user == null && _pinController.text.length != 4) {
      setState(() => _dialogError = 'PIN must be exactly 4 digits');
      return;
    }

    setState(() {
      _isSaving = true;
      _dialogError = null;
    });

    final payload = {
      'username': _usernameController.text.trim(),
      'role': _role,
      'branch': _branch,
      'status': _status,
      'permissions': {
        'create': _permCreate,
        'edit': _permEdit,
        'delete': _permDelete,
        'reports': _permReports,
      },
    };

    if (_pinController.text.trim().isNotEmpty) {
      payload['pin'] = _pinController.text.trim();
    }

    try {
      await ApiService.saveAdminUser(payload, id: widget.user?['id']);
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.user != null ? 'Employee updated successfully' : 'Employee created successfully'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dialogError = e.toString().replaceAll('Exception:', '').trim();
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.user != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_outline_rounded, color: Color(0xFF4F46E5), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            isEditing ? 'Edit Employee Credentials' : 'Add New Staff Employee',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: const Color(0xFF94A3B8),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 28, thickness: 1, color: Color(0xFFF1F5F9)),

                  if (_dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Text(_dialogError!, style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Username
                  const Text('EMPLOYEE USERNAME / FULL NAME *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameController,
                    decoration: _inputDecoration(isDark, hint: 'e.g. Ramesh Kumar'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Username required' : null,
                  ),
                  const SizedBox(height: 16),

                  // 4-Digit PIN
                  Text(
                    isEditing ? '4-DIGIT PIN CODE (LEAVE EMPTY TO KEEP CURRENT)' : '4-DIGIT PIN CODE *',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: _inputDecoration(isDark, hint: '••••'),
                    style: const TextStyle(fontSize: 16, fontFamily: 'monospace', letterSpacing: 6, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // Role & Branch
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SECURITY ROLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _role,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              decoration: _inputDecoration(isDark),
                              items: const [
                                DropdownMenuItem(value: 'worker', child: Text('Worker / Operator', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'admin', child: Text('Administrator', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _role = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('BRANCH ROUTING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _branch,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              decoration: _inputDecoration(isDark),
                              items: const [
                                DropdownMenuItem(value: 'MAIN', child: Text('Main Branch', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'AP_BNG', child: Text('AP BNG', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'ALL', child: Text('All Branches', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _branch = v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Permissions Checkboxes (For Workers)
                  if (_role == 'worker') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GRANULAR WORKER PERMISSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Create GCs/GDMs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  value: _permCreate,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (v) => setState(() => _permCreate = v ?? false),
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Edit Records', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  value: _permEdit,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (v) => setState(() => _permEdit = v ?? false),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Delete Records', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                                  value: _permDelete,
                                  activeColor: const Color(0xFFE11D48),
                                  onChanged: (v) => setState(() => _permDelete = v ?? false),
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Export Reports', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  value: _permReports,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (v) => setState(() => _permReports = v ?? false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Account Status (when editing)
                  if (isEditing) ...[
                    const Text('ACCOUNT STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _status,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      decoration: _inputDecoration(isDark),
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('Active (Can Login)', style: TextStyle(fontSize: 13, color: Color(0xFF059669), fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Suspended', child: Text('Suspended (Locked Out)', style: TextStyle(fontSize: 13, color: Color(0xFFE11D48), fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Save & Cancel Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(isEditing ? 'Save Changes' : 'Create Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }
}
