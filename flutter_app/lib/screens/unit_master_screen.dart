import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/unit_model.dart';
import '../services/api_service.dart';

class UnitMasterScreen extends StatefulWidget {
  const UnitMasterScreen({super.key});

  @override
  State<UnitMasterScreen> createState() => _UnitMasterScreenState();
}

class _UnitMasterScreenState extends State<UnitMasterScreen> {
  List<UnitModel> _units = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  bool _isGridView = false;
  String? _errorMessage;

  final List<String> _categories = [
    'Cases',
    'Cartons',
    'Bundles',
    'Boxes',
    'Drums',
    'Other',
  ];

  final List<Map<String, dynamic>> _colorOptions = const [
    {
      'name': 'slate',
      'label': 'Slate Gray',
      'color': Color(0xFF64748B),
      'bg': Color(0xFFF1F5F9),
      'border': Color(0xFFCBD5E1),
      'text': Color(0xFF334155),
    },
    {
      'name': 'emerald',
      'label': 'Emerald',
      'color': Color(0xFF10B981),
      'bg': Color(0xFFECFDF5),
      'border': Color(0xFFA7F3D0),
      'text': Color(0xFF065F46),
    },
    {
      'name': 'amber',
      'label': 'Amber',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB),
      'border': Color(0xFFFDE68A),
      'text': Color(0xFF92400E),
    },
    {
      'name': 'rose',
      'label': 'Rose',
      'color': Color(0xFFF43F5E),
      'bg': Color(0xFFFFF1F2),
      'border': Color(0xFFFECDD3),
      'text': Color(0xFF9F1239),
    },
    {
      'name': 'blue',
      'label': 'Blue',
      'color': Color(0xFF3B82F6),
      'bg': Color(0xFFEFF6FF),
      'border': Color(0xFFBFDBFE),
      'text': Color(0xFF1E40AF),
    },
    {
      'name': 'indigo',
      'label': 'Indigo',
      'color': Color(0xFF6366F1),
      'bg': Color(0xFFEEF2FF),
      'border': Color(0xFFC7D2FE),
      'text': Color(0xFF3730A3),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  Future<void> _fetchUnits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await ApiService.getUnits();
      if (mounted) {
        setState(() {
          _units = data;
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

  Future<void> _deleteUnit(UnitModel unit) async {
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
            const Expanded(
              child: Text(
                'Delete Unit Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${unit.description}" (${unit.code})?\nThis might affect existing templates using this unit code.',
          style: const TextStyle(color: Color(0xFF475569), height: 1.5, fontSize: 13),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Unit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteUnit(unit.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unit "${unit.description}" deleted successfully'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _fetchUnits();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _openUnitDialog([UnitModel? unit]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UnitDialog(
        unit: unit,
        categories: _categories,
        colorOptions: _colorOptions,
        onSaved: () {
          _fetchUnits();
        },
      ),
    );
  }

  void _showUnitInspectionModal(UnitModel unit, bool isDark) {
    final colorConfig = _getColorConfig(unit.color);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: (colorConfig['bg'] as Color),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: (colorConfig['border'] as Color), width: 1.5),
                      ),
                      child: Text(
                        unit.code,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: (colorConfig['text'] as Color),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unit.description,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Category: ${unit.category}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInspectionTile(
                        label: 'DEFAULT HSN CODE',
                        value: unit.hsn?.isNotEmpty == true ? unit.hsn! : 'Not Configured',
                        icon: Icons.tag_rounded,
                        isDark: isDark,
                        isMonospace: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInspectionTile(
                        label: 'DEFAULT GOODS DESC',
                        value: unit.goodsDesc?.isNotEmpty == true ? unit.goodsDesc! : 'Not Configured',
                        icon: Icons.inventory_2_outlined,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openUnitDialog(unit);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Unit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: unit.code));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unit code "${unit.code}" copied to clipboard!'),
                              backgroundColor: const Color(0xFF4F46E5),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInspectionTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    bool isMonospace = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: isMonospace ? 'monospace' : null,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getColorConfig(String colorName) {
    return _colorOptions.firstWhere(
      (c) => c['name'] == colorName.toLowerCase(),
      orElse: () => _colorOptions[0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredUnits = _units.where((u) {
      final matchesCategory = _selectedCategoryFilter == 'All' || u.category == _selectedCategoryFilter;
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          u.category.toLowerCase().contains(q) ||
          u.description.toLowerCase().contains(q) ||
          u.code.toLowerCase().contains(q) ||
          (u.hsn?.toLowerCase().contains(q) ?? false) ||
          (u.goodsDesc?.toLowerCase().contains(q) ?? false);
      return matchesCategory && matchesSearch;
    }).toList();

    final totalCategories = _units.map((u) => u.category).toSet().length;
    final hsnMappedUnits = _units.where((u) => u.hsn?.trim().isNotEmpty == true).length;
    final goodsMappedUnits = _units.where((u) => u.goodsDesc?.trim().isNotEmpty == true).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Executive Cockpit Header
            _buildCockpitHeader(
              isDark: isDark,
              totalUnits: _units.length,
              totalCategories: totalCategories,
              hsnMappedUnits: hsnMappedUnits,
              goodsMappedUnits: goodsMappedUnits,
            ),

            // Main Body Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error Banner if present
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
                                  style: const TextStyle(color: Color(0xFF9F1239), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFF9F1239)),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Filter Bar & Controls
                      _buildToolbar(
                        isDark: isDark,
                        filteredCount: filteredUnits.length,
                        totalCount: _units.length,
                      ),
                      const SizedBox(height: 18),

                      // Category Pills Carousel
                      _buildCategoryFilterRow(isDark: isDark),
                      const SizedBox(height: 20),

                      // Content: Table or Grid
                      if (_isLoading)
                        Container(
                          height: 320,
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
                              const SizedBox(height: 16),
                              Text(
                                'Loading packaging master...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (filteredUnits.isEmpty)
                        _buildEmptyState(isDark)
                      else if (_isGridView)
                        _buildGridView(filteredUnits, isDark)
                      else
                        _buildTableView(filteredUnits, isDark),

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
    required int totalUnits,
    required int totalCategories,
    required int hsnMappedUnits,
    required int goodsMappedUnits,
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
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isCompactHeader = headerConstraints.maxWidth < 650;
                  final badge = Container(
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
                          'MASTER REGISTRY // PACKAGING & GOODS UNITS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFFC7D2FE),
                          ),
                        ),
                      ],
                    ),
                  );

                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _fetchUnits,
                        tooltip: 'Refresh Units',
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _openUnitDialog(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add New Unit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  );

                  if (isCompactHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        badge,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      badge,
                      actions,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Title & Subtitle
              const Text(
                'Packaging Units & Standard Codes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage standardized packaging short codes, default HSN mappings, and color-coded tag pills for rapid GC counter bookings.',
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
                  final isCompact = constraints.maxWidth < 800;
                  return isCompact
                      ? Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildKpiCard(
                              title: 'TOTAL UNITS',
                              value: totalUnits.toString(),
                              subtitle: 'Active standard units',
                              icon: Icons.scale_rounded,
                              color: const Color(0xFF6366F1),
                            ),
                            _buildKpiCard(
                              title: 'CATEGORIES',
                              value: totalCategories.toString(),
                              subtitle: 'Distinct classifications',
                              icon: Icons.category_rounded,
                              color: const Color(0xFF3B82F6),
                            ),
                            _buildKpiCard(
                              title: 'HSN MAPPED',
                              value: hsnMappedUnits.toString(),
                              subtitle: 'Tax compliant units',
                              icon: Icons.verified_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            _buildKpiCard(
                              title: 'GOODS MAPPED',
                              value: goodsMappedUnits.toString(),
                              subtitle: 'Auto-fill commodity',
                              icon: Icons.auto_awesome_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'TOTAL UNITS',
                                value: totalUnits.toString(),
                                subtitle: 'Active standard units',
                                icon: Icons.scale_rounded,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'CATEGORIES',
                                value: totalCategories.toString(),
                                subtitle: 'Distinct classifications',
                                icon: Icons.category_rounded,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'HSN MAPPED',
                                value: hsnMappedUnits.toString(),
                                subtitle: 'Tax compliant units',
                                icon: Icons.verified_rounded,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'GOODS MAPPED',
                                value: goodsMappedUnits.toString(),
                                subtitle: 'Auto-fill commodity',
                                icon: Icons.auto_awesome_rounded,
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
                  style: const TextStyle(
                    fontSize: 20,
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

  Widget _buildToolbar({
    required bool isDark,
    required int filteredCount,
    required int totalCount,
  }) {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          final searchField = Container(
            height: 42,
            constraints: const BoxConstraints(maxWidth: 440),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                hintText: 'Search by category, code, HSN or description...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
            ),
          );

          final countBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Showing $filteredCount of $totalCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          );

          final viewToggle = Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Table View',
                  icon: Icon(
                    Icons.table_rows_rounded,
                    size: 18,
                    color: !_isGridView ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  ),
                  onPressed: () => setState(() => _isGridView = false),
                ),
                IconButton(
                  tooltip: 'Grid Card View',
                  icon: Icon(
                    Icons.grid_view_rounded,
                    size: 18,
                    color: _isGridView ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  ),
                  onPressed: () => setState(() => _isGridView = true),
                ),
              ],
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    countBadge,
                    viewToggle,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 14),
              countBadge,
              const SizedBox(width: 10),
              viewToggle,
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilterRow({required bool isDark}) {
    final allCategoryOptions = ['All', ..._categories];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: allCategoryOptions.map((cat) {
          final isSelected = _selectedCategoryFilter == cat;
          final count = cat == 'All' ? _units.length : _units.where((u) => u.category == cat).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedCategoryFilter = cat),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableView(List<UnitModel> units, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          horizontalMargin: 20,
          columnSpacing: 28,
          headingRowHeight: 48,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 60,
          headingTextStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
          columns: const [
            DataColumn(label: Text('S.NO', style: TextStyle(fontFamily: 'monospace'))),
            DataColumn(label: Text('CODE')),
            DataColumn(label: Text('DESCRIPTION')),
            DataColumn(label: Text('CATEGORY')),
            DataColumn(label: Text('DEFAULT HSN')),
            DataColumn(label: Text('DEFAULT GOODS')),
            DataColumn(label: Text('ACTIONS', textAlign: TextAlign.right)),
          ],
          rows: units.asMap().entries.map((entry) {
            final index = entry.key;
            final unit = entry.value;
            final colorConfig = _getColorConfig(unit.color);

            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC);
                }
                return index.isEven
                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                    : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFFAFAFA));
              }),
              cells: [
                DataCell(
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: unit.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied code "${unit.code}"'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (colorConfig['bg'] as Color),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: (colorConfig['border'] as Color)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            unit.code,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: (colorConfig['text'] as Color),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_rounded, size: 10, color: (colorConfig['text'] as Color).withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () => _showUnitInspectionModal(unit, isDark),
                    child: Text(
                      unit.description,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      unit.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    unit.hsn?.isNotEmpty == true ? unit.hsn! : '-',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    unit.goodsDesc?.isNotEmpty == true ? unit.goodsDesc! : '-',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                        color: const Color(0xFF64748B),
                        tooltip: 'View details',
                        splashRadius: 18,
                        onPressed: () => _showUnitInspectionModal(unit, isDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: const Color(0xFF6366F1),
                        tooltip: 'Edit Unit',
                        splashRadius: 18,
                        onPressed: () => _openUnitDialog(unit),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        color: const Color(0xFFE11D48),
                        tooltip: 'Delete Unit',
                        splashRadius: 18,
                        onPressed: () => _deleteUnit(unit),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGridView(List<UnitModel> units, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600
            ? 1
            : constraints.maxWidth < 950
                ? 2
                : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 190,
          ),
          itemCount: units.length,
          itemBuilder: (context, index) {
            final unit = units[index];
            final colorConfig = _getColorConfig(unit.color);

            return Container(
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (colorConfig['bg'] as Color),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (colorConfig['border'] as Color)),
                        ),
                        child: Text(
                          unit.code,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: (colorConfig['text'] as Color),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          unit.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    unit.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'HSN: ${unit.hsn?.isNotEmpty == true ? unit.hsn! : 'None'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('•', style: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          unit.goodsDesc?.isNotEmpty == true ? unit.goodsDesc! : 'No Default Goods',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                        color: const Color(0xFF64748B),
                        splashRadius: 16,
                        onPressed: () => _showUnitInspectionModal(unit, isDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        color: const Color(0xFF6366F1),
                        splashRadius: 16,
                        onPressed: () => _openUnitDialog(unit),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        color: const Color(0xFFE11D48),
                        splashRadius: 16,
                        onPressed: () => _deleteUnit(unit),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined, size: 40, color: const Color(0xFF94A3B8).withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No packaging units configured' : 'No units match your filter',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isEmpty
                ? 'Create standard packaging types (Cases, Cartons, Bundles) to speed up billing.'
                : 'Try adjusting your search criteria or category filter.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openUnitDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Packaging Unit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitDialog extends StatefulWidget {
  final UnitModel? unit;
  final List<String> categories;
  final List<Map<String, dynamic>> colorOptions;
  final VoidCallback onSaved;

  const _UnitDialog({
    required this.unit,
    required this.categories,
    required this.colorOptions,
    required this.onSaved,
  });

  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  late String _selectedColor;
  late TextEditingController _descriptionController;
  late TextEditingController _codeController;
  late TextEditingController _hsnController;
  late TextEditingController _goodsDescController;

  bool _isSaving = false;
  String? _dialogError;

  @override
  void initState() {
    super.initState();
    final u = widget.unit;
    _selectedCategory = u?.category ?? widget.categories.first;
    _selectedColor = u?.color ?? 'slate';
    _descriptionController = TextEditingController(text: u?.description ?? '');
    _codeController = TextEditingController(text: u?.code ?? '');
    _hsnController = TextEditingController(text: u?.hsn ?? '');
    _goodsDescController = TextEditingController(text: u?.goodsDesc ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _codeController.dispose();
    _hsnController.dispose();
    _goodsDescController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _dialogError = null;
    });

    final payload = {
      'category': _selectedCategory,
      'description': _descriptionController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'color': _selectedColor,
      'hsn': _hsnController.text.trim(),
      'goodsDesc': _goodsDescController.text.trim(),
    };

    try {
      await ApiService.saveUnit(payload, id: widget.unit?.id);
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.unit != null ? 'Unit updated successfully' : 'New unit created successfully'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final isEditing = widget.unit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                              color: const Color(0xFF6366F1),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Packaging Unit' : 'New Packaging Unit',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Configure short code and commodity links',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
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
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  if (_dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dialogError!,
                              style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Category & Short Code Row
                  LayoutBuilder(
                    builder: (context, rowConstraints) {
                      final isNarrow = rowConstraints.maxWidth < 440;
                      final categoryField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CATEGORY *',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: _inputDecoration(isDark),
                            items: widget.categories.map((c) {
                              return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                        ],
                      );

                      final shortCodeField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SHORT CODE *',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _inputDecoration(isDark, hint: 'e.g. C/S'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            categoryField,
                            const SizedBox(height: 14),
                            shortCodeField,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: categoryField),
                          const SizedBox(width: 14),
                          Expanded(flex: 2, child: shortCodeField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Description
                  const Text(
                    'DESCRIPTION *',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _inputDecoration(isDark, hint: 'e.g. Cases of Industrial Goods'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Color Picker Swatches
                  const Text(
                    'BADGE COLOR ACCENT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.colorOptions.map((opt) {
                      final isSelected = _selectedColor == opt['name'];
                      return InkWell(
                        onTap: () => setState(() => _selectedColor = opt['name']),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (opt['color'] as Color).withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? (opt['color'] as Color) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: opt['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (opt['color'] as Color)
                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.check_rounded, size: 14, color: opt['color'] as Color),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Default HSN & Goods Desc
                  LayoutBuilder(
                    builder: (context, rowConstraints) {
                      final isNarrow = rowConstraints.maxWidth < 440;
                      final hsnField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DEFAULT HSN CODE',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _hsnController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(isDark, hint: 'e.g. 36041000'),
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                          ),
                        ],
                      );

                      final goodsDescField = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DEFAULT GOODS DESC',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _goodsDescController,
                            decoration: _inputDecoration(isDark, hint: 'e.g. FIREWORKS'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            hsnField,
                            const SizedBox(height: 14),
                            goodsDescField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: hsnField),
                          const SizedBox(width: 14),
                          Expanded(child: goodsDescField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Actions
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
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
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
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  isEditing ? 'Update Unit' : 'Create Unit',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
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
