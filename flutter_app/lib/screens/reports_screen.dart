import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _activeTab = 'gc';

  final TextEditingController _searchController = TextEditingController();
  String _branch = 'ALL';
  String _statusFilter = '';
  String _freightTypeFilter = '';
  String _godownFilter = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  int _page = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchReportData({bool append = false}) async {
    if (append) {
      if (_page >= _totalPages) return;
      _page++;
    } else {
      _page = 1;
      _reportData = [];
      setState(() => _isLoading = true);
    }

    try {
      final q = StringBuffer('page=$_page&limit=50');
      if (_branch != 'ALL') q.write('&branch=$_branch');
      if (_statusFilter.isNotEmpty) q.write('&status=${Uri.encodeComponent(_statusFilter)}');
      if (_freightTypeFilter.isNotEmpty) q.write('&freightType=${Uri.encodeComponent(_freightTypeFilter)}');
      if (_godownFilter.isNotEmpty) q.write('&godown=${Uri.encodeComponent(_godownFilter)}');
      if (_fromDate != null) q.write('&fromDate=${_fromDate!.toIso8601String().split('T').first}');
      if (_toDate != null) q.write('&toDate=${_toDate!.toIso8601String().split('T').first}');
      if (_searchController.text.trim().isNotEmpty) {
        final term = Uri.encodeComponent(_searchController.text.trim());
        q.write('&searchQuery=$term&q=$term');
      }

      Map<String, dynamic> res;
      List<Map<String, dynamic>> parsedData = [];

      if (['consignor', 'consignee', 'vehicle'].contains(_activeTab)) {
        res = await ApiService.getReportAggregations(q.toString());
        if (_activeTab == 'consignor') parsedData = List<Map<String, dynamic>>.from(res['consignors'] ?? []);
        if (_activeTab == 'consignee') parsedData = List<Map<String, dynamic>>.from(res['consignees'] ?? []);
        if (_activeTab == 'vehicle') parsedData = List<Map<String, dynamic>>.from(res['vehicles'] ?? []);
        _totalRecords = parsedData.length;
        _totalPages = 1;
      } else if (_activeTab == 'gc' || _activeTab == 'ewaybill') {
        res = await ApiService.getReportGcs(q.toString());
        _totalRecords = res['total'] ?? 0;
        _totalPages = res['totalPages'] ?? 1;

        for (var item in (res['data'] as List? ?? [])) {
          if (_activeTab == 'gc') {
            parsedData.add({
              'id': item['id'],
              'GC Number': item['gcNumber'],
              'Date': item['date']?.toString().split('T').first ?? '',
              'Consignor': item['consignor']?['name'] ?? '-',
              'Consignee': item['consignee']?['name'] ?? '-',
              'Invoice Value': item['invoiceValue'],
              'Freight Type': item['freightType'],
              'Freight Amount': item['freightTotal'],
              'Status': item['status']
            });
          } else {
            parsedData.add({
              'id': item['id'],
              'E-Way Bill No': item['ewbNumber'] ?? 'PENDING',
              'GC No': item['gcNumber'],
              'Date': item['date']?.toString().split('T').first ?? '',
              'Consignor': item['consignor']?['name'] ?? '-',
              'Consignee': item['consignee']?['name'] ?? '-',
              'Invoice Value': item['invoiceValue'],
              'Status': item['status']
            });
          }
        }
      } else if (_activeTab == 'gdm') {
        res = await ApiService.getReportGdms(q.toString());
        _totalRecords = res['total'] ?? 0;
        _totalPages = res['totalPages'] ?? 1;
        for (var item in (res['data'] as List? ?? [])) {
          parsedData.add({
            'id': item['id'],
            'GDM Number': item['gdmNumber'],
            'Date': item['date']?.toString().split('T').first ?? '',
            'Vehicle': item['vehicle']?['vehicleNumber'] ?? '-',
            'Destination': item['destination'] ?? item['toName'] ?? '-',
            'Total GCs': (item['gcs'] as List?)?.length ?? 0,
            'Status': item['status']
          });
        }
      }

      setState(() {
        if (append) {
          _reportData.addAll(parsedData);
        } else {
          _reportData = parsedData;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report data: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTabChanged(String tabId) {
    setState(() {
      _activeTab = tabId;
      _searchController.clear();
      _branch = 'ALL';
      _statusFilter = '';
      _freightTypeFilter = '';
      _godownFilter = '';
      _fromDate = null;
      _toDate = null;
    });
    _fetchReportData();
  }

  double get _totalComputedFreight {
    double sum = 0;
    for (var r in _reportData) {
      final f = r['Freight Amount'] ?? r['Freight'] ?? r['totalFreight'] ?? r['Invoice Value'] ?? 0;
      sum += double.tryParse(f.toString()) ?? 0;
    }
    return sum;
  }

  int get _deliveredCount {
    return _reportData.where((r) => r['Status']?.toString().toLowerCase() == 'delivered').length;
  }

  void _exportCsv() {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    final headers = _reportData.first.keys.where((k) => k != 'id' && k != '_gcObj').toList();
    final buffer = StringBuffer();
    buffer.writeln(headers.map((h) => '"$h"').join(','));

    for (var row in _reportData) {
      final line = headers.map((h) {
        final val = row[h]?.toString().replaceAll('"', '""') ?? '';
        return '"$val"';
      }).join(',');
      buffer.writeln(line);
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              '${_reportData.length} ${_activeTab.toUpperCase()} records copied to clipboard in CSV format!',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showRecordDetailModal(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.analytics_rounded, color: Color(0xFF0284C7), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REPORT RECORD AUDIT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF64748B),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            row['GC Number'] ?? row['GDM Number'] ?? row['E-Way Bill No'] ?? 'Record #${row['id'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: row.entries.where((e) => e.key != 'id' && e.key != '_gcObj').map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                          ),
                          Flexible(
                            child: Text(
                              entry.value?.toString() ?? '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('DISMISS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? bgColor, Color? borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTabPill(String id, String label, IconData icon) {
    final isActive = _activeTab == id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onTabChanged(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isActive ? Colors.white : const Color(0xFF334155),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Cockpit Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF082F49), Color(0xFF0369A1), Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Executive BI & Operational Analytics',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBAE6FD).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF7DD3FC).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.query_stats_rounded, size: 12, color: Color(0xFFE0F2FE)),
                                SizedBox(width: 5),
                                Text(
                                  'REAL-TIME AUDIT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    color: Color(0xFFE0F2FE),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Multi-dimensional logistics reports, freight turnover, consignment tracking & partner volume audits',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFFE0F2FE).withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Record Count Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dataset_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        '$_totalRecords Records',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Export CSV Button
                ElevatedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('EXPORT CSV', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0369A1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Executive Financial Summary KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildGlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.list_alt_rounded, color: Color(0xFF0284C7), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RECORDS IN REPORT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_reportData.length} Loaded',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0284C7),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _buildGlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF10B981), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REPORT VOLUME / FREIGHT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '₹ ${_totalComputedFreight.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _buildGlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF7C3AED), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DELIVERY CLEARANCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$_deliveredCount Delivered',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C3AED),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Main Filter & Table Swiss Card
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Horizontal Report Category Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabPill('gc', 'GC Consignment Report', Icons.inventory_2_rounded),
                      _buildTabPill('gdm', 'GDM Despatch Manifests', Icons.local_shipping_rounded),
                      _buildTabPill('ewaybill', 'E-Way Bill Compliance', Icons.shield_outlined),
                      _buildTabPill('consignor', 'Consignor Volumes', Icons.business_rounded),
                      _buildTabPill('consignee', 'Consignee Receiver Metrics', Icons.people_alt_rounded),
                      _buildTabPill('vehicle', 'Fleet Utilization', Icons.directions_bus_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 20),

                // Filter Strip
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _fetchReportData(),
                        decoration: InputDecoration(
                          hintText: 'Search within ${_activeTab.toUpperCase()} records...',
                          hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _fetchReportData();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Branch Selector
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: _branch,
                        decoration: InputDecoration(
                          labelText: 'Branch',
                          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All Branches')),
                          DropdownMenuItem(value: 'MAIN', child: Text('Main (Sivakasi)')),
                          DropdownMenuItem(value: 'AP_BNG', child: Text('AP Bangalore')),
                          DropdownMenuItem(value: 'MADURAI', child: Text('Madurai')),
                          DropdownMenuItem(value: 'CHENNAI', child: Text('Chennai')),
                        ],
                        onChanged: (val) {
                          setState(() => _branch = val!);
                          _fetchReportData();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // From Date
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _fromDate = picked);
                          _fetchReportData();
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(
                        _fromDate == null
                            ? 'From Date'
                            : '${_fromDate!.day.toString().padLeft(2, '0')}/${_fromDate!.month.toString().padLeft(2, '0')}/${_fromDate!.year}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // To Date
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _toDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _toDate = picked);
                          _fetchReportData();
                        }
                      },
                      icon: const Icon(Icons.event_rounded, size: 14),
                      label: Text(
                        _toDate == null
                            ? 'To Date'
                            : '${_toDate!.day.toString().padLeft(2, '0')}/${_toDate!.month.toString().padLeft(2, '0')}/${_toDate!.year}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    if (_activeTab == 'gc') ...[
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String>(
                          value: _freightTypeFilter,
                          decoration: InputDecoration(
                            labelText: 'Freight Type',
                            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All Types')),
                            DropdownMenuItem(value: 'To Pay', child: Text('To Pay')),
                            DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                            DropdownMenuItem(value: 'T.B.B.', child: Text('T.B.B.')),
                          ],
                          onChanged: (val) {
                            setState(() => _freightTypeFilter = val!);
                            _fetchReportData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Status filter if applicable
                    if (['gc', 'gdm', 'ewaybill'].contains(_activeTab))
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.8),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'Created', child: Text('Created')),
                            DropdownMenuItem(value: 'In Transit', child: Text('In Transit')),
                            DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                          ],
                          onChanged: (val) {
                            setState(() => _statusFilter = val!);
                            _fetchReportData();
                          },
                        ),
                      ),
                    if (['gc', 'gdm', 'ewaybill'].contains(_activeTab)) const SizedBox(width: 14),

                    // Refresh Button
                    ElevatedButton.icon(
                      onPressed: () => _fetchReportData(),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Data Table Container
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(60.0),
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                            ),
                          )
                        : _reportData.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(60.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.blueGrey.shade200),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No matching report records found.',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Scrollbar(
                                controller: _horizontalScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 1000),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                      dataRowMinHeight: 48,
                                      dataRowMaxHeight: 52,
                                      horizontalMargin: 20,
                                      columnSpacing: 24,
                                      columns: _reportData.first.keys
                                          .where((k) => k != 'id' && k != '_gcObj')
                                          .map((k) => DataColumn(
                                                label: Text(
                                                  k.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                      rows: _reportData.map((row) {
                                        return DataRow(
                                          onSelectChanged: (_) => _showRecordDetailModal(row),
                                          cells: row.entries
                                              .where((e) => e.key != 'id' && e.key != '_gcObj')
                                              .map((e) {
                                            final valStr = e.value?.toString() ?? '-';
                                            final isMoney = e.key.toLowerCase().contains('freight') ||
                                                e.key.toLowerCase().contains('value') ||
                                                e.key.toLowerCase().contains('amount');
                                            final isStatus = e.key.toLowerCase().contains('status');

                                            if (isStatus) {
                                              final isDelivered = valStr.toLowerCase() == 'delivered';
                                              final isInTransit = valStr.toLowerCase() == 'in transit';
                                              return DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isDelivered
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                        : (isInTransit
                                                            ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                                            : const Color(0xFFF1F5F9)),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    valStr,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: isDelivered
                                                          ? const Color(0xFF059669)
                                                          : (isInTransit
                                                              ? const Color(0xFF2563EB)
                                                              : const Color(0xFF475569)),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }

                                            return DataCell(
                                              Text(
                                                isMoney && double.tryParse(valStr) != null
                                                    ? '₹$valStr'
                                                    : valStr,
                                                style: TextStyle(
                                                  fontWeight: isMoney ? FontWeight.w900 : FontWeight.w700,
                                                  fontSize: 12,
                                                  color: isMoney ? const Color(0xFF059669) : const Color(0xFF1E293B),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 16),

                // Table Pagination Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${_reportData.length} of $_totalRecords records',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Row(
                      children: [
                        Text(
                          'Page $_page of $_totalPages',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        if (_page < _totalPages) ...[
                          const SizedBox(width: 14),
                          TextButton.icon(
                            onPressed: () => _fetchReportData(append: true),
                            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                            label: const Text('Load More Records', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
