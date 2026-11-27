import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'gc_entry_screen.dart';
import 'gc_list_screen.dart';
import 'vehicle_master_screen.dart';
import 'driver_master_screen.dart';
import 'login_screen.dart';
import 'gdm_entry_screen.dart';
import 'warehouse_entry_screen.dart';
import 'trip_settlement_screen.dart';
import 'lorry_hire_screen.dart';
import 'lorry_accounts_screen.dart';
import 'party_accounts_screen.dart';
import 'daily_accounts_screen.dart';
import 'party_master_screen.dart';
import 'godown_master_screen.dart';
import 'hsn_master_screen.dart';
import 'govt_compliance_screen.dart';
import 'print_hub_screen.dart';
import 'reports_screen.dart';
import 'home_dashboard_screen.dart';
import 'freight_entry_screen.dart';
import 'warehouse_statement_screen.dart';
import 'company_master_screen.dart';
import 'unit_master_screen.dart';
import 'retail_gc_entry_screen.dart';
import 'admin_dashboard_screen.dart';
import 'audit_logs_screen.dart';
import 'technology_usage_screen.dart';
import 'godown_planner_screen.dart';
import 'legacy_rapid_entry_screen.dart';
import 'legacy_viewer_screen.dart';
import 'remote_scanner_screen.dart';
import '../services/update_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _activeScreenIndex = 18; // Default to Home Dashboard
  final Set<int> _loadedIndices = {18}; // Lazy-mount screens only when visited
  int _branchReloadEpoch = 0;
  Timer? _inactivityTimer;
  DateTime? _lastActivityReset;
  static const Duration _inactivityTimeout = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
    ApiService.onUnauthorized = _handleSessionExpired;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    if (ApiService.onUnauthorized == _handleSessionExpired) {
      ApiService.onUnauthorized = null;
    }
    super.dispose();
  }

  void _resetInactivityTimer({bool throttle = false}) {
    final now = DateTime.now();
    if (throttle &&
        _lastActivityReset != null &&
        now.difference(_lastActivityReset!) < const Duration(seconds: 5)) {
      return;
    }
    _lastActivityReset = now;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _handleInactivityLogout);
  }

  Future<void> _handleInactivityLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Logged out due to 30 minutes of inactivity.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleSessionExpired() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please sign in again.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _navigateToIndex(int index) {
    setState(() {
      _activeScreenIndex = index;
      _loadedIndices.add(index);
    });
  }

  Future<void> _showBranchSwitcher() async {
    if (!AuthService.isAdmin) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Switch Active Branch'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: AuthService.activeBranch == 'MAIN' ? const Color(0xFFEFF6FF) : null,
              leading: const Icon(Icons.business_rounded, color: Color(0xFF2563EB)),
              title: const Text('MAIN BRANCH (Sivakasi)', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: AuthService.activeBranch == 'MAIN'
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB))
                  : null,
              onTap: () => Navigator.of(ctx).pop('MAIN'),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              tileColor: AuthService.activeBranch == 'AP_BNG' ? const Color(0xFFEFF6FF) : null,
              leading: const Icon(Icons.location_city_rounded, color: Color(0xFF10B981)),
              title: const Text('AP BANGALORE (AP_BNG)', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: AuthService.activeBranch == 'AP_BNG'
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                  : null,
              onTap: () => Navigator.of(ctx).pop('AP_BNG'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && selected != AuthService.activeBranch) {
      await AuthService.setActiveBranch(selected);
      if (mounted) {
        setState(() {
          _loadedIndices
            ..clear()
            ..add(_activeScreenIndex);
          _branchReloadEpoch++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched active branch to $selected'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getAllScreens() {
    return [
      {'title': 'New GC Billing', 'screen': const GcEntryScreen()},           // 0
      {'title': 'Warehouse Inward', 'screen': const WarehouseEntryScreen()},  // 1
      {'title': 'GDM Manifest', 'screen': const GdmEntryScreen()},            // 2
      {'title': 'Trip Settlement', 'screen': const TripSettlementScreen()},   // 3
      {'title': 'Lorry Hire', 'screen': const LorryHireScreen()},             // 4
      {'title': 'Lorry Accounts', 'screen': const LorryAccountsScreen()},     // 5
      {'title': 'Party Accounts', 'screen': const PartyAccountsScreen()},     // 6
      {'title': 'Daily Cashbook', 'screen': const DailyAccountsScreen()},     // 7
      {'title': 'Vehicles', 'screen': const VehicleMasterScreen()},           // 8
      {'title': 'GC Register', 'screen': const GcListScreen()},               // 9
      {'title': 'Consignors', 'screen': const PartyMasterScreen(endpoint: 'consignors', title: 'Consignor')}, // 10
      {'title': 'Consignees', 'screen': const PartyMasterScreen(endpoint: 'consignees', title: 'Consignee')}, // 11
      {'title': 'Drivers', 'screen': const DriverMasterScreen()},             // 12
      {'title': 'Godowns', 'screen': const GodownMasterScreen()},             // 13
      {'title': 'HSN Master', 'screen': const HSNMasterScreen()},             // 14
      {'title': 'Govt Compliance', 'screen': const GovtComplianceScreen()},   // 15
      {'title': 'Print Hub', 'screen': const PrintHubScreen()},               // 16
      {'title': 'Reports & BI', 'screen': const ReportsScreen()},             // 17
      {
        'title': 'Home',
        'screen': HomeDashboardScreen(
          onNavigate: (index) {
            _navigateToIndex(index);
          },
        )
      },                                                                      // 18
      {'title': 'Freight Entry', 'screen': const FreightEntryScreen()},       // 19
      {'title': 'Warehouse Statement', 'screen': const WarehouseStatementScreen()}, // 20
      {'title': 'Company Master', 'screen': const CompanyMasterScreen()},     // 21
      {'title': 'Unit Master', 'screen': const UnitMasterScreen()},           // 22
      {'title': 'Retail Quick Bill', 'screen': const RetailGcEntryScreen()},  // 23
      {'title': 'Admin Controls', 'screen': const AdminDashboardScreen()},    // 24
      {'title': 'Audit Trails', 'screen': const AuditLogsScreen()},           // 25
      {'title': 'Tech Usage', 'screen': const TechnologyUsageScreen()},       // 26
      {'title': 'Godown Planner AI', 'screen': const GodownPlannerScreen()},  // 27
      {'title': 'Legacy Rapid Entry', 'screen': const LegacyRapidEntryScreen()}, // 28
      {'title': 'Legacy MDB Viewer', 'screen': const LegacyViewerScreen()},   // 29
      {'title': 'Remote Scanner', 'screen': const RemoteScannerScreen()},     // 30
    ];
  }

  String _getActiveScreenTitle() {
    final screens = _getAllScreens();
    if (_activeScreenIndex >= 0 && _activeScreenIndex < screens.length) {
      return screens[_activeScreenIndex]['title'] as String;
    }
    return 'Dashboard';
  }

  final Map<String, List<Map<String, dynamic>>> _menus = {
    'Operations': [
      {
        'title': 'New GC Billing',
        'desc': 'Create Consignment Note (Bilty)',
        'index': 0,
        'icon': Icons.note_add_rounded,
      },
      {
        'title': 'GC Register',
        'desc': 'Lookup, filter & search GCs',
        'index': 9,
        'icon': Icons.search_rounded,
      },
      {
        'title': 'Retail Quick Bill',
        'desc': 'Walk-in parcel fast billing',
        'index': 23,
        'icon': Icons.flash_on_rounded,
      },
      {
        'title': 'GDM Manifest',
        'desc': 'Lorry loading & despatch',
        'index': 2,
        'icon': Icons.local_shipping_outlined,
      },
      {
        'title': 'Trip Settlement',
        'desc': 'Driver advance & reconciliation',
        'index': 3,
        'icon': Icons.account_balance_wallet_outlined,
      },
      {
        'title': 'Freight Entry',
        'desc': 'Rate calculation & adjustments',
        'index': 19,
        'icon': Icons.currency_rupee_rounded,
      },
      {
        'title': 'Lorry Hire',
        'desc': 'Market truck contracts',
        'index': 4,
        'icon': Icons.handshake_outlined,
      },
    ],
    'Warehouse': [
      {
        'title': 'Warehouse Inward',
        'desc': 'Barcode verification & inward',
        'index': 1,
        'icon': Icons.qr_code_scanner_rounded,
      },
      {
        'title': 'Warehouse Statement',
        'desc': 'Daily stock audit sheet',
        'index': 20,
        'icon': Icons.inventory_2_outlined,
      },
      {
        'title': 'Godown Planner AI',
        'desc': 'Voice assistant (தமிழ்/Eng)',
        'index': 27,
        'icon': Icons.record_voice_over_rounded,
      },
      {
        'title': 'Remote Scanner',
        'desc': 'Bridge phone camera live to PC',
        'index': 30,
        'icon': Icons.sensors_rounded,
      },
    ],
    'Accounts': [
      {
        'title': 'Party Accounts',
        'desc': 'Consignor / Consignee ledgers',
        'index': 6,
        'icon': Icons.business_center_outlined,
      },
      {
        'title': 'Daily Cashbook',
        'desc': 'Daily cash in & cash out ledger',
        'index': 7,
        'icon': Icons.receipt_long_rounded,
      },
      {
        'title': 'Lorry Accounts',
        'desc': 'Truck freight balance ledger',
        'index': 5,
        'icon': Icons.account_balance_outlined,
      },
    ],
    'Masters': [
      {
        'title': 'Vehicles',
        'desc': 'Fleet registry & permits',
        'index': 8,
        'icon': Icons.local_shipping_rounded,
      },
      {
        'title': 'Drivers',
        'desc': 'Driver profiles & licenses',
        'index': 12,
        'icon': Icons.badge_rounded,
      },
      {
        'title': 'Consignors',
        'desc': 'Sender customer accounts',
        'index': 10,
        'icon': Icons.business_rounded,
      },
      {
        'title': 'Consignees',
        'desc': 'Receiver customer accounts',
        'index': 11,
        'icon': Icons.store_rounded,
      },
      {
        'title': 'Companies',
        'desc': 'AP & BELL enterprise profiles',
        'index': 21,
        'icon': Icons.domain_rounded,
      },
      {
        'title': 'Godowns',
        'desc': 'Branch storage hubs',
        'index': 13,
        'icon': Icons.warehouse_rounded,
      },
      {
        'title': 'Units',
        'desc': 'Packaging measurement units',
        'index': 22,
        'icon': Icons.scale_rounded,
      },
      {
        'title': 'HSN Tax',
        'desc': 'Commodity HSN & GST slabs',
        'index': 14,
        'icon': Icons.percent_rounded,
      },
    ],
    'Reports & Hub': [
      {
        'title': 'Print Hub',
        'desc': 'Thermal & laser print hub',
        'index': 16,
        'icon': Icons.print_rounded,
      },
      {
        'title': 'Reports & BI',
        'desc': 'Operational analytics & summaries',
        'index': 17,
        'icon': Icons.bar_chart_rounded,
      },
      {
        'title': 'Govt Compliance',
        'desc': 'E-Way bill & GST filings',
        'index': 15,
        'icon': Icons.shield_rounded,
      },
    ],
    'System': [
      {
        'title': 'Admin Controls',
        'desc': 'Security & role permissions',
        'index': 24,
        'icon': Icons.admin_panel_settings_rounded,
      },
      {
        'title': 'Audit Trails',
        'desc': 'Tamper-proof event logs',
        'index': 25,
        'icon': Icons.history_edu_rounded,
      },
      {
        'title': 'Legacy Rapid Entry',
        'desc': 'Dense spreadsheet historical GC',
        'index': 28,
        'icon': Icons.bolt_rounded,
      },
      {
        'title': 'Legacy MDB Viewer',
        'desc': 'MS Access historical archives',
        'index': 29,
        'icon': Icons.dns_rounded,
      },
      {
        'title': 'Tech Usage',
        'desc': 'System telemetry & performance',
        'index': 26,
        'icon': Icons.memory_rounded,
      },
    ],
  };

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('Logout Session?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of Arunachalam Transport ERP? Your active session token will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully. Session token cleared.'),
            backgroundColor: Color(0xFF6366F1),
          ),
        );
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, List<Map<String, dynamic>>> get _visibleMenus {
    final result = <String, List<Map<String, dynamic>>>{};
    _menus.forEach((key, items) {
      final filtered = items.where((item) {
        if (item['index'] == 24 && !AuthService.isAdmin) return false;
        return true;
      }).toList();
      if (filtered.isNotEmpty) result[key] = filtered;
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;
    final allScreens = _getAllScreens();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerMove: (_) => _resetInactivityTimer(throttle: true),
      onPointerSignal: (_) => _resetInactivityTimer(throttle: true),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF1F5F9),
        drawer: isMobile ? _buildMobileDrawer() : null,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(isMobile ? 56 : 58),
          child: isMobile ? _buildMobileAppBar() : _buildDesktopAppBar(),
        ),
        body: KeyedSubtree(
          key: ValueKey('branch_epoch_$_branchReloadEpoch'),
          child: IndexedStack(
            index: _activeScreenIndex,
            children: List.generate(allScreens.length, (i) {
              if (!_loadedIndices.contains(i)) {
                return const SizedBox.shrink();
              }
              return allScreens[i]['screen'] as Widget;
            }),
          ),
        ),
        bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
      ),
    );
  }

  // --- Mobile Compact App Bar (56px) ---
  Widget _buildMobileAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF090D1A), // Deepest Midnight
            Color(0xFF0F172A), // Slate Navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Hamburger Menu Button
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                  tooltip: 'Open ERP Menu',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),

                // Mini Brand Icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),

                // Active Screen Title
                Expanded(
                  child: Text(
                    _getActiveScreenTitle(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Compact Station Badge (Clickable for Admin / ALL-branch)
                InkWell(
                  onTap: AuthService.isAdmin ? _showBranchSwitcher : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          AuthService.activeBranch,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF86EFAC),
                          ),
                        ),
                        if (AuthService.isAdmin) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.swap_horiz_rounded, size: 12, color: Color(0xFF86EFAC)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Logout Button
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8), size: 18),
                  tooltip: 'Logout Session',
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Mobile Bottom Navigation Bar (5 Primary Actions) ---
  Widget _buildMobileBottomNav() {
    final navItems = [
      {'title': 'Inward', 'icon': Icons.qr_code_scanner_rounded, 'index': 1},
      {'title': 'Home', 'icon': Icons.home_rounded, 'index': 18},
      {'title': 'Manifest', 'icon': Icons.local_shipping_outlined, 'index': 2},
      {'title': 'Quick Bill', 'icon': Icons.flash_on_rounded, 'index': 23},
      {'title': 'More', 'icon': Icons.grid_view_rounded, 'index': -1},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF090D1A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navItems.map((item) {
              final targetIndex = item['index'] as int;
              final isMenu = targetIndex == -1;
              final isSelected = !isMenu && _activeScreenIndex == targetIndex;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (isMenu) {
                      _scaffoldKey.currentState?.openDrawer();
                    } else {
                      _navigateToIndex(targetIndex);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: isSelected ? 24 : 22,
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- Mobile Drawer (All 30+ ERP Modules Categorized) ---
  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 50, 18, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Text(
                    AuthService.userName.isNotEmpty ? AuthService.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AuthService.userName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'Branch: ${AuthService.activeBranch}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFBFDBFE)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Drawer Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                // Quick Jump Section
                _buildDrawerTile(
                  title: 'Warehouse Inward & Dock',
                  icon: Icons.qr_code_scanner_rounded,
                  index: 1,
                  badge: 'MOBILE',
                ),
                _buildDrawerTile(
                  title: 'Home Dashboard',
                  icon: Icons.home_rounded,
                  index: 18,
                ),
                _buildDrawerTile(
                  title: 'New GC Billing',
                  icon: Icons.note_add_rounded,
                  index: 0,
                ),
                _buildDrawerTile(
                  title: 'Retail Quick Bill',
                  icon: Icons.flash_on_rounded,
                  index: 23,
                ),
                _buildDrawerTile(
                  title: 'GDM Manifest',
                  icon: Icons.local_shipping_outlined,
                  index: 2,
                ),

                const Divider(color: Color(0xFF1E293B), height: 20),

                // Categorized Submenus
                ..._visibleMenus.entries.map((entry) {
                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      iconColor: const Color(0xFF38BDF8),
                      collapsedIconColor: const Color(0xFF64748B),
                      title: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      children: entry.value.map((item) {
                        return _buildDrawerTile(
                          title: item['title'] as String,
                          icon: item['icon'] as IconData,
                          index: item['index'] as int,
                          indent: true,
                        );
                      }).toList(),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Drawer Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFF7F1D1D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('LOGOUT SESSION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _handleLogout();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required String title,
    required IconData icon,
    required int index,
    String? badge,
    bool indent = false,
  }) {
    final isSelected = _activeScreenIndex == index;

    return Container(
      margin: EdgeInsets.only(left: indent ? 12 : 0, bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.6)) : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 18, color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
              )
            : (isSelected ? const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF38BDF8)) : null),
        onTap: () {
          _navigateToIndex(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // --- Desktop Single-Tier App Bar (58px) ---
  Widget _buildDesktopAppBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF090D1A), // Deepest Midnight
            Color(0xFF0F172A), // Slate Navy
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand Icon & Title
          InkWell(
            onTap: () => _navigateToIndex(18),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'ARUNACHALAM ',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: 'TRANSPORT',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFF93C5FD),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Station Pill with Live Indicator & Branch Switcher
          InkWell(
            onTap: AuthService.isAdmin ? _showBranchSwitcher : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AuthService.activeBranch,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF86EFAC),
                    ),
                  ),
                  if (AuthService.isAdmin) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz_rounded, size: 13, color: Color(0xFF86EFAC)),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Center Unified Navigation Menus
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDirectNavTab(
                    title: 'Home',
                    icon: Icons.home_rounded,
                    targetIndex: 18,
                  ),
                  const SizedBox(width: 4),
                  ..._visibleMenus.entries.map((entry) => _buildDropdownNavTab(
                        title: entry.key,
                        items: entry.value,
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // User Profile Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    AuthService.userName.isNotEmpty
                        ? AuthService.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  AuthService.userName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Logout Icon Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
              tooltip: 'Logout Session',
              hoverColor: Colors.red.withValues(alpha: 0.2),
              onPressed: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }

  // --- Direct Navigation Tab (e.g. Home) ---
  Widget _buildDirectNavTab({
    required String title,
    required IconData icon,
    required int targetIndex,
  }) {
    final isSelected = _activeScreenIndex == targetIndex;

    return InkWell(
      onTap: () => _navigateToIndex(targetIndex),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Enhanced Category Dropdown Nav Tab ---
  Widget _buildDropdownNavTab({
    required String title,
    required List<Map<String, dynamic>> items,
  }) {
    final hasActiveChild = items.any((item) => item['index'] == _activeScreenIndex);

    return PopupMenuButton<int>(
      offset: const Offset(0, 42),
      tooltip: '',
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 20,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      onSelected: (int index) {
        _navigateToIndex(index);
      },
      itemBuilder: (BuildContext context) {
        return items.map((item) {
          final isSelected = _activeScreenIndex == item['index'];
          return PopupMenuItem<int>(
            value: item['index'] as int,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        if (item['desc'] != null)
                          Text(
                            item['desc'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                ],
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          gradient: hasActiveChild
              ? const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: hasActiveChild ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: hasActiveChild
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: hasActiveChild ? Colors.white : const Color(0xFFE2E8F0),
                fontWeight: hasActiveChild ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasActiveChild ? Colors.white : const Color(0xFF94A3B8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
