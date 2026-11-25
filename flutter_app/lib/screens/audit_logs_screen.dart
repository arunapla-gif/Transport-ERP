import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _actionFilter = 'ALL';
  String _entityFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getAuditLogs(
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        action: _actionFilter != 'ALL' ? _actionFilter : null,
      );
      if (mounted) {
        setState(() {
          _logs = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
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
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute:$second';
    } catch (_) {
      return raw.toString();
    }
  }

  Map<String, dynamic> _getActionColor(String? action) {
    switch ((action ?? '').toUpperCase()) {
      case 'CREATE':
        return {
          'bg': const Color(0xFFECFDF5),
          'border': const Color(0xFFA7F3D0),
          'text': const Color(0xFF065F46),
          'icon': Icons.add_circle_outline_rounded,
        };
      case 'UPDATE':
        return {
          'bg': const Color(0xFFFFFBEB),
          'border': const Color(0xFFFDE68A),
          'text': const Color(0xFF92400E),
          'icon': Icons.edit_note_rounded,
        };
      case 'DELETE':
        return {
          'bg': const Color(0xFFFFF1F2),
          'border': const Color(0xFFFECDD3),
          'text': const Color(0xFF9F1239),
          'icon': Icons.delete_forever_rounded,
        };
      default:
        return {
          'bg': const Color(0xFFF1F5F9),
          'border': const Color(0xFFCBD5E1),
          'text': const Color(0xFF334155),
          'icon': Icons.info_outline_rounded,
        };
    }
  }

  void _showLogDetailModal(Map<String, dynamic> log) {
    final actionColor = _getActionColor(log['action']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 680,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: actionColor['bg'] as Color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: actionColor['border'] as Color),
                    ),
                    child: Icon(actionColor['icon'] as IconData, color: actionColor['text'] as Color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(log['action'] ?? 'ACTION').toString().toUpperCase()} • ${log['entity'] ?? 'Record'} #${log['entityId'] ?? ''}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Timestamp: ${_formatDateTime(log['createdAt'])}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Actor Meta Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PERFORMED BY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            log['username']?.toString() ?? 'SYSTEM',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('USER ROLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            (log['userRole'] ?? 'USER').toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BRANCH LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            log['userBranch']?.toString() ?? 'MAIN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Change Details & Payload Payload:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.3),
              ),
              const SizedBox(height: 10),

              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      log['details']?.toString() ?? 'No extra details recorded.',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
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

    final filtered = _logs.where((log) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          (log['username']?.toString().toLowerCase().contains(q) ?? false) ||
          (log['entity']?.toString().toLowerCase().contains(q) ?? false) ||
          (log['entityId']?.toString().toLowerCase().contains(q) ?? false) ||
          (log['details']?.toString().toLowerCase().contains(q) ?? false);

      final act = log['action']?.toString().toUpperCase() ?? '';
      final matchesAction = _actionFilter == 'ALL' || act == _actionFilter;

      final ent = log['entity']?.toString().toUpperCase() ?? '';
      final matchesEntity = _entityFilter == 'ALL' || ent == _entityFilter;

      return matchesSearch && matchesAction && matchesEntity;
    }).toList();

    int createCount = 0;
    int updateCount = 0;
    int deleteCount = 0;
    for (var l in _logs) {
      final act = (l['action'] ?? '').toString().toUpperCase();
      if (act == 'CREATE') createCount++;
      if (act == 'UPDATE') updateCount++;
      if (act == 'DELETE') deleteCount++;
    }

    // Extract available entity tags
    final entitySet = <String>{};
    for (var l in _logs) {
      final ent = (l['entity'] ?? '').toString().toUpperCase().trim();
      if (ent.isNotEmpty) entitySet.add(ent);
    }
    final entityList = entitySet.toList()..sort();

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

                      // Top Metrics Grid
                      _buildMetricsGrid(createCount, updateCount, deleteCount),
                      const SizedBox(height: 20),

                      // Search & Action Filter Controls
                      _buildSearchAndFilters(isDark, entityList, filtered.length),
                      const SizedBox(height: 16),

                      // Main Table / Cards
                      _buildLogsTableContainer(isDark, filtered),

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
                  child: const Icon(Icons.security_rounded, color: Colors.white, size: 28),
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
                            'System Audit Trails',
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
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF34D399)),
                                SizedBox(width: 4),
                                Text(
                                  'COMPLIANCE MONITOR',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
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
                        'Immutable activity logs tracking creates, edits, and deletions across all ERP modules',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _fetchLogs,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh Logs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(int createCount, int updateCount, int deleteCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        final metrics = [
          {
            'label': 'Total Events',
            'value': '${_logs.length}',
            'sub': 'All Operations',
            'icon': Icons.history_edu_rounded,
            'color': const Color(0xFF6366F1),
            'bg': const Color(0xFFEEF2FF),
            'border': const Color(0xFFC7D2FE),
          },
          {
            'label': 'Created Records',
            'value': '$createCount',
            'sub': 'New Additions',
            'icon': Icons.add_circle_outline_rounded,
            'color': const Color(0xFF10B981),
            'bg': const Color(0xFFECFDF5),
            'border': const Color(0xFFA7F3D0),
          },
          {
            'label': 'Updated Records',
            'value': '$updateCount',
            'sub': 'Modified Values',
            'icon': Icons.edit_note_rounded,
            'color': const Color(0xFFF59E0B),
            'bg': const Color(0xFFFFFBEB),
            'border': const Color(0xFFFDE68A),
          },
          {
            'label': 'Deleted Records',
            'value': '$deleteCount',
            'sub': 'Purged / Removed',
            'icon': Icons.delete_forever_rounded,
            'color': const Color(0xFFE11D48),
            'bg': const Color(0xFFFFF1F2),
            'border': const Color(0xFFFECDD3),
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

  Widget _buildSearchAndFilters(bool isDark, List<String> entityList, int matchCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _fetchLogs();
                            },
                          )
                        : null,
                    hintText: 'Search by entity, ID, user, branch, or action payload...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  onSubmitted: (_) => _fetchLogs(),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Action Filter Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildActionChip('ALL', 'All Actions'),
                  _buildActionChip('CREATE', 'Creates'),
                  _buildActionChip('UPDATE', 'Updates'),
                  _buildActionChip('DELETE', 'Deletes'),
                ],
              ),
            ),
          ],
        ),

        // Entity filter chips row
        if (entityList.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Module:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                _buildEntityChip('ALL', 'All Modules'),
                ...entityList.map((e) => _buildEntityChip(e, e)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $matchCount audit records',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const Text(
                'Click row to view full details payload',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionChip(String code, String label) {
    final isSelected = _actionFilter == code;
    return InkWell(
      onTap: () {
        setState(() => _actionFilter = code);
        _fetchLogs();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildEntityChip(String code, String label) {
    final isSelected = _entityFilter == code;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _entityFilter = code),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsTableContainer(bool isDark, List<dynamic> filtered) {
    return Container(
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
          : filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.manage_search_rounded, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.7)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty ? 'No audit trails recorded yet.' : 'No audit logs found matching your filters.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 28,
                    headingRowHeight: 48,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 66,
                    headingTextStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                    columns: const [
                      DataColumn(label: Text('TIMESTAMP')),
                      DataColumn(label: Text('USER & BRANCH')),
                      DataColumn(label: Text('ACTION')),
                      DataColumn(label: Text('MODULE / RECORD')),
                      DataColumn(label: Text('DETAILS PREVIEW')),
                      DataColumn(label: Text('INSPECT')),
                    ],
                    rows: filtered.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final log = entry.value as Map<String, dynamic>;
                      final actionColor = _getActionColor(log['action']);
                      final role = (log['userRole']?.toString() ?? 'SYSTEM').toLowerCase();

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
                          // Timestamp
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDateTime(log['createdAt']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // User & Branch
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: 14,
                                      color: role == 'admin' ? const Color(0xFF6366F1) : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      log['username']?.toString() ?? log['userRole']?.toString().toUpperCase() ?? 'SYSTEM',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${log['userBranch'] ?? "MAIN"} • ${(log['userRole'] ?? "USER").toString().toUpperCase()}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          // Action
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: actionColor['bg'] as Color,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: actionColor['border'] as Color),
                              ),
                              child: Text(
                                (log['action']?.toString() ?? 'ACTION').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: actionColor['text'] as Color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          // Entity & Record
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (log['entity']?.toString() ?? 'RECORD').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '#${log['entityId'] ?? "-"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Details Preview
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  log['details']?.toString() ?? 'No details provided.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Inspect
                          DataCell(
                            IconButton(
                              tooltip: 'Inspect details payload',
                              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF6366F1)),
                              onPressed: () => _showLogDetailModal(log),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
