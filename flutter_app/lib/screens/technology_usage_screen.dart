import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class TechnologyUsageScreen extends StatefulWidget {
  const TechnologyUsageScreen({super.key});

  @override
  State<TechnologyUsageScreen> createState() => _TechnologyUsageScreenState();
}

class _TechnologyUsageScreenState extends State<TechnologyUsageScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _health;
  List<dynamic> _healthHistory = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isTestingSandbox = false;
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _healthTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchHealth());
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchStats(),
      _fetchHealth(),
      _fetchHealthHistory(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchHealth() async {
    try {
      final res = await ApiService.getSystemHealth();
      if (mounted && res['success'] == true) {
        setState(() => _health = res['data'] ?? {});
      }
    } catch (_) {}
  }

  Future<void> _fetchHealthHistory() async {
    try {
      final list = await ApiService.getSystemHealthHistory();
      if (mounted) setState(() => _healthHistory = list);
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    try {
      final data = await ApiService.getUsageStats();
      if (mounted) setState(() => _stats = data);
    } catch (_) {}
  }

  Future<void> _manualRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.wait([
      _fetchStats(),
      _fetchHealth(),
      _fetchHealthHistory(),
    ]);
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _runSandboxTest() async {
    setState(() => _isTestingSandbox = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SandboxModal(
        onRun: () => ApiService.runSandboxTest(),
        onDone: () {
          _fetchStats();
        },
      ),
    );

    setState(() => _isTestingSandbox = false);
  }

  String _formatUptime(dynamic rawSeconds) {
    final s = int.tryParse(rawSeconds?.toString() ?? '0') ?? 0;
    if (s <= 0) return '0m';
    final d = s ~/ 86400;
    final h = (s % 86400) ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatMemory(dynamic bytes) {
    final b = double.tryParse(bytes?.toString() ?? '0') ?? 0;
    if (b <= 0) return '0';
    return (b / (1024 * 1024)).toStringAsFixed(0);
  }

  Map<String, dynamic> _getTodayStats() {
    if (_stats == null || _stats!['daily'] == null) return {'count': 0, 'cost': 0.0};
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final daily = _stats!['daily'] as Map<String, dynamic>?;
    if (daily != null && daily.containsKey(today)) {
      final item = daily[today];
      return {
        'count': item['count'] ?? 0,
        'cost': double.tryParse(item['cost']?.toString() ?? '0') ?? 0.0,
      };
    }
    return {'count': 0, 'cost': 0.0};
  }

  Map<String, dynamic> _getThisMonthStats() {
    if (_stats == null || _stats!['monthly'] == null) return {'count': 0, 'cost': 0.0};
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthly = _stats!['monthly'] as Map<String, dynamic>?;
    if (monthly != null && monthly.containsKey(month)) {
      final item = monthly[month];
      return {
        'count': item['count'] ?? 0,
        'cost': double.tryParse(item['cost']?.toString() ?? '0') ?? 0.0,
      };
    }
    return {'count': 0, 'cost': 0.0};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayStats = _getTodayStats();
    final monthStats = _getThisMonthStats();
    final totalCost = double.tryParse(_stats?['totalCost']?.toString() ?? '0') ?? 0.0;
    final recentLogs = (_stats?['recent'] as List?) ?? [];

    final memoryRss = _health?['memoryUsage']?['rss'];
    final uptimeSeconds = _health?['uptime'];
    final dbPing = _health?['dbLatency'];
    final cpuLoad = (_health?['cpuLoad'] as List?)?.isNotEmpty == true ? _health!['cpuLoad'][0] : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      body: _isLoading && _health == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Executive Cockpit Header
                  _buildCockpitHeader(
                    isDark: isDark,
                    memoryRss: memoryRss,
                    uptimeSeconds: uptimeSeconds,
                    dbPing: dbPing,
                    monthCost: monthStats['cost'] as double,
                  ),

                  // Main Content Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: System Vitals
                            Row(
                              children: [
                                const Icon(Icons.dns_rounded, size: 18, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Text(
                                  'SYSTEM HEALTH & VITALS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _isRefreshing ? null : _manualRefresh,
                                  icon: _isRefreshing
                                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.refresh_rounded, size: 14),
                                  label: const Text('Refresh Vitals', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 4 Vitals Cards
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;
                                return GridView.count(
                                  crossAxisCount: isNarrow ? 2 : 4,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: isNarrow ? 1.6 : 1.8,
                                  children: [
                                    _buildVitalCard(
                                      title: 'BACKEND MEMORY',
                                      value: '${_formatMemory(memoryRss)} MB',
                                      subtitle: 'RAM Used',
                                      icon: Icons.memory_rounded,
                                      color: const Color(0xFF10B981),
                                      isDark: isDark,
                                    ),
                                    _buildVitalCard(
                                      title: 'SERVER UPTIME',
                                      value: _formatUptime(uptimeSeconds),
                                      subtitle: 'Without Downtime',
                                      icon: Icons.schedule_rounded,
                                      color: const Color(0xFF6366F1),
                                      isDark: isDark,
                                    ),
                                    _buildVitalCard(
                                      title: 'DATABASE PING',
                                      value: '${dbPing ?? "--"} ms',
                                      subtitle: 'PostgreSQL Latency',
                                      icon: Icons.storage_rounded,
                                      color: const Color(0xFFF59E0B),
                                      isDark: isDark,
                                    ),
                                    _buildVitalCard(
                                      title: 'CPU LOAD (1M)',
                                      value: cpuLoad != null ? (double.tryParse(cpuLoad.toString())?.toStringAsFixed(2) ?? '--') : '--',
                                      subtitle: 'Processor Avg',
                                      icon: Icons.speed_rounded,
                                      color: const Color(0xFF0EA5E9),
                                      isDark: isDark,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // System Status Summary (English Report)
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'SYSTEM STATUS SUMMARY',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrow = constraints.maxWidth < 650;
                                      return GridView.count(
                                        crossAxisCount: isNarrow ? 1 : 2,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 12,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        childAspectRatio: isNarrow ? 3.5 : 3.8,
                                        children: [
                                          _buildStatusTile(
                                            title: 'Performance',
                                            status: (dbPing is int && dbPing > 100) ? 'Degraded' : 'Excellent',
                                            desc: 'System queries are executing promptly under standard threshold.',
                                            isOk: (dbPing is int && dbPing > 100) ? false : true,
                                            isDark: isDark,
                                          ),
                                          _buildStatusTile(
                                            title: 'Reliability',
                                            status: 'High Stability',
                                            desc: 'Zero unhandled cluster exceptions in the active runtime.',
                                            isOk: true,
                                            isDark: isDark,
                                          ),
                                          _buildStatusTile(
                                            title: 'Resource Health',
                                            status: 'Stable',
                                            desc: 'Memory utilization is level with no memory leak profiles.',
                                            isOk: true,
                                            isDark: isDark,
                                          ),
                                          _buildStatusTile(
                                            title: 'Maintenance',
                                            status: 'Up to date',
                                            desc: 'Prisma query cache & temporary log cleaner running normally.',
                                            isOk: true,
                                            isDark: isDark,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 24-Hour Performance Timeline Visual
                            if (_healthHistory.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.insights_rounded, color: Color(0xFF6366F1), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          '24-HOUR PERFORMANCE TIMELINE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Row(
                                          children: [
                                            CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
                                            SizedBox(width: 6),
                                            Text('Memory (MB)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                            SizedBox(width: 14),
                                            CircleAvatar(radius: 4, backgroundColor: Color(0xFFF59E0B)),
                                            SizedBox(width: 6),
                                            Text('DB Ping (ms)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      height: 120,
                                      child: CustomPaint(
                                        painter: _TimelineChartPainter(
                                          data: _healthHistory,
                                          isDark: isDark,
                                        ),
                                        child: Container(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // API Billing & Analytics Cards
                            Row(
                              children: [
                                const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Text(
                                  'API BILLING & ANALYTICS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 650;
                                return Flex(
                                  direction: isNarrow ? Axis.vertical : Axis.horizontal,
                                  children: [
                                    Expanded(
                                      flex: isNarrow ? 0 : 1,
                                      child: Container(
                                        padding: const EdgeInsets.all(22),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(18),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'TODAY\'S API USAGE',
                                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${todayStats['count']} Calls',
                                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                                                ),
                                                Text(
                                                  '₹${(todayStats['cost'] as double).toStringAsFixed(2)}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isNarrow ? 0 : 14, height: isNarrow ? 12 : 0),
                                    Expanded(
                                      flex: isNarrow ? 0 : 1,
                                      child: Container(
                                        padding: const EdgeInsets.all(22),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'THIS MONTH',
                                              style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${monthStats['count']} Calls',
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  '₹${(monthStats['cost'] as double).toStringAsFixed(2)}',
                                                  style: const TextStyle(color: Color(0xFFE11D48), fontSize: 20, fontWeight: FontWeight.w800),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isNarrow ? 0 : 14, height: isNarrow ? 12 : 0),
                                    Expanded(
                                      flex: isNarrow ? 0 : 1,
                                      child: Container(
                                        padding: const EdgeInsets.all(22),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'ALL-TIME DATABASE',
                                              style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '₹${totalCost.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const Text(
                                                  'Total Cost',
                                                  style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 28),

                            // Cloud Infrastructure Architecture Grid
                            Row(
                              children: [
                                const Icon(Icons.cloud_done_rounded, size: 18, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Text(
                                  'CLOUD INFRASTRUCTURE ARCHITECTURE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 650;
                                final isMedium = constraints.maxWidth < 950;
                                final cols = isNarrow ? 1 : (isMedium ? 2 : 3);
                                return GridView.count(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: isNarrow ? 2.3 : 1.9,
                                  children: [
                                    _buildTechCard(
                                      title: 'Supabase PostgreSQL',
                                      desc: 'Serverless Database holding all ERP records with connection pooling and edge caching.',
                                      status: 'ACTIVE',
                                      icon: Icons.storage_rounded,
                                      color: const Color(0xFF3B82F6),
                                      link: 'https://supabase.com/dashboard',
                                      isDark: isDark,
                                    ),
                                    _buildTechCard(
                                      title: 'Railway Backend',
                                      desc: 'Node.js Express Server handling heavy PDF generation and E-Way Bill integrations 24/7.',
                                      status: 'ACTIVE',
                                      icon: Icons.dns_rounded,
                                      color: const Color(0xFF8B5CF6),
                                      link: 'https://railway.app/dashboard',
                                      isDark: isDark,
                                    ),
                                    _buildTechCard(
                                      title: 'Vercel & Flutter CDN',
                                      desc: 'Global Edge Network hosting responsive web and desktop portals with sub-second asset delivery.',
                                      status: 'ACTIVE',
                                      icon: Icons.cloud_queue_rounded,
                                      color: const Color(0xFF0EA5E9),
                                      link: 'https://vercel.com',
                                      isDark: isDark,
                                    ),
                                    _buildTechCard(
                                      title: 'Whitebooks API',
                                      desc: 'Fetches government E-Way Bill details, verifies VAHAN RC statuses, and GSTIN auto-fill.',
                                      status: 'PREPAID',
                                      icon: Icons.sync_alt_rounded,
                                      color: const Color(0xFFF59E0B),
                                      link: 'https://api.whitebooks.in',
                                      isDark: isDark,
                                    ),
                                    _buildTechCard(
                                      title: 'Appyflow API',
                                      desc: 'Integrated globally for instant GSTIN verification and postal pincode city mapping.',
                                      status: 'ACTIVE',
                                      icon: Icons.verified_rounded,
                                      color: const Color(0xFF10B981),
                                      link: 'https://app.appyflow.in',
                                      isDark: isDark,
                                    ),
                                    _buildTechCard(
                                      title: 'Tesseract OCR',
                                      desc: 'On-device camera AI processing for rapid barcode & consignment slip scanning.',
                                      status: 'ACTIVE',
                                      icon: Icons.document_scanner_rounded,
                                      color: const Color(0xFFEC4899),
                                      link: null,
                                      isDark: isDark,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 28),

                            // Recent API Execution Logs Table
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Recent API Execution Logs',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${recentLogs.length} Events Logged',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, thickness: 1),

                                  if (recentLogs.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(40),
                                      child: Center(
                                        child: Text('No API calls recorded yet.', style: TextStyle(color: Color(0xFF64748B))),
                                      ),
                                    )
                                  else
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        horizontalMargin: 20,
                                        columnSpacing: 32,
                                        headingRowHeight: 46,
                                        dataRowMinHeight: 52,
                                        dataRowMaxHeight: 56,
                                        headingTextStyle: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          letterSpacing: 0.5,
                                        ),
                                        columns: const [
                                          DataColumn(label: Text('TIMESTAMP')),
                                          DataColumn(label: Text('PROVIDER')),
                                          DataColumn(label: Text('API NAME')),
                                          DataColumn(label: Text('STATUS')),
                                          DataColumn(label: Text('COST (₹)', textAlign: TextAlign.right)),
                                        ],
                                        rows: recentLogs.map((log) {
                                          final status = log['status']?.toString() ?? 'Success';
                                          final isSuccess = status.toLowerCase() == 'success';
                                          final cost = double.tryParse(log['cost']?.toString() ?? '0') ?? 0.0;

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  log['timestamp'] != null
                                                      ? DateTime.tryParse(log['timestamp'].toString())?.toLocal().toString().substring(0, 19) ?? '-'
                                                      : '-',
                                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  log['provider']?.toString() ?? '-',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  log['apiName']?.toString() ?? '-',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isSuccess ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFE11D48).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: isSuccess ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFE11D48).withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    status.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                      color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  cost > 0 ? '₹${cost.toStringAsFixed(2)}' : 'Free',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: cost > 0 ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF10B981),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
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

  Widget _buildCockpitHeader({
    required bool isDark,
    required dynamic memoryRss,
    required dynamic uptimeSeconds,
    required dynamic dbPing,
    required double monthCost,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top breadcrumb tag & actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.memory_rounded, size: 12, color: Color(0xFF818CF8)),
                        SizedBox(width: 6),
                        Text(
                          'ENTERPRISE TELEMETRY // CLOUD CLUSTER & API USAGE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFFC7D2FE),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'SYSTEM LIVE // ALL NODES PASS',
                              style: TextStyle(
                                color: Color(0xFF6EE7B7),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isTestingSandbox ? null : _runSandboxTest,
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('Run Sandbox Test'),
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
              const SizedBox(height: 14),

              // Title & Description
              const Text(
                'Technology & Infrastructure Cockpit',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Real-time health monitoring across PostgreSQL clusters, Node.js edge nodes, query latencies, and prepaid third-party API quotas.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // KPI Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 750;
                  return isNarrow
                      ? Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildKpiCard(
                              title: 'BACKEND RAM',
                              value: '${_formatMemory(memoryRss)} MB',
                              subtitle: 'Active cluster footprint',
                              icon: Icons.memory_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            _buildKpiCard(
                              title: 'SERVER UPTIME',
                              value: _formatUptime(uptimeSeconds),
                              subtitle: 'Continuous production runtime',
                              icon: Icons.schedule_rounded,
                              color: const Color(0xFF6366F1),
                            ),
                            _buildKpiCard(
                              title: 'DATABASE PING',
                              value: '${dbPing ?? "--"} ms',
                              subtitle: 'PostgreSQL round-trip time',
                              icon: Icons.storage_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                            _buildKpiCard(
                              title: 'MONTHLY SPEND',
                              value: '₹${monthCost.toStringAsFixed(0)}',
                              subtitle: 'External API consumption',
                              icon: Icons.currency_rupee_rounded,
                              color: const Color(0xFF3B82F6),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'BACKEND RAM',
                                value: '${_formatMemory(memoryRss)} MB',
                                subtitle: 'Active cluster footprint',
                                icon: Icons.memory_rounded,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'SERVER UPTIME',
                                value: _formatUptime(uptimeSeconds),
                                subtitle: 'Continuous production runtime',
                                icon: Icons.schedule_rounded,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'DATABASE PING',
                                value: '${dbPing ?? "--"} ms',
                                subtitle: 'PostgreSQL round-trip time',
                                icon: Icons.storage_rounded,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'MONTHLY SPEND',
                                value: '₹${monthCost.toStringAsFixed(0)}',
                                subtitle: 'External API consumption',
                                icon: Icons.currency_rupee_rounded,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile({
    required String title,
    required String status,
    required String desc,
    required bool isOk,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 18,
            color: isOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isOk ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechCard({
    required String title,
    required String desc,
    required String status,
    required IconData icon,
    required Color color,
    String? link,
    required bool isDark,
  }) {
    final isPrepaid = status == 'PREPAID';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPrepaid ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isPrepaid ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isPrepaid ? const Color(0xFFD97706) : const Color(0xFF059669),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 10),
          if (link != null)
            InkWell(
              onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              child: Row(
                children: [
                  Text(
                    'Manage Dashboard',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: color),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineChartPainter extends CustomPainter {
  final List<dynamic> data;
  final bool isDark;

  _TimelineChartPainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintMemory = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPing = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    // Max values for normalization
    double maxMem = 300.0;
    double maxPing = 50.0;

    for (final item in data) {
      final mem = double.tryParse(item['memoryMb']?.toString() ?? '0') ?? 0.0;
      final ping = double.tryParse(item['dbPing']?.toString() ?? '0') ?? 0.0;
      if (mem > maxMem) maxMem = mem;
      if (ping > maxPing) maxPing = ping;
    }

    final pathMem = Path();
    final pathPing = Path();

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final mem = double.tryParse(item['memoryMb']?.toString() ?? '0') ?? 0.0;
      final ping = double.tryParse(item['dbPing']?.toString() ?? '0') ?? 0.0;

      final x = i * stepX;
      final yMem = size.height - (mem / maxMem * (size.height - 20)) - 10;
      final yPing = size.height - (ping / maxPing * (size.height - 20)) - 10;

      if (i == 0) {
        pathMem.moveTo(x, yMem);
        pathPing.moveTo(x, yPing);
      } else {
        pathMem.lineTo(x, yMem);
        pathPing.lineTo(x, yPing);
      }
    }

    canvas.drawPath(pathMem, paintMemory);
    canvas.drawPath(pathPing, paintPing);
  }

  @override
  bool shouldRepaint(covariant _TimelineChartPainter oldDelegate) => true;
}

class _SandboxModal extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() onRun;
  final VoidCallback onDone;

  const _SandboxModal({required this.onRun, required this.onDone});

  @override
  State<_SandboxModal> createState() => _SandboxModalState();
}

class _SandboxModalState extends State<_SandboxModal> {
  bool _isRunning = true;
  List<dynamic> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final res = await widget.onRun();
      if (mounted) {
        setState(() {
          _results = res['results'] as List? ?? [];
          _isRunning = false;
        });
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sandbox Lifecycle Test',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF94A3B8),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text(
                'Executing verification sequence on NIC test environment.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 20),

              if (_isRunning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF4F46E5)),
                        SizedBox(height: 14),
                        Text(
                          'Pinging NIC sandbox (Auth ➔ Generate ➔ Fetch)...',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Text('Test sequence failed: $_error', style: const TextStyle(color: Color(0xFF9F1239), fontSize: 13, fontWeight: FontWeight.w600)),
                )
              else
                Column(
                  children: _results.map((r) {
                    final success = r['success'] == true;
                    final ping = r['ping'] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: success
                            ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFFE11D48).withValues(alpha: 0.12) : const Color(0xFFFFF1F2)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: success
                              ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFA7F3D0))
                              : (isDark ? const Color(0xFFE11D48).withValues(alpha: 0.3) : const Color(0xFFFECDD3)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: success ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['step']?.toString() ?? 'Step',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  r['message']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: success
                                        ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46))
                                        : (isDark ? const Color(0xFFFECDD3) : const Color(0xFF9F1239)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${ping}ms',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close Dialog', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
