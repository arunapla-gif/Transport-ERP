import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class CompanyMasterScreen extends StatefulWidget {
  const CompanyMasterScreen({super.key});

  @override
  State<CompanyMasterScreen> createState() => _CompanyMasterScreenState();
}

class _CompanyMasterScreenState extends State<CompanyMasterScreen> {
  List<dynamic> _companies = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearchingGst = false;

  String? _errorMessage;
  String? _successMessage;

  final TextEditingController _searchGstinController = TextEditingController();
  final TextEditingController _tradeNameController = TextEditingController();
  final TextEditingController _legalNameController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _tableSearchController = TextEditingController();

  int? _editingId;
  String _tableSearchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchGstinController.dispose();
    _tradeNameController.dispose();
    _legalNameController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tableSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.getCompanies();
      if (mounted) {
        setState(() {
          _companies = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to fetch companies: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGstSearch() async {
    final gstin = _searchGstinController.text.trim().toUpperCase();
    if (gstin.length != 15) {
      setState(() => _errorMessage = 'Please enter a valid 15-digit GSTIN');
      return;
    }

    setState(() {
      _isSearchingGst = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await ApiService.verifyGST(gstin);
      final taxpayer = res['taxpayerInfo'] ?? res;
      final addr = taxpayer['pradr']?['addr'] ?? {};

      if (mounted) {
        setState(() {
          _gstinController.text = gstin;
          _tradeNameController.text = taxpayer['tradeNam'] ?? taxpayer['tradeName'] ?? taxpayer['lgnm'] ?? '';
          _legalNameController.text = taxpayer['lgnm'] ?? taxpayer['legalName'] ?? '';
          _cityController.text = addr['loc'] ?? addr['city'] ?? taxpayer['city'] ?? '';
          _districtController.text = addr['dst'] ?? taxpayer['district'] ?? '';
          _stateController.text = addr['stcd'] ?? taxpayer['state'] ?? '';
          _pincodeController.text = addr['pncd'] ?? taxpayer['pincode'] ?? '';

          final bno = addr['bno'] ?? '';
          final bnm = addr['bnm'] ?? '';
          final st = addr['st'] ?? '';
          final flno = addr['flno'] ?? '';
          final fullAddr = [bno, flno, bnm, st].where((s) => s.toString().isNotEmpty).join(', ');
          _addressController.text = fullAddr.isNotEmpty ? fullAddr : (taxpayer['address'] ?? '');

          _successMessage = 'GST credentials verified from government GSTIN registry!';
          _isSearchingGst = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'GST search failed: $e';
          _isSearchingGst = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final tradeName = _tradeNameController.text.trim();
    final gstin = _gstinController.text.trim().toUpperCase();

    if (tradeName.isEmpty || gstin.isEmpty) {
      setState(() => _errorMessage = 'Trade Name and GSTIN are required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final payload = {
      'tradeName': tradeName,
      'legalName': _legalNameController.text.trim(),
      'gstin': gstin,
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'district': _districtController.text.trim(),
      'state': _stateController.text.trim(),
      'pincode': _pincodeController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'status': 'Active',
    };

    try {
      await ApiService.saveCompany(payload, id: _editingId);
      if (mounted) {
        setState(() {
          _successMessage = _editingId != null ? 'Company updated successfully!' : 'Company registered successfully!';
        });
        _resetForm();
        await _fetchCompanies();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save company: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleEdit(Map<String, dynamic> comp) {
    setState(() {
      _editingId = comp['id'] is int ? comp['id'] as int : int.tryParse(comp['id'].toString());
      _tradeNameController.text = comp['tradeName'] ?? '';
      _legalNameController.text = comp['legalName'] ?? '';
      _gstinController.text = comp['gstin'] ?? '';
      _addressController.text = comp['address'] ?? '';
      _cityController.text = comp['city'] ?? '';
      _districtController.text = comp['district'] ?? '';
      _stateController.text = comp['state'] ?? '';
      _pincodeController.text = comp['pincode'] ?? '';
      _phoneController.text = comp['phone'] ?? '';
      _emailController.text = comp['email'] ?? '';
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _handleDelete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 10),
            Text('Archive Firm Profile?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to archive corporate profile "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive Firm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteCompany(id);
      if (mounted) {
        setState(() {
          _successMessage = 'Company profile archived successfully';
        });
        if (_editingId == id) _resetForm();
        await _fetchCompanies();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to delete company: $e';
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _searchGstinController.clear();
      _tradeNameController.clear();
      _legalNameController.clear();
      _gstinController.clear();
      _addressController.clear();
      _cityController.clear();
      _districtController.clear();
      _stateController.clear();
      _pincodeController.clear();
      _phoneController.clear();
      _emailController.clear();
    });
  }

  List<dynamic> _getFilteredCompanies() {
    if (_tableSearchTerm.trim().isEmpty) return _companies;
    final query = _tableSearchTerm.trim().toLowerCase();
    return _companies.where((comp) {
      final trade = (comp['tradeName'] ?? '').toString().toLowerCase();
      final legal = (comp['legalName'] ?? '').toString().toLowerCase();
      final gstin = (comp['gstin'] ?? '').toString().toLowerCase();
      final city = (comp['city'] ?? '').toString().toLowerCase();
      return trade.contains(query) || legal.contains(query) || gstin.contains(query) || city.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredCompanies();
    final withGst = _companies.where((c) => (c['gstin'] ?? '').toString().trim().isNotEmpty).length;
    final distinctStates = _companies.map((c) => (c['state'] ?? '').toString().trim()).where((s) => s.isNotEmpty).toSet().length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company & Entity Master',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
            Text(
              'Corporate entity profiles, legal GST registrations, and multi-firm branches',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Companies',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            onPressed: _fetchCompanies,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Executive Cockpit Hero Banner
                _buildExecutiveCockpit(
                  totalFirms: _companies.length,
                  gstValidated: withGst,
                  statesCount: distinctStates,
                ),
                const SizedBox(height: 20),

                // 2. Alert Messages
                if (_errorMessage != null) ...[
                  _buildAlertBox(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                    color: const Color(0xFFBE123C),
                    bg: const Color(0xFFFFF1F2),
                    border: const Color(0xFFFECDD3),
                    onClose: () => setState(() => _errorMessage = null),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_successMessage != null) ...[
                  _buildAlertBox(
                    icon: Icons.check_circle_outline_rounded,
                    message: _successMessage!,
                    color: const Color(0xFF047857),
                    bg: const Color(0xFFECFDF5),
                    border: const Color(0xFFA7F3D0),
                    onClose: () => setState(() => _successMessage = null),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Responsive Two-Column Layout (Form on Left / Table on Right)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 940;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildFormCard()),
                          const SizedBox(width: 22),
                          Expanded(flex: 7, child: _buildCompaniesTableCard(filtered)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildFormCard(),
                        const SizedBox(height: 22),
                        _buildCompaniesTableCard(filtered),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveCockpit({
    required int totalFirms,
    required int gstValidated,
    required int statesCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              final infoContent = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Color(0xFF818CF8), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            const Text(
                              'MULTI-FIRM CORPORATE OPERATING ENTITIES',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 3, backgroundColor: Color(0xFF34D399)),
                                  SizedBox(width: 5),
                                  Text('MULTI-GSTIN ACTIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Primary transport firm legal identities, billing entity prefixes (AP / BELL), and tax jurisdictions',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final cancelBtn = _editingId != null
                  ? TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF3C7),
                        foregroundColor: const Color(0xFFB45309),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _resetForm,
                    )
                  : null;

              if (isNarrow && cancelBtn != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoContent,
                    const SizedBox(height: 12),
                    cancelBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: infoContent),
                  if (cancelBtn != null) ...[
                    const SizedBox(width: 12),
                    cancelBtn,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 16),
          // Cockpit KPIs
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildCockpitKpi(
                title: 'ACTIVE ENTITIES',
                value: '$totalFirms firms',
                icon: Icons.business_rounded,
                iconColor: const Color(0xFF38BDF8),
              ),
              _buildCockpitKpi(
                title: 'GSTIN VALIDATED',
                value: '$gstValidated registered',
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF34D399),
              ),
              _buildCockpitKpi(
                title: 'TAX JURISDICTIONS',
                value: '$statesCount states',
                icon: Icons.map_rounded,
                iconColor: const Color(0xFFFBBF24),
              ),
              _buildCockpitKpi(
                title: 'SYSTEM PREFIXES',
                value: 'AP / BELL',
                icon: Icons.alt_route_rounded,
                iconColor: const Color(0xFFA78BFA),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitKpi({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subheader
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(
                  _editingId != null ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                  size: 18,
                  color: const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                Text(
                  _editingId != null ? 'EDIT OPERATING FIRM #$_editingId' : 'REGISTER NEW TRANSPORT FIRM',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF334155), letterSpacing: 0.5),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Government GSTIN Search
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.search_rounded, size: 16, color: Color(0xFF4F46E5)),
                          SizedBox(width: 6),
                          Text(
                            'SEARCH GOVERNMENT GSTIN DIRECTORY',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF4338CA), letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchGstinController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter 15-digit GSTIN...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _handleGstSearch(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isSearchingGst ? null : _handleGstSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: _isSearchingGst
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Fetch Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Auto-fetches and verifies legal trade name and registered address directly from GST portal',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 14),

                // Trade Name
                _buildFieldLabel('TRADE NAME (OPERATING BRAND) *'),
                _buildFormInput(
                  controller: _tradeNameController,
                  hintText: 'e.g. ARUNACHALAM PASSENGER or BELL LOGISTICS',
                  prefixIcon: Icons.storefront_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w900,
                  textColor: const Color(0xFF1E3A8A),
                ),
                const SizedBox(height: 14),

                // Legal Name
                _buildFieldLabel('LEGAL NAME (AS PER GST)'),
                _buildFormInput(
                  controller: _legalNameController,
                  hintText: 'Registered GST legal entity name',
                  prefixIcon: Icons.badge_rounded,
                  iconColor: const Color(0xFF64748B),
                ),
                const SizedBox(height: 14),

                // GSTIN
                _buildFieldLabel('GSTIN REGISTRATION NUMBER *'),
                _buildFormInput(
                  controller: _gstinController,
                  hintText: '15-digit GSTIN (e.g. 33AABCA1234F1Z5)',
                  prefixIcon: Icons.pin_rounded,
                  iconColor: const Color(0xFF10B981),
                  textCapitalization: TextCapitalization.characters,
                  readOnly: _editingId != null,
                  fillColor: _editingId != null ? const Color(0xFFF1F5F9) : Colors.white,
                ),
                LayoutBuilder(
                  builder: (context, formConstraints) {
                    final isCompact = formConstraints.maxWidth < 460;

                    final cityField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('CITY *'),
                        _buildFormInput(
                          controller: _cityController,
                          hintText: 'e.g. Sivakasi',
                          prefixIcon: Icons.location_city_rounded,
                          iconColor: const Color(0xFFF59E0B),
                        ),
                      ],
                    );

                    final districtField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('DISTRICT'),
                        _buildFormInput(
                          controller: _districtController,
                          hintText: 'e.g. Virudhunagar',
                          prefixIcon: Icons.map_rounded,
                          iconColor: const Color(0xFF64748B),
                        ),
                      ],
                    );

                    final stateField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('STATE'),
                        _buildFormInput(
                          controller: _stateController,
                          hintText: 'e.g. Tamil Nadu (33)',
                          prefixIcon: Icons.public_rounded,
                          iconColor: const Color(0xFF64748B),
                        ),
                      ],
                    );

                    final pincodeField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('PINCODE'),
                        _buildFormInput(
                          controller: _pincodeController,
                          hintText: '626123',
                          prefixIcon: Icons.markunread_mailbox_rounded,
                          iconColor: const Color(0xFF64748B),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    );

                    final phoneField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('PHONE'),
                        _buildFormInput(
                          controller: _phoneController,
                          hintText: '9842100000',
                          prefixIcon: Icons.phone_rounded,
                          iconColor: const Color(0xFF10B981),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    );

                    final emailField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('EMAIL'),
                        _buildFormInput(
                          controller: _emailController,
                          hintText: 'accounts@company.com',
                          prefixIcon: Icons.email_rounded,
                          iconColor: const Color(0xFF6366F1),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    );

                    final clearButton = OutlinedButton(
                      onPressed: _resetForm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Clear Form', style: TextStyle(fontWeight: FontWeight.bold)),
                    );

                    final saveButton = ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : (_editingId != null ? 'Update Company Profile' : 'Save Company Profile'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // City & District
                        if (isCompact) ...[
                          cityField,
                          const SizedBox(height: 14),
                          districtField,
                        ] else
                          Row(
                            children: [
                              Expanded(child: cityField),
                              const SizedBox(width: 12),
                              Expanded(child: districtField),
                            ],
                          ),
                        const SizedBox(height: 14),

                        // State & Pincode
                        if (isCompact) ...[
                          stateField,
                          const SizedBox(height: 14),
                          pincodeField,
                        ] else
                          Row(
                            children: [
                              Expanded(child: stateField),
                              const SizedBox(width: 12),
                              Expanded(child: pincodeField),
                            ],
                          ),
                        const SizedBox(height: 14),

                        // Full Address
                        _buildFieldLabel('OFFICIAL REGISTERED ADDRESS'),
                        _buildFormInput(
                          controller: _addressController,
                          hintText: 'Building No, Industrial Area, Street, Landmark',
                          prefixIcon: Icons.place_rounded,
                          iconColor: const Color(0xFF64748B),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),

                        // Phone & Email
                        if (isCompact) ...[
                          phoneField,
                          const SizedBox(height: 14),
                          emailField,
                        ] else
                          Row(
                            children: [
                              Expanded(child: phoneField),
                              const SizedBox(width: 12),
                              Expanded(child: emailField),
                            ],
                          ),

                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),

                        // Form Buttons
                        if (isCompact) ...[
                          saveButton,
                          const SizedBox(height: 10),
                          clearButton,
                        ] else
                          Row(
                            children: [
                              Expanded(child: clearButton),
                              const SizedBox(width: 12),
                              Expanded(flex: 2, child: saveButton),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompaniesTableCard(List<dynamic> filtered) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrowHeader = headerConstraints.maxWidth < 580;
                final titleGroup = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.domain_rounded, color: Color(0xFF4F46E5), size: 20),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'REGISTERED FIRMS DIRECTORY',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_companies.length} firms',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                );

                final searchField = SizedBox(
                  width: isNarrowHeader ? double.infinity : 220,
                  height: 36,
                  child: TextField(
                    controller: _tableSearchController,
                    onChanged: (val) => setState(() => _tableSearchTerm = val),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Filter firms...',
                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                      isDense: true,
                    ),
                  ),
                );

                if (isNarrowHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleGroup,
                      const SizedBox(height: 12),
                      searchField,
                    ],
                  );
                }

                return Row(
                  children: [
                    titleGroup,
                    const Spacer(),
                    searchField,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              ),
            )
          else if (_companies.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: Text('No companies registered yet. Add one from the form.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: Text('No companies matching your search filter.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, tableConstraints) {
                const minTableWidth = 650.0;
                final tableWidth = tableConstraints.maxWidth < minTableWidth
                    ? minTableWidth
                    : tableConstraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final comp = filtered[index];
                        final id = comp['id'] is int ? comp['id'] as int : int.tryParse(comp['id'].toString()) ?? 0;
                        final tradeName = comp['tradeName'] ?? 'Unnamed';
                        final gstin = comp['gstin'] ?? '-';
                        final city = comp['city'] ?? '-';
                        final isSelected = _editingId == id;
                        final initial = tradeName.isNotEmpty ? tradeName.substring(0, 1).toUpperCase() : 'F';

                        return Container(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            children: [
                              // Avatar Monogram
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Trade & Legal Name
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tradeName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                    ),
                                    if (comp['legalName'] != null && comp['legalName'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        comp['legalName'],
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // GSTIN
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () {
                                    if (gstin != '-') {
                                      Clipboard.setData(ClipboardData(text: gstin));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('GSTIN $gstin copied to clipboard'), duration: const Duration(seconds: 1)),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          gstin,
                                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                        ),
                                        if (gstin != '-') ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.copy_rounded, size: 10, color: Color(0xFF64748B)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // City
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      city,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                              ),

                              // Actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4F46E5)),
                                    tooltip: 'Edit Company',
                                    onPressed: () => _handleEdit(comp),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                    tooltip: 'Delete Company',
                                    onPressed: () => _handleDelete(id, tradeName),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildFormInput({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool readOnly = false,
    Color fillColor = Colors.white,
    Color textColor = const Color(0xFF0F172A),
    FontWeight fontWeight = FontWeight.w600,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        readOnly: readOnly,
        maxLines: maxLines,
        style: TextStyle(fontSize: 13, fontWeight: fontWeight, color: textColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
          prefixIcon: Icon(prefixIcon, size: 18, color: iconColor),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildAlertBox({
    required IconData icon,
    required String message,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: color),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
