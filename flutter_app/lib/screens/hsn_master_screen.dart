import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class HSNMasterScreen extends StatefulWidget {
  const HSNMasterScreen({super.key});

  @override
  State<HSNMasterScreen> createState() => _HSNMasterScreenState();
}

class _HSNMasterScreenState extends State<HSNMasterScreen> {
  List<Map<String, dynamic>> _hsnList = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _fetchHsnList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHsnList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getHsnList();
      if (mounted) {
        setState(() {
          _hsnList = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch HSN records.';
          _isLoading = false;
        });
      }
    }
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

  Future<void> _handleDelete(Map<String, dynamic> item) async {
    final int? id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete HSN Code?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to delete HSN "${item['hsnCode']}"?',
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
      await ApiService.deleteHsn(id);
      _showToast('HSN Code deleted successfully');
      _fetchHsnList();
    } catch (e) {
      _showToast('Failed to delete HSN', isError: true);
    }
  }

  Future<void> _openModal([Map<String, dynamic>? item]) async {
    setState(() => _error = null);
    final int? editingId = item != null
        ? (item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? ''))
        : null;
    final codeCtrl = TextEditingController(text: item?['hsnCode']?.toString() ?? '');
    final descCtrl = TextEditingController(text: item?['description']?.toString() ?? '');
    final rateCtrl = TextEditingController(text: (item?['gstRate'] ?? 18).toString());
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> submit() async {
              final hsnCode = codeCtrl.text.trim();
              final desc = descCtrl.text.trim();
              if (hsnCode.isEmpty || desc.isEmpty) return;

              setModalState(() => saving = true);
              try {
                final payload = {
                  'hsnCode': hsnCode,
                  'description': desc,
                  'gstRate': double.tryParse(rateCtrl.text.trim()) ?? 0,
                };
                if (editingId != null) {
                  await ApiService.updateHsn(editingId, payload);
                } else {
                  await ApiService.createHsn(payload);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _showToast('HSN Code saved successfully');
                _fetchHsnList();
              } catch (e) {
                setModalState(() => saving = false);
                if (mounted) {
                  setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
                }
                _showToast('Failed to save HSN', isError: true);
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
                          const Text(
                            'Manage HSN Code',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HSN CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: codeCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            decoration: _modalDeco('e.g. 3604'),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Numbers only. Enter exact 4, 6, or 8 digit code.',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 14),
                          const Text('GOODS DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: descCtrl,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            decoration: _modalDeco('e.g. Fireworks and Crackers'),
                          ),
                          const SizedBox(height: 14),
                          const Text('TOTAL GST RATE (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            decoration: _modalDeco('e.g. 18').copyWith(
                              suffixText: '%',
                              suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                            ),
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
                                        : const Text('Save HSN', style: TextStyle(fontWeight: FontWeight.w700)),
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

    codeCtrl.dispose();
    descCtrl.dispose();
    rateCtrl.dispose();
  }

  InputDecoration _modalDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final filteredList = _hsnList.where((h) {
      if (q.isEmpty) return true;
      return (h['hsnCode']?.toString().toLowerCase().contains(q) ?? false) ||
          (h['description']?.toString().toLowerCase().contains(q) ?? false);
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
                // HEADER (1:1 with React HSNMaster.jsx lines 80-91)
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
                              'HSN Tax Master',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage HSN Codes and GST Rates for accurate E-Way Bill generation.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openModal(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add New HSN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

                // TABLE CARD (1:1 with React HSNMaster.jsx lines 99-154)
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
                                hintText: 'Search HSN or Description...',
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
                            child: Text('Loading HSN codes...', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double tableWidth = constraints.maxWidth < 640 ? 640 : constraints.maxWidth;
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
                                          Expanded(flex: 2, child: Text('HSN CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          Expanded(flex: 4, child: Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          Expanded(flex: 2, child: Text('GST RATE (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                          SizedBox(width: 90, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                        ],
                                      ),
                                    ),
                                    if (filteredList.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Center(
                                          child: Text('No HSN records found.', style: TextStyle(color: Color(0xFF64748B))),
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: filteredList.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (context, index) {
                                          final item = filteredList[index];
                                          final num rawRate = num.tryParse(item['gstRate']?.toString() ?? '0') ?? 0;
                                          final String rateText = rawRate == rawRate.roundToDouble()
                                              ? '${rawRate.toInt()}%'
                                              : '$rawRate%';

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
                                                  child: Text(
                                                    item['hsnCode']?.toString() ?? '-',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      fontFamily: 'monospace',
                                                      color: Color(0xFF4338CA),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    (item['description']?.toString().trim().isNotEmpty == true)
                                                        ? item['description'].toString()
                                                        : '-',
                                                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFD1FAE5),
                                                        borderRadius: BorderRadius.circular(14),
                                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                                      ),
                                                      child: Text(
                                                        rateText,
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                                                      ),
                                                    ),
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
                                                        onPressed: () => _openModal(item),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                                                        tooltip: 'Delete',
                                                        constraints: const BoxConstraints(),
                                                        padding: const EdgeInsets.all(6),
                                                        onPressed: () => _handleDelete(item),
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
