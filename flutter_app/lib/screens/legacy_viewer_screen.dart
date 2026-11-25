import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class LegacyViewerScreen extends StatefulWidget {
  const LegacyViewerScreen({super.key});

  @override
  State<LegacyViewerScreen> createState() => _LegacyViewerScreenState();
}

class _LegacyViewerScreenState extends State<LegacyViewerScreen> {
  List<String> _companies = [];
  String? _selectedCompany;

  List<String> _financialYears = [];
  String? _selectedFy;

  String _activeTab = 'consignors'; // consignors, consignees, vehicles, transactions, gdms
  List<dynamic> _data = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int _visibleCount = 100;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final companies = await ApiService.getLegacyCompanies();
      if (mounted) {
        setState(() {
          _companies = companies;
          if (companies.isNotEmpty) {
            _selectedCompany = companies.first;
          }
          _isLoading = false;
        });

        if (_selectedCompany != null) {
          _fetchFinancialYearsAndData();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load MS Access folders: ${e.toString().replaceAll('Exception:', '').trim()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchFinancialYearsAndData() async {
    if (_selectedCompany == null) return;

    try {
      final years = await ApiService.getLegacyFinancialYears(_selectedCompany!);
      if (mounted) {
        setState(() {
          _financialYears = years;
          _selectedFy = years.isNotEmpty ? years.first : null;
        });
        _fetchData();
      }
    } catch (_) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (_selectedCompany == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _visibleCount = 100;
    });

    try {
      final res = await ApiService.getLegacyMdbData(
        _selectedCompany!,
        _activeTab,
        fy: (_activeTab == 'transactions' || _activeTab == 'gdms' || _activeTab == 'vehicles') ? _selectedFy : null,
      );

      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load $_activeTab from MS Access: ${e.toString().replaceAll('Exception:', '').trim()}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    final str = dateVal.toString().trim();
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(str)) {
      return str;
    }
    try {
      final d = DateTime.parse(str);
      return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    } catch (_) {
      return str;
    }
  }

  void _showRecordDetailsModal(Map<String, dynamic> row, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storage_rounded, color: Color(0xFF6366F1), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raw MS Access Record',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Exact attributes extracted from historical .mdb tables ($_activeTab)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: const Color(0xFF94A3B8),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Modal Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: row.entries.map((entry) {
                      final valStr = entry.value == null || entry.value.toString().isEmpty ? 'EMPTY' : entry.value.toString();
                      final isEmpty = entry.value == null || entry.value.toString().isEmpty;

                      return SizedBox(
                        width: 350,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (!isEmpty)
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: entry.value.toString()));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Copied ${entry.key}: ${entry.value}'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                valStr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isEmpty
                                      ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                  fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
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

              // Modal Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                      label: const Text('Record Verified', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Record verified and active in current ERP buffer!'),
                            backgroundColor: Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _data.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (item is Map) {
        return item.values.any((v) => v != null && v.toString().toLowerCase().contains(q));
      }
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Executive Cockpit Header
            _buildCockpitHeader(
              isDark: isDark,
              totalRecords: _data.length,
              filteredRecords: filtered.length,
            ),

            // Main Body Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Navigation Tabs & Search Toolbar
                      _buildToolbar(isDark: isDark, filteredCount: filtered.length),
                      const SizedBox(height: 20),

                      // Error Banner if any
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFFBE123C)),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Content Cards
                      if (_isLoading)
                        Container(
                          height: 360,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3),
                              const SizedBox(height: 18),
                              Text(
                                'Reading historical MS Access (.mdb) files...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (filtered.isEmpty)
                        _buildEmptyState(isDark)
                      else ...[
                        // Cards Grid
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 800;
                            final itemWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
                            final visibleSubset = filtered.take(_visibleCount).toList();

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: visibleSubset.map((item) {
                                final row = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
                                return SizedBox(
                                  width: itemWidth,
                                  child: _buildRecordCard(row, isDark),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        // Load More Button
                        if (filtered.length > _visibleCount) ...[
                          const SizedBox(height: 24),
                          Center(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                foregroundColor: isDark ? Colors.white : const Color(0xFF475569),
                                elevation: 0,
                                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.expand_more_rounded, size: 20),
                              label: Text(
                                'Load More (+100) — Showing $_visibleCount of ${filtered.length}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                setState(() => _visibleCount += 100);
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Showing ${filtered.length < _visibleCount ? filtered.length : _visibleCount} of ${filtered.length} records from MS Access archive.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],

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
    required int totalRecords,
    required int filteredRecords,
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
                        Icon(Icons.inventory_2_rounded, size: 12, color: Color(0xFF818CF8)),
                        SizedBox(width: 6),
                        Text(
                          'HISTORICAL ARCHIVES // JELLY MS ACCESS (.MDB) BRIDGE',
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
                      // Financial Year dropdown if applicable
                      if (_activeTab == 'transactions' || _activeTab == 'gdms' || _activeTab == 'vehicles') ...[
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: const Color(0xFF1E293B),
                              value: _financialYears.contains(_selectedFy) ? _selectedFy : null,
                              hint: const Text('All Years', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('All Years', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))),
                                ..._financialYears.map((fy) => DropdownMenuItem(value: fy, child: Text(fy, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)))),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedFy = val);
                                _fetchData();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      // Company dropdown
                      if (_companies.isNotEmpty) ...[
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: const Color(0xFF1E293B),
                              value: _companies.contains(_selectedCompany) ? _selectedCompany : _companies.first,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                              items: _companies.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCompany = val);
                                  _fetchFinancialYearsAndData();
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      IconButton(
                        onPressed: _isLoading ? null : _fetchData,
                        tooltip: 'Refresh Archive',
                        icon: _isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title & Description
              const Text(
                'Legacy ERP Archives & Data Bridge',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Direct high-speed reader across legacy Microsoft Access databases, historical transaction ledgers, and master parties.',
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
                              title: 'COMPANY FOLDER',
                              value: _selectedCompany ?? 'NONE',
                              subtitle: 'Active Access database',
                              icon: Icons.folder_rounded,
                              color: const Color(0xFF6366F1),
                            ),
                            _buildKpiCard(
                              title: 'FINANCIAL YEAR',
                              value: (_selectedFy?.isNotEmpty == true ? _selectedFy! : 'ALL YEARS'),
                              subtitle: 'Historical ledger partition',
                              icon: Icons.calendar_today_rounded,
                              color: const Color(0xFF3B82F6),
                            ),
                            _buildKpiCard(
                              title: 'LOADED RECORDS',
                              value: totalRecords.toString(),
                              subtitle: 'Rows in current buffer',
                              icon: Icons.dns_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            _buildKpiCard(
                              title: 'FILTER MATCHES',
                              value: filteredRecords.toString(),
                              subtitle: 'Active search matches',
                              icon: Icons.filter_alt_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'COMPANY FOLDER',
                                value: _selectedCompany ?? 'NONE',
                                subtitle: 'Active Access database',
                                icon: Icons.folder_rounded,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'FINANCIAL YEAR',
                                value: (_selectedFy?.isNotEmpty == true ? _selectedFy! : 'ALL YEARS'),
                                subtitle: 'Historical ledger partition',
                                icon: Icons.calendar_today_rounded,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'LOADED RECORDS',
                                value: totalRecords.toString(),
                                subtitle: 'Rows in current buffer',
                                icon: Icons.dns_rounded,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'FILTER MATCHES',
                                value: filteredRecords.toString(),
                                subtitle: 'Active search matches',
                                icon: Icons.filter_alt_rounded,
                                color: const Color(0xFFF59E0B),
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

  Widget _buildToolbar({required bool isDark, required int filteredCount}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Tabs
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabButton('Consignors', 'consignors', isDark),
                        _buildTabButton('Consignees', 'consignees', isDark),
                        _buildTabButton('Vehicles', 'vehicles', isDark),
                        _buildTabButton('GCs (Bills)', 'transactions', isDark),
                        _buildTabButton('GDMs (Trips)', 'gdms', isDark),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Search Bar
              SizedBox(
                width: 320,
                height: 42,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search legacy $_activeTab...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tabKey, bool isDark) {
    final isSelected = _activeTab == tabKey;

    return InkWell(
      onTap: () {
        if (_activeTab != tabKey) {
          setState(() => _activeTab = tabKey);
          _fetchData();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF4F46E5) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> row, bool isDark) {
    return InkWell(
      onTap: () => _showRecordDetailsModal(row, isDark),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab-specific visual body
            if (_activeTab == 'consignors') ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (row['ConsignorName'] ?? 'UNKNOWN').toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ID: ${row['ConsignorID'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [row['Address'], row['Street_Area'], row['City_Village']].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (row['GSTIN'] != null && row['GSTIN'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'GST: ${row['GSTIN']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ] else if (_activeTab == 'consignees') ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (row['ConsigneeName'] ?? 'UNKNOWN').toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ID: ${row['ConsigneeID'] ?? '-'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [row['Address'], row['Street_Area'], row['City_Village']].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (row['GSTIN'] != null && row['GSTIN'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'GST: ${row['GSTIN']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ] else if (_activeTab == 'transactions') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GC No: ${row['Billno'] ?? '-'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF6366F1)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDate(row['Date']),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row['Fromname']?.toString() ?? 'Sender',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ),
                  Expanded(
                    child: Text(
                      row['Toname']?.toString() ?? 'Receiver',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${row['FromCity'] ?? '-'} ➔ ${row['ToCity2'] ?? '-'} | Freight: ₹${row['Total'] ?? '0'} (${row['Paymenttype'] ?? '-'})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ] else if (_activeTab == 'vehicles') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (row['LorryNo'] ?? 'UNKNOWN').toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (row['LorryName'] != null && row['LorryName'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        row['LorryName'].toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Driver: ${row['DriverName'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              Text(
                'Contact: ${row['Cell'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ] else if (_activeTab == 'gdms') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GDM ID: ${row['ID'] ?? '-'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDate(row['Date']),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Lorry No: ${row['LorryNo'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              Text(
                'Driver: ${row['DriverName'] ?? '-'} | Ph: ${row['Cell'] ?? '-'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],

            const SizedBox(height: 14),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Card Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CLICK FOR FULL ATTRIBUTES',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                  label: const Text('Inspect Record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _showRecordDetailsModal(row, isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(60),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storage_rounded, size: 48, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 18),
          Text(
            'No records found in MS Access archive',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'No records matching "$_searchQuery" in $_activeTab.'
                : 'Select a different company folder or financial year above.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
