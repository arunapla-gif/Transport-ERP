import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CompanyMasterScreen extends StatefulWidget {
  const CompanyMasterScreen({super.key});

  @override
  State<CompanyMasterScreen> createState() => _CompanyMasterScreenState();
}

class _CompanyMasterScreenState extends State<CompanyMasterScreen> {
  List<Map<String, dynamic>> _companies = [];
  bool _isSaving = false;
  bool _isSearchingGst = false;

  int? _editingId;
  String _status = 'Active';

  final ScrollController _pageScrollController = ScrollController();
  final TextEditingController _searchGstinController = TextEditingController();
  final TextEditingController _tradeNameController = TextEditingController();
  final TextEditingController _legalNameController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  static const Color _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    _searchGstinController.dispose();
    _tradeNameController.dispose();
    _legalNameController.dispose();
    _gstinController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    try {
      final list = await ApiService.getCompanies();
      if (mounted) {
        setState(() {
          _companies = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSearchGst() async {
    final gstin = _searchGstinController.text.trim().toUpperCase();
    if (gstin.length != 15) {
      _showToast('Please enter a valid 15-digit GSTIN', isError: true);
      return;
    }

    setState(() => _isSearchingGst = true);
    try {
      final res = await ApiService.verifyGST(gstin);
      final taxpayer = res['taxpayerInfo'] is Map
          ? Map<String, dynamic>.from(res['taxpayerInfo'])
          : res;
      final Map<String, dynamic> addr = taxpayer['pradr'] is Map && taxpayer['pradr']['addr'] is Map
          ? Map<String, dynamic>.from(taxpayer['pradr']['addr'])
          : {};

      final fullAddr = [addr['bno'], addr['flno'], addr['bnm'], addr['st']]
          .where((s) => s != null && s.toString().trim().isNotEmpty)
          .map((s) => s.toString().trim())
          .join(', ');

      setState(() {
        _editingId = null;
        _gstinController.text = gstin;
        _tradeNameController.text =
            (taxpayer['tradeNam'] ?? taxpayer['tradeName'] ?? taxpayer['lgnm'] ?? '').toString();
        _legalNameController.text = (taxpayer['lgnm'] ?? taxpayer['legalName'] ?? '').toString();
        _addressController.text = fullAddr.isNotEmpty ? fullAddr : (taxpayer['address'] ?? '').toString();
        _cityController.text = (addr['loc'] ?? addr['city'] ?? taxpayer['city'] ?? '').toString();
        _districtController.text = (addr['dst'] ?? taxpayer['district'] ?? '').toString();
        _stateController.text = (addr['stcd'] ?? taxpayer['state'] ?? '').toString();
        _pincodeController.text = (addr['pncd'] ?? taxpayer['pincode'] ?? '').toString();
        _phoneController.clear();
        _emailController.clear();
        _status = (taxpayer['sts'] ?? taxpayer['status'] ?? 'Active').toString();
      });

      _showToast('GST Details Fetched Successfully!');
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSearchingGst = false);
    }
  }

  Future<void> _handleSave() async {
    final gstin = _gstinController.text.trim().toUpperCase();
    final tradeName = _tradeNameController.text.trim();
    if (gstin.isEmpty || tradeName.isEmpty) {
      _showToast('GSTIN and Trade Name are required', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'gstin': gstin,
        'tradeName': tradeName,
        'legalName': _legalNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'status': _status,
      };

      await ApiService.saveCompany(payload, id: _editingId);
      _showToast(_editingId != null ? 'Company updated successfully!' : 'Company added successfully!');
      _resetForm();
      await _fetchCompanies();
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleEdit(Map<String, dynamic> comp) {
    setState(() {
      _editingId = comp['id'] is int ? comp['id'] as int : int.tryParse(comp['id']?.toString() ?? '');
      _gstinController.text = (comp['gstin'] ?? '').toString();
      _searchGstinController.text = (comp['gstin'] ?? '').toString();
      _tradeNameController.text = (comp['tradeName'] ?? '').toString();
      _legalNameController.text = (comp['legalName'] ?? '').toString();
      _addressController.text = (comp['address'] ?? '').toString();
      _cityController.text = (comp['city'] ?? '').toString();
      _districtController.text = (comp['district'] ?? '').toString();
      _stateController.text = (comp['state'] ?? '').toString();
      _pincodeController.text = (comp['pincode'] ?? '').toString();
      _phoneController.text = (comp['phone'] ?? '').toString();
      _emailController.text = (comp['email'] ?? '').toString();
      _status = (comp['status'] ?? 'Active').toString();
    });

    if (_pageScrollController.hasClients) {
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> comp) async {
    final int? id = comp['id'] is int ? comp['id'] as int : int.tryParse(comp['id']?.toString() ?? '');
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Company?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to delete "${comp['tradeName']}"?',
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
      await ApiService.deleteCompany(id);
      _showToast('Company deleted successfully');
      if (_editingId == id) _resetForm();
      await _fetchCompanies();
    } catch (_) {
      _showToast('Failed to delete company', isError: true);
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _status = 'Active';
      _searchGstinController.clear();
      _tradeNameController.clear();
      _legalNameController.clear();
      _gstinController.clear();
      _cityController.clear();
      _districtController.clear();
      _stateController.clear();
      _pincodeController.clear();
      _addressController.clear();
      _phoneController.clear();
      _emailController.clear();
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
          width: 420,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Widget _field({
    String? label,
    required TextEditingController controller,
    String? placeholder,
    bool readOnly = false,
    bool highlightIndigo = false,
    bool uppercase = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlightIndigo ? FontWeight.w900 : FontWeight.w600,
              color: readOnly
                  ? const Color(0xFF64748B)
                  : (highlightIndigo ? const Color(0xFF312E81) : const Color(0xFF1E293B)),
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
              filled: true,
              fillColor: readOnly
                  ? const Color(0xFFF8FAFC)
                  : (highlightIndigo ? const Color(0xFFEEF2FF).withValues(alpha: 0.5) : Colors.white),
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
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // GST Search Box (1:1 with React CompanyMaster.jsx lines 169-192)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.search_rounded, size: 16, color: Color(0xFF6366F1)),
                          SizedBox(width: 8),
                          Text(
                            'Search Government Database',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _searchGstinController,
                                textCapitalization: TextCapitalization.characters,
                                onChanged: (val) {
                                  final u = val.toUpperCase();
                                  if (val != u) {
                                    _searchGstinController.value = _searchGstinController.value.copyWith(
                                      text: u,
                                      selection: TextSelection.collapsed(offset: u.length),
                                    );
                                  }
                                },
                                onSubmitted: (_) => _handleSearchGst(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter 15-digit GSTIN',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
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
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _isSearchingGst ? null : _handleSearchGst,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _indigo,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                _isSearchingGst ? 'Fetching...' : 'Fetch',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fetches Legal Name, Address, and Status directly from NIC/WhiteBooks.',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Form Card (1:1 with React CompanyMaster.jsx lines 195-225)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(label: 'Trade Name', controller: _tradeNameController, highlightIndigo: true),
              const SizedBox(height: 14),
              _field(label: 'Legal Name', controller: _legalNameController),
              const SizedBox(height: 14),
              _field(
                label: 'GSTIN',
                controller: _gstinController,
                readOnly: _editingId != null,
                uppercase: true,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field(label: 'City', controller: _cityController)),
                  const SizedBox(width: 14),
                  Expanded(child: _field(label: 'District', controller: _districtController)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field(label: 'State', controller: _stateController)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _field(
                      label: 'Pincode',
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(label: 'Address', controller: _addressController),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      label: 'Phone (Optional)',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _field(
                      label: 'Email (Optional)',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _resetForm,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(
                          _editingId != null ? 'Update Company' : 'Save Company',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            child: Text(
              'Saved Companies (${_companies.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final double tableWidth = constraints.maxWidth < 560 ? 560 : constraints.maxWidth;
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
                            SizedBox(width: 48, child: Text('S.NO', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                            Expanded(flex: 4, child: Text('TRADE NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                            Expanded(flex: 3, child: Text('GSTIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                            Expanded(flex: 2, child: Text('CITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                            SizedBox(width: 90, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                          ],
                        ),
                      ),
                      if (_companies.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No companies saved yet.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _companies.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final comp = _companies[index];
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
                                    flex: 4,
                                    child: Text(
                                      comp['tradeName']?.toString() ?? '-',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      comp['gstin']?.toString() ?? '-',
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      comp['city']?.toString() ?? '-',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                          tooltip: 'Edit',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          onPressed: () => _handleEdit(comp),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                                          tooltip: 'Delete',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          onPressed: () => _handleDelete(comp),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        controller: _pageScrollController,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER (1:1 with React CompanyMaster.jsx lines 151-161)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business_rounded, size: 24, color: Color(0xFF4338CA)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Company Master',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage your own Transport Companies and Billing Entities (AP, BELL, etc.)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 5/7 RESPONSIVE SPLIT (1:1 with React CompanyMaster.jsx lines 163-274)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 960) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildLeftColumn()),
                          const SizedBox(width: 24),
                          Expanded(flex: 7, child: _buildRightTable()),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLeftColumn(),
                        const SizedBox(height: 24),
                        _buildRightTable(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
