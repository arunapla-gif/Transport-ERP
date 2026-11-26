import 'package:flutter/material.dart';
import '../models/godown.dart';
import '../services/api_service.dart';

class GodownMasterScreen extends StatefulWidget {
  const GodownMasterScreen({super.key});

  @override
  State<GodownMasterScreen> createState() => _GodownMasterScreenState();
}

class _GodownMasterScreenState extends State<GodownMasterScreen> {
  List<Godown> _godowns = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String _search = '';

  int? _editingId;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();

  static const Color _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _fetchGodowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _nameFocusNode.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchGodowns() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getGodowns();
      if (mounted) {
        setState(() {
          _godowns = res.map((e) => Godown.fromJson(Map<String, dynamic>.from(e))).toList();
        });
      }
    } catch (e) {
      _showToast('Failed to fetch Godowns', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim().toUpperCase();
    if (name.isEmpty) {
      _showToast('Godown name is required', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_editingId != null) {
        await ApiService.updateGodown(_editingId!, {'name': name});
        _showToast('Godown updated successfully');
      } else {
        await ApiService.createGodown({'name': name});
        _showToast('Godown added successfully');
      }
      _handleCancel();
      await _fetchGodowns();
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleEdit(Godown godown) {
    setState(() {
      _editingId = godown.id;
      _nameController.text = godown.name;
    });
    if (_pageScrollController.hasClients) {
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    _nameFocusNode.requestFocus();
  }

  Future<void> _handleDelete(Godown godown) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Godown?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to delete "${godown.name}"?',
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
      await ApiService.deleteGodown(godown.id);
      _showToast('Godown deleted successfully');
      if (_editingId == godown.id) _handleCancel();
      await _fetchGodowns();
    } catch (_) {
      _showToast('Failed to delete Godown. It might be used in GCs.', isError: true);
    }
  }

  void _handleCancel() {
    setState(() {
      _editingId = null;
      _nameController.clear();
    });
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          width: 400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final filteredGodowns = _godowns.where((g) {
      if (_search.trim().isEmpty) return true;
      return g.name.toLowerCase().contains(_search.trim().toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        controller: _pageScrollController,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 896), // max-w-4xl in React
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // FORM CARD (1:1 with React GodownMaster.jsx lines 99-147)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCBD5E1).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 16,
                          child: IgnorePointer(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 112,
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isDesktop = constraints.maxWidth >= 600;

                              final nameInput = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GODOWN NAME *',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _nameController,
                                      focusNode: _nameFocusNode,
                                      textCapitalization: TextCapitalization.characters,
                                      onChanged: (val) {
                                        final upper = val.toUpperCase();
                                        if (val != upper) {
                                          _nameController.value = _nameController.value.copyWith(
                                            text: upper,
                                            selection: TextSelection.collapsed(offset: upper.length),
                                          );
                                        }
                                      },
                                      onSubmitted: (_) => _handleSubmit(),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. Sivakasi Main Godown',
                                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
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
                                          borderSide: const BorderSide(color: _indigo, width: 1.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );

                              final buttonsRow = SizedBox(
                                height: 38,
                                child: Row(
                                  children: [
                                    if (_editingId != null) ...[
                                      OutlinedButton(
                                        onPressed: _handleCancel,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          foregroundColor: const Color(0xFF1E293B),
                                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isSaving ? null : _handleSubmit,
                                        icon: _isSaving
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : Icon(_editingId != null ? Icons.edit_outlined : Icons.add_rounded, size: 15),
                                        label: Text(
                                          _editingId != null ? 'Update Godown' : 'Add Godown',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _indigo,
                                          foregroundColor: Colors.white,
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE0E7FF)),
                                        ),
                                        child: const Icon(Icons.inventory_2_outlined, size: 20, color: _indigo),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Godown Master',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1E293B),
                                                letterSpacing: -0.4,
                                              ),
                                            ),
                                            SizedBox(height: 1),
                                            Text(
                                              'Manage storage locations and godowns',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  if (isDesktop)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(child: nameInput),
                                        const SizedBox(width: 16),
                                        Expanded(child: buttonsRow),
                                      ],
                                    )
                                  else ...[
                                    nameInput,
                                    const SizedBox(height: 12),
                                    buttonsRow,
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // LIST CARD (1:1 with React GodownMaster.jsx lines 150-204)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCBD5E1).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Godown List',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${filteredGodowns.length}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4338CA)),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 256,
                              height: 34,
                              child: TextField(
                                controller: _searchController,
                                onChanged: (v) => setState(() => _search = v),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                                decoration: InputDecoration(
                                  hintText: 'Search godowns...',
                                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Color(0xFF94A3B8)),
                                  suffixIcon: _search.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _search = '');
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          ],
                        ),
                      ),

                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text('S.NO', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                            ),
                            Expanded(
                              child: Text('GODOWN NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                            ),
                          ],
                        ),
                      ),

                      if (_isLoading && _godowns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(color: _indigo)),
                        )
                      else if (filteredGodowns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No godowns found.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredGodowns.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                          itemBuilder: (context, index) {
                            final g = filteredGodowns[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      g.name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF312E81)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
                                          tooltip: 'Edit',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          onPressed: () => _handleEdit(g),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFE11D48)),
                                          tooltip: 'Delete',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          onPressed: () => _handleDelete(g),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
