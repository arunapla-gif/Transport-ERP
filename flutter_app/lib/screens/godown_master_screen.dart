import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/godown.dart';

class GodownMasterScreen extends StatefulWidget {
  const GodownMasterScreen({super.key});

  @override
  State<GodownMasterScreen> createState() => _GodownMasterScreenState();
}

class _GodownMasterScreenState extends State<GodownMasterScreen> {
  List<Godown> _godowns = [];
  bool _isLoading = false;
  String _searchTerm = '';

  int? _editingId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _fetchGodowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGodowns() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiService.getGodowns();
      if (mounted) {
        setState(() {
          _godowns = res.map((e) => Godown.fromJson(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load godown facilities: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim().toUpperCase();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid Godown / Warehouse Name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final payload = {'name': name};

      if (_editingId != null) {
        await ApiService.updateGodown(_editingId!, payload);
        setState(() {
          _successMessage = 'Godown facility "$name" updated successfully!';
        });
      } else {
        await ApiService.createGodown(payload);
        setState(() {
          _successMessage = 'New Godown facility "$name" registered successfully!';
        });
      }

      _clearForm();
      await _fetchGodowns();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save record: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleEdit(Godown g) {
    setState(() {
      _editingId = g.id;
      _nameController.text = g.name;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _handleDelete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Godown Facility', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$name"? Godowns with active stock cannot be deleted.',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ApiService.deleteGodown(id);
      setState(() {
        _successMessage = 'Godown facility "$name" removed successfully.';
      });
      if (_editingId == id) _clearForm();
      await _fetchGodowns();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to delete godown (it may be in use by active consignments or stock): $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
    });
  }

  Widget _buildSwissCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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

  @override
  Widget build(BuildContext context) {
    final filteredGodowns = _godowns.where((g) {
      if (_searchTerm.isEmpty) return true;
      final term = _searchTerm.toLowerCase().trim();
      return g.name.toLowerCase().contains(term) || g.id.toString().contains(term);
    }).toList();

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
          ),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFEEF2F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Cockpit
                  _buildHeaderCockpit(),

                  const SizedBox(height: 18),

                  // 2. Alert Messages
                  if (_errorMessage != null) ...[
                    _buildAlertBanner(
                      icon: Icons.error_outline_rounded,
                      message: _errorMessage!,
                      color: const Color(0xFFBE123C),
                      bg: const Color(0xFFFFE4E6),
                      border: const Color(0xFFFECDD3),
                      onClose: () => setState(() => _errorMessage = null),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_successMessage != null) ...[
                    _buildAlertBanner(
                      icon: Icons.check_circle_outline_rounded,
                      message: _successMessage!,
                      color: const Color(0xFF047857),
                      bg: const Color(0xFFD1FAE5),
                      border: const Color(0xFFA7F3D0),
                      onClose: () => setState(() => _successMessage = null),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 3. KPI Metrics Row
                  _buildMetricsRow(filteredGodowns.length),

                  const SizedBox(height: 20),

                  // 4. Facility Form Card
                  _buildFacilityFormCard(),

                  const SizedBox(height: 20),

                  // 5. Facility Directory List Card
                  _buildFacilityDirectoryCard(filteredGodowns),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCockpit() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;

          final titleRow = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GODOWN & WAREHOUSE FACILITIES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configure storage bays, transit godowns, and parcel dispatch centers.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionsRow = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded, color: Color(0xFFFCD34D), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_godowns.length} FACILITIES',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _fetchGodowns,
                icon: _isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                const SizedBox(height: 14),
                actionsRow,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleRow),
              const SizedBox(width: 16),
              actionsRow,
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertBanner({
    required IconData icon,
    required String message,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: color),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(int matchCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 440;
        final isNarrow = constraints.maxWidth < 650;
        final cardWidth = isMobile
            ? constraints.maxWidth
            : (isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 24) / 3);

        final metrics = [
          {
            'label': 'TOTAL GODOWN HUBS',
            'value': '${_godowns.length}',
            'sub': 'Configured nationwide',
            'icon': Icons.home_work_rounded,
            'color': const Color(0xFFD97706),
            'bg': const Color(0xFFFFFBEB),
          },
          {
            'label': 'SEARCH MATCHES',
            'value': '$matchCount',
            'sub': _searchTerm.isEmpty ? 'All records active' : 'Filter active',
            'icon': Icons.filter_alt_rounded,
            'color': const Color(0xFF2563EB),
            'bg': const Color(0xFFEFF6FF),
          },
          {
            'label': 'ACTIVE MODE',
            'value': _editingId != null ? 'EDITING #$_editingId' : 'REGISTER NEW',
            'sub': _editingId != null ? 'Update selected record' : 'Ready for input',
            'icon': _editingId != null ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
            'color': _editingId != null ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
            'bg': _editingId != null ? const Color(0xFFF5F3FF) : const Color(0xFFECFDF5),
          },
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((m) {
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                        m['label'] as String,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: m['bg'] as Color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m['value'] as String,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: m['color'] as Color,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m['sub'] as String,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
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

  Widget _buildFacilityFormCard() {
    return _buildSwissCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Icon(
                      _editingId != null ? Icons.edit_location_rounded : Icons.add_business_rounded,
                      color: const Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _editingId != null ? 'Edit Godown Facility #$_editingId' : 'Register New Godown Facility',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              if (_editingId != null)
                TextButton.icon(
                  onPressed: _clearForm,
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                  label: const Text('Cancel Edit', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              return Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: isNarrow ? 0 : 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GODOWN / WAREHOUSE FACILITY NAME *',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'e.g. SIVAKASI MAIN CENTRAL GODOWN',
                            prefixIcon: Icon(Icons.domain_rounded, size: 18, color: Color(0xFF94A3B8)),
                          ),
                          onSubmitted: (_) => _handleSave(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isNarrow ? 0 : 14, height: isNarrow ? 14 : 0),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleSave,
                      icon: _isLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_editingId != null ? Icons.save_rounded : Icons.add_rounded, size: 18),
                      label: Text(_editingId != null ? 'Update Facility' : 'Add Facility'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _editingId != null ? const Color(0xFF8B5CF6) : const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityDirectoryCard(List<Godown> godowns) {
    return _buildSwissCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrow = headerConstraints.maxWidth < 580;
                const title = Row(
                  children: [
                    Icon(Icons.list_alt_rounded, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'GODOWN FACILITIES DIRECTORY',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                    ),
                  ],
                );

                final searchBox = SizedBox(
                  width: isNarrow ? double.infinity : 260,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchTerm = val),
                    decoration: InputDecoration(
                      hintText: 'Search by facility name...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixIcon: _searchTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchTerm = '');
                              },
                            )
                          : null,
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      searchBox,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    title,
                    searchBox,
                  ],
                );
              },
            ),
          ),

          LayoutBuilder(
            builder: (context, tableConstraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableConstraints.maxWidth < 650 ? 650 : tableConstraints.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        color: const Color(0xFFF1F5F9),
                        child: const Row(
                          children: [
                            SizedBox(width: 50, child: Text('ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)))),
                            Expanded(flex: 4, child: Text('FACILITY / GODOWN NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)))),
                            Expanded(flex: 2, child: Text('OPERATIONAL STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)))),
                            SizedBox(width: 90, child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),

                      // List
                      if (_isLoading && _godowns.isEmpty)
                        const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
                        )
                      else if (godowns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                          child: Column(
                            children: [
                              Icon(Icons.warehouse_outlined, size: 48, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 12),
                              Text('No Godown Facilities Found', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569), fontSize: 15)),
                              SizedBox(height: 4),
                              Text('Register a new godown facility using the form above.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: godowns.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final g = godowns[index];
                            final isEditingThis = _editingId == g.id;

                            return Container(
                              color: isEditingThis ? const Color(0xFFFFFBEB) : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  // ID badge
                                  SizedBox(
                                    width: 50,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#${g.id}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF475569),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Facility Name
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.warehouse_rounded, color: Color(0xFFD97706), size: 16),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            g.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: isEditingThis ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 12),
                                              SizedBox(width: 4),
                                              Text(
                                                'ACTIVE STORAGE',
                                                style: TextStyle(
                                                  color: Color(0xFF065F46),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Actions
                                  SizedBox(
                                    width: 90,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                                          tooltip: 'Edit Godown',
                                          onPressed: () => _handleEdit(g),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                                          tooltip: 'Delete Godown',
                                          onPressed: () => _handleDelete(g.id, g.name),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
