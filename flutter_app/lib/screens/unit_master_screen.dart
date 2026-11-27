import 'package:flutter/material.dart';
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
  String? _error;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color _indigo = Color(0xFF4F46E5);

  static const List<String> _categories = [
    'Cases',
    'Cartons',
    'Bundles',
    'Boxes',
    'Drums',
    'Other',
  ];

  static const List<Map<String, dynamic>> _colors = [
    {
      'name': 'slate',
      'label': 'Gray',
      'bg': Color(0xFFF1F5F9),
      'text': Color(0xFF334155),
      'border': Color(0xFFE2E8F0),
    },
    {
      'name': 'emerald',
      'label': 'Green',
      'bg': Color(0xFFD1FAE5),
      'text': Color(0xFF047857),
      'border': Color(0xFFA7F3D0),
    },
    {
      'name': 'amber',
      'label': 'Yellow',
      'bg': Color(0xFFFEF3C7),
      'text': Color(0xFFB45309),
      'border': Color(0xFFFDE68A),
    },
    {
      'name': 'rose',
      'label': 'Red',
      'bg': Color(0xFFFFE4E6),
      'text': Color(0xFFBE123C),
      'border': Color(0xFFFECDD3),
    },
    {
      'name': 'blue',
      'label': 'Blue',
      'bg': Color(0xFFDBEAFE),
      'text': Color(0xFF1D4ED8),
      'border': Color(0xFFBFDBFE),
    },
    {
      'name': 'indigo',
      'label': 'Indigo',
      'bg': Color(0xFFE0E7FF),
      'text': Color(0xFF4338CA),
      'border': Color(0xFFC7D2FE),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUnits() async {
    setState(() {
      _isLoading = true;
      _error = null;
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
          _error = 'Failed to fetch units.';
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _resolveColor(String raw) {
    return _colors.firstWhere(
      (c) => c['name'] == raw.toLowerCase(),
      orElse: () => _colors.first,
    );
  }

  Future<void> _handleDelete(UnitModel unit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Unit?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to delete "${unit.description}" (${unit.code})?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ApiService.deleteUnit(unit.id);
      _fetchUnits();
    } catch (e) {
      setState(() => _error = 'Failed to delete unit.');
    }
  }

  Future<void> _openModal([UnitModel? unit]) async {
    setState(() => _error = null);
    String category = unit?.category ?? 'Cases';
    if (!_categories.contains(category)) category = 'Cases';
    String color = unit?.color ?? 'slate';
    if (!_colors.any((c) => c['name'] == color)) color = 'slate';

    final descCtrl = TextEditingController(text: unit?.description ?? '');
    final codeCtrl = TextEditingController(text: unit?.code ?? '');
    final hsnCtrl = TextEditingController(text: unit?.hsn ?? '');
    final goodsCtrl = TextEditingController(text: unit?.goodsDesc ?? '');
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> submit() async {
              if (descCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty) {
                return;
              }
              setModalState(() => saving = true);
              try {
                await ApiService.saveUnit(
                  {
                    'category': category,
                    'description': descCtrl.text.trim(),
                    'code': codeCtrl.text.trim().toUpperCase(),
                    'color': color,
                    'hsn': hsnCtrl.text.trim(),
                    'goodsDesc': goodsCtrl.text.trim(),
                  },
                  id: unit?.id,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchUnits();
              } catch (e) {
                setModalState(() => saving = false);
                if (mounted) {
                  setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            unit != null ? 'Edit Unit' : 'Add New Unit',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _modalLabel('CATEGORY'),
                          _modalDropdown(
                            value: category,
                            items: _categories
                                .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setModalState(() => category = v);
                            },
                          ),
                          const SizedBox(height: 14),
                          _modalLabel('DESCRIPTION'),
                          _modalInput(controller: descCtrl, hint: 'e.g. Cases of Fireworks'),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _modalLabel('SHORT CODE'),
                                    _modalInput(controller: codeCtrl, hint: 'e.g. C/S', uppercase: true),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _modalLabel('BADGE COLOR'),
                                    _modalDropdown(
                                      value: color,
                                      items: _colors
                                          .map((c) => DropdownMenuItem<String>(
                                                value: c['name'] as String,
                                                child: Text(c['label'] as String),
                                              ))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setModalState(() => color = v);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _modalLabel('DEFAULT HSN'),
                                    _modalInput(controller: hsnCtrl, hint: 'e.g. 36041000'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _modalLabel('DEFAULT GOODS DESC'),
                                    _modalInput(controller: goodsCtrl, hint: 'e.g. FIREWORKS'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.only(top: 14),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      foregroundColor: const Color(0xFF1E293B),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: saving ? null : submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _indigo,
                                      foregroundColor: Colors.white,
                                      elevation: 1,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Save Unit', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    descCtrl.dispose();
    codeCtrl.dispose();
    hsnCtrl.dispose();
    goodsCtrl.dispose();
  }

  Widget _modalLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
      ),
    );
  }

  Widget _modalInput({
    required TextEditingController controller,
    required String hint,
    bool uppercase = false,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
      onChanged: uppercase
          ? (val) {
              final u = val.toUpperCase();
              if (val != u) {
                controller.value = controller.value.copyWith(
                  text: u,
                  selection: TextSelection.collapsed(offset: u.length),
                );
              }
            }
          : null,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _indigo, width: 1.6),
        ),
      ),
    );
  }

  Widget _modalDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final filteredUnits = _units.where((u) {
      if (q.isEmpty) return true;
      return u.category.toLowerCase().contains(q) ||
          u.description.toLowerCase().contains(q) ||
          u.code.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1024), // max-w-5xl in React
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER (1:1 with React UnitMaster.jsx lines 109-120)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.settings_outlined, size: 24, color: _indigo),
                            SizedBox(width: 8),
                            Text(
                              'Unit Master',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage physical categories and descriptions for goods.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openModal(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add New Unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFBE123C)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFBE123C))),
                        ),
                      ],
                    ),
                  ),

                // TABLE CARD (1:1 with React UnitMaster.jsx lines 128-187)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() => _search = v),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                              decoration: InputDecoration(
                                hintText: 'Search units...',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: _indigo, width: 1.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('Loading units...', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double tableWidth = constraints.maxWidth < 760 ? 760 : constraints.maxWidth;
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      child: const Row(
                                        children: [
                                          SizedBox(width: 48, child: Text('S.NO', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          Expanded(flex: 2, child: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          Expanded(flex: 3, child: Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          Expanded(flex: 2, child: Text('SHORT CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          Expanded(flex: 2, child: Text('DEFAULT HSN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          Expanded(flex: 3, child: Text('DEFAULT GOODS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          SizedBox(width: 90, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                        ],
                                      ),
                                    ),
                                    if (filteredUnits.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Center(
                                          child: Text('No units found.', style: TextStyle(color: Color(0xFF64748B))),
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: filteredUnits.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (context, index) {
                                          final u = filteredUnits[index];
                                          final c = _resolveColor(u.color);
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 48,
                                                  child: Text(
                                                    '${index + 1}',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(u.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(u.description, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: c['bg'] as Color,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: c['border'] as Color),
                                                      ),
                                                      child: Text(
                                                        u.code,
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c['text'] as Color),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    (u.hsn?.trim().isNotEmpty == true) ? u.hsn! : '-',
                                                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF475569)),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    (u.goodsDesc?.trim().isNotEmpty == true) ? u.goodsDesc! : '-',
                                                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 90,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                                        tooltip: 'Edit',
                                                        constraints: const BoxConstraints(),
                                                        padding: const EdgeInsets.all(6),
                                                        onPressed: () => _openModal(u),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                                                        tooltip: 'Delete',
                                                        constraints: const BoxConstraints(),
                                                        padding: const EdgeInsets.all(6),
                                                        onPressed: () => _handleDelete(u),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
