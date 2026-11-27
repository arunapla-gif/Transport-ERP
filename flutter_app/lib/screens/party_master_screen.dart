import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/consignor.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

const Map<String, String> _stateNameToCode = {
  'jammu and kashmir': '01',
  'himachal pradesh': '02',
  'punjab': '03',
  'chandigarh': '04',
  'uttarakhand': '05',
  'haryana': '06',
  'delhi': '07',
  'rajasthan': '08',
  'uttar pradesh': '09',
  'bihar': '10',
  'sikkim': '11',
  'arunachal pradesh': '12',
  'nagaland': '13',
  'manipur': '14',
  'mizoram': '15',
  'tripura': '16',
  'meghalaya': '17',
  'assam': '18',
  'west bengal': '19',
  'jharkhand': '20',
  'odisha': '21',
  'chhattisgarh': '22',
  'madhya pradesh': '23',
  'gujarat': '24',
  'daman and diu': '25',
  'dadra and nagar haveli and daman and diu': '26',
  'maharashtra': '27',
  'andhra pradesh': '28',
  'karnataka': '29',
  'goa': '30',
  'lakshadweep': '31',
  'kerala': '32',
  'tamil nadu': '33',
  'puducherry': '34',
  'andaman and nicobar islands': '35',
  'telangana': '36',
  'ladakh': '38',
};

class PartyMasterScreen extends StatefulWidget {
  final String endpoint; // 'consignors' or 'consignees'
  final String title; // 'Consignor' or 'Consignee'

  const PartyMasterScreen({
    super.key,
    required this.endpoint,
    required this.title,
  });

  @override
  State<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends State<PartyMasterScreen> {
  // Pagination & List State
  List<Consignor> _parties = [];
  List<Consignor> _allParentCandidates = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isVerifyingGst = false;
  int _page = 1;
  int _totalRecords = 0;
  bool _hasMore = true;

  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _tableScrollController = ScrollController();

  // Search & Tabs (matching React ConsignorTable / ConsigneeTable)
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedSearch = '';
  String _activeTab = 'API_ONLY'; // 'API_ONLY' | 'RETAIL_WITH_PHONE'

  // Form State (matching React formData 1-to-1)
  int? _id;
  bool _isRetail = false;
  String _migrationType = 'MANUAL';
  int? _parentId;
  List<Map<String, dynamic>> _addresses = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _legalNameController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _panNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _stateCodeController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();

  bool get _isConsignor => widget.endpoint == 'consignors';
  bool get _isUrp => _gstinController.text.trim().toUpperCase() == 'URP';

  // Permissions parity with React usePermissions()
  bool get _canEdit => true;
  bool get _canDelete => AuthService.isAdmin;

  // Exact React color accents: Indigo for Consignor, Emerald for Consignee
  Color get _accent =>
      _isConsignor ? const Color(0xFF4F46E5) : const Color(0xFF059669);
  Color get _accentSoftBg =>
      _isConsignor ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5);
  Color get _accentSoftBorder =>
      _isConsignor ? const Color(0xFFE0E7FF) : const Color(0xFFD1FAE5);
  Color get _accentDarkText =>
      _isConsignor ? const Color(0xFF312E81) : const Color(0xFF064E3B);

  @override
  void initState() {
    super.initState();
    _fetchParties(1);
    if (!_isConsignor) {
      _loadParentCandidates();
    }
    _tableScrollController.addListener(_onTableScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pageScrollController.dispose();
    _tableScrollController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _legalNameController.dispose();
    _gstinController.dispose();
    _panNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _stateCodeController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  void _onTableScroll() {
    if (_tableScrollController.hasClients &&
        _tableScrollController.position.pixels >=
            _tableScrollController.position.maxScrollExtent - 250 &&
        !_isLoading &&
        _hasMore) {
      _fetchParties(_page + 1);
    }
  }

  Future<void> _loadParentCandidates() async {
    try {
      final res = await ApiService.getPartiesPaginated('consignees',
          page: 1, limit: 2000);
      final raw = res['data'] as List<dynamic>;
      if (mounted) {
        setState(() {
          _allParentCandidates = raw
              .map((e) => Consignor.fromJson(Map<String, dynamic>.from(e)))
              .where((c) => c.isActive)
              .toList();
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _debouncedSearch = val.trim();
      _fetchParties(1);
    });
  }

  Future<void> _fetchParties(int pageNum) async {
    if (_isLoading && pageNum > 1) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.getPartiesPaginated(
        widget.endpoint,
        page: pageNum,
        limit: 50,
        q: _debouncedSearch,
      );
      final List<dynamic> rawList = res['data'] as List<dynamic>;
      final List<Consignor> fetched = rawList
          .map((e) => Consignor.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          _page = pageNum;
          _totalRecords = (res['total'] as int?) ?? fetched.length;
          _hasMore = res['hasMore'] == true;
          if (pageNum == 1) {
            _parties = fetched;
          } else {
            final existingIds = _parties.map((p) => p.id).toSet();
            for (final item in fetched) {
              if (!existingIds.contains(item.id)) {
                _parties.add(item);
              }
            }
          }
        });
      }
    } catch (e) {
      _showToast('Failed to fetch data: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _cleanAddressParts(List<dynamic> parts, String companyName) {
    String joined = parts
        .where((p) => p != null && p.toString().trim().isNotEmpty)
        .map((p) => p.toString().trim())
        .join(', ');
    if (companyName.trim().isEmpty) return joined;

    try {
      final cleanName =
          companyName.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim();
      if (cleanName.isNotEmpty) {
        final pattern = cleanName
            .split(RegExp(r'\s+'))
            .map(RegExp.escape)
            .join(r'\s*[^a-zA-Z0-9]*\s*');
        final regex =
            RegExp('^$pattern\\s*[^a-zA-Z0-9]*\\s*', caseSensitive: false);
        joined = joined.replaceFirst(regex, '');
      }
    } catch (_) {}
    return joined;
  }

  Future<void> _handleVerifyGST() async {
    final trimmedGstin = _gstinController.text.trim().toUpperCase();
    if (trimmedGstin.isEmpty || trimmedGstin == 'URP') {
      _showToast('Please enter a GSTIN to verify', isError: true);
      return;
    }

    setState(() => _isVerifyingGst = true);
    try {
      final data = await ApiService.verifyGST(trimmedGstin);
      final info = data['taxpayerInfo'];
      if (info == null || info is! Map) {
        throw Exception('Invalid GSTIN details');
      }

      final Map<String, dynamic> addr =
          info['pradr'] is Map && info['pradr']['addr'] is Map
              ? Map<String, dynamic>.from(info['pradr']['addr'])
              : {};

      final String companyName =
          (info['tradeNam']?.toString().trim().isNotEmpty == true
                      ? info['tradeNam']
                      : info['lgnm'])
                  ?.toString()
                  .trim() ??
              '';
      final String legalName = info['lgnm']?.toString().trim() ?? '';

      final List<Map<String, dynamic>> additionalAddresses = [];
      if (info['adadr'] is List) {
        for (final a in (info['adadr'] as List)) {
          if (a is Map && a['addr'] is Map) {
            final adr = Map<String, dynamic>.from(a['addr']);
            additionalAddresses.add({
              'address': _cleanAddressParts(
                [adr['bno'], adr['bnm'], adr['st'], adr['flno']],
                companyName,
              ),
              'city': (adr['loc'] ?? adr['city'] ?? '').toString(),
              'district': (adr['dst'] ?? '').toString(),
              'state': (adr['stcd'] ?? '').toString(),
              'pincode': (adr['pncd'] ?? adr['pincode'] ?? '').toString(),
            });
          }
        }
      }

      final String rawState = (addr['stcd'] ?? '').toString();
      String mappedStateCode = _stateCodeController.text.trim();
      if (rawState.isNotEmpty) {
        final normalized = rawState.trim().toLowerCase();
        if (_stateNameToCode.containsKey(normalized)) {
          mappedStateCode = _stateNameToCode[normalized]!;
        } else if (trimmedGstin.length >= 2) {
          mappedStateCode = trimmedGstin.substring(0, 2);
        }
      }

      final cleanedPrimaryAddr = _cleanAddressParts(
        [addr['bno'], addr['bnm'], addr['st'], addr['flno']],
        companyName,
      );

      setState(() {
        if (companyName.isNotEmpty) _nameController.text = companyName;
        if (legalName.isNotEmpty) _legalNameController.text = legalName;
        if (trimmedGstin.length >= 12) {
          _panNumberController.text = trimmedGstin.substring(2, 12);
        }
        if (cleanedPrimaryAddr.isNotEmpty) {
          _addressController.text = cleanedPrimaryAddr;
        }
        final loc = (addr['loc'] ?? addr['city'] ?? '').toString();
        if (loc.isNotEmpty) _cityController.text = loc;
        final dst = (addr['dst'] ?? '').toString();
        if (dst.isNotEmpty) _districtController.text = dst;
        if (rawState.isNotEmpty) _stateController.text = rawState;
        _stateCodeController.text =
            mappedStateCode.isNotEmpty ? mappedStateCode : rawState;
        final pin = (addr['pncd'] ?? addr['pincode'] ?? '').toString();
        if (pin.isNotEmpty) _pincodeController.text = pin;
        _addresses = additionalAddresses;
        _migrationType = 'GST_VERIFIED';
        _isRetail = false;
      });

      _showToast('GST verified and details auto-filled!');
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isVerifyingGst = false);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showToast('${widget.title} Name is required', isError: true);
      return;
    }

    final rawGstin = _gstinController.text.trim().toUpperCase();

    // Exact React validations (Retail vs URD)
    if (_isRetail) {
      if (_phoneController.text.trim().isEmpty) {
        _showToast('Phone Number is required for Retail Customers',
            isError: true);
        return;
      }
    } else if (rawGstin == 'URP') {
      if (_panNumberController.text.trim().isEmpty) {
        _showToast('PAN / Aadhaar is mandatory for Unregistered Dealers (URD)',
            isError: true);
        return;
      }
      if (_addressController.text.trim().isEmpty) {
        _showToast('Full Address is mandatory for URD', isError: true);
        return;
      }
      if (_cityController.text.trim().isEmpty) {
        _showToast('City is mandatory for URD', isError: true);
        return;
      }
      if (_stateController.text.trim().isEmpty ||
          _stateCodeController.text.trim().isEmpty) {
        _showToast('State and State Code are mandatory for URD', isError: true);
        return;
      }
      if (_pincodeController.text.trim().isEmpty) {
        _showToast('Pincode is mandatory for URD', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final String resolvedMigrationType = _isRetail
          ? 'RETAIL_WITH_PHONE'
          : (rawGstin == 'URP'
              ? 'MANUAL'
              : (_migrationType == 'GST_VERIFIED' ? 'GST_VERIFIED' : 'MANUAL'));

      final Map<String, dynamic> payload = {
        'name': name,
        if (_legalNameController.text.trim().isNotEmpty || !_isConsignor)
          'legalName': _legalNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'stateCode': _stateCodeController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'gstin': _isRetail
            ? null
            : (rawGstin == 'URP'
                ? 'URP'
                : (rawGstin.isEmpty ? null : rawGstin)),
        'panNumber': _panNumberController.text.trim().toUpperCase(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'group': _groupController.text.trim(),
        'addresses': _addresses,
        'branch': ApiService.activeBranch,
        'migrationType': resolvedMigrationType,
        if (!_isConsignor) 'parentId': _parentId,
      };

      if (_id != null) {
        await ApiService.updateParty(
            widget.endpoint, _id!, {...payload, 'id': _id});
        _showToast('${widget.title} updated successfully');
      } else {
        await ApiService.createParty(widget.endpoint, payload);
        _showToast('${widget.title} created successfully');
      }

      _clearForm();
      await _fetchParties(1);
      if (!_isConsignor) {
        _loadParentCandidates();
      }
    } catch (e) {
      _showToast(
          'Failed to save record: ${e.toString().replaceFirst('Exception: ', '')}',
          isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleEdit(Consignor p) {
    setState(() {
      _id = p.id;
      _nameController.text = p.name;
      _legalNameController.text = p.legalName ?? '';
      _addressController.text = p.address ?? '';
      _cityController.text = p.city ?? '';
      _districtController.text = p.district ?? '';
      _stateController.text = p.state ?? '';
      _stateCodeController.text = p.stateCode ??
          (_stateNameToCode[(p.state ?? '').trim().toLowerCase()] ?? '');
      _pincodeController.text = p.pincode ?? '';
      _gstinController.text = p.gstin ?? '';
      _panNumberController.text = p.panNumber ??
          ((p.gstin != null && p.gstin != 'URP' && p.gstin!.length >= 12)
              ? p.gstin!.substring(2, 12)
              : '');
      _phoneController.text = p.phone ?? '';
      _emailController.text = p.email ?? '';
      _groupController.text = p.group ?? '';
      _addresses = List<Map<String, dynamic>>.from(
        p.addresses.map((a) => Map<String, dynamic>.from(a)),
      );
      _parentId = p.parentId;
      _isRetail = p.migrationType == 'RETAIL_WITH_PHONE';
      _migrationType = p.migrationType ?? 'MANUAL';
    });

    if (_pageScrollController.hasClients) {
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleArchive(Consignor p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Archive ${widget.title}?',
          style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to archive "${p.name}"? You can restore this record anytime.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Archive',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ApiService.deleteParty(widget.endpoint, p.id);
      _showToast('Record archived');
      _fetchParties(1);
    } catch (e) {
      _showToast('Failed to archive record', isError: true);
    }
  }

  Future<void> _handleRestore(Consignor p) async {
    try {
      await ApiService.restoreParty(widget.endpoint, p.id);
      _showToast('Record restored successfully');
      _fetchParties(1);
    } catch (e) {
      _showToast('Failed to restore record', isError: true);
    }
  }

  Future<void> _updateConsigneePrimaryName(int id, String newName) async {
    try {
      await ApiService.updateParty('consignees', id, {'name': newName});
      _showToast('Primary name updated!');
      _fetchParties(1);
    } catch (e) {
      _showToast('Failed to update name: $e', isError: true);
    }
  }

  void _clearForm() {
    setState(() {
      _id = null;
      _isRetail = false;
      _migrationType = 'MANUAL';
      _parentId = null;
      _addresses = [];
      _nameController.clear();
      _legalNameController.clear();
      _gstinController.clear();
      _panNumberController.clear();
      _addressController.clear();
      _cityController.clear();
      _districtController.clear();
      _stateController.clear();
      _stateCodeController.clear();
      _pincodeController.clear();
      _phoneController.clear();
      _emailController.clear();
      _groupController.clear();
    });
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          backgroundColor:
              isError ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          width: 420,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  List<Consignor> get _filteredParties {
    if (_isConsignor) return _parties;
    return _parties.where((c) {
      if (_activeTab == 'RETAIL_WITH_PHONE') {
        return c.migrationType == 'RETAIL_WITH_PHONE';
      }
      return c.migrationType == null ||
          c.migrationType == 'API_ONLY' ||
          c.migrationType == 'MANUAL' ||
          c.migrationType == 'EWB_LITE' ||
          c.migrationType == 'GST_VERIFIED';
    }).toList();
  }

  String? _resolveParentName(int? parentId) {
    if (parentId == null) return null;
    for (final p in _allParentCandidates) {
      if (p.id == parentId) return p.name;
    }
    for (final p in _parties) {
      if (p.id == parentId) return p.name;
    }
    return '#$parentId';
  }

  // --- UI PRIMITIVES (React GlassCard + DenseInput parity) ---

  Widget _glassCard(
      {required Widget child,
      EdgeInsetsGeometry? padding,
      Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _denseField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    bool readOnly = false,
    bool boldAccentText = false,
    bool uppercase = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: uppercase
              ? TextCapitalization.characters
              : TextCapitalization.none,
          onChanged: (val) {
            if (uppercase && val != val.toUpperCase()) {
              controller.value = controller.value.copyWith(
                text: val.toUpperCase(),
                selection: TextSelection.collapsed(offset: val.length),
              );
            }
            onChanged?.call(uppercase ? val.toUpperCase() : val);
          },
          style: TextStyle(
            fontSize: 14,
            fontWeight: boldAccentText ? FontWeight.w700 : FontWeight.w500,
            color: readOnly
                ? const Color(0xFF94A3B8)
                : (boldAccentText ? _accentDarkText : const Color(0xFF0F172A)),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400),
            isDense: true,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide:
                  const BorderSide(color: Color(0xFF10B981), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGstinControl() {
    final bool isVerified = _migrationType == 'GST_VERIFIED' &&
        !_isUrp &&
        _gstinController.text.trim().isNotEmpty;
    final bool disableVerify = _isVerifyingGst ||
        _isSaving ||
        _isUrp ||
        _isRetail ||
        _gstinController.text.trim().isEmpty ||
        isVerified;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GSTIN',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.4,
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _isRetail
                      ? null
                      : () {
                          setState(() {
                            if (_isUrp) {
                              _gstinController.clear();
                            } else {
                              _gstinController.text = 'URP';
                              _migrationType = 'MANUAL';
                            }
                          });
                        },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: Checkbox(
                            value: _isUrp,
                            activeColor: const Color(0xFF059669),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(
                                color: Color(0xFF94A3B8), width: 1.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3)),
                            onChanged: _isRetail
                                ? null
                                : (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _gstinController.text = 'URP';
                                        _migrationType = 'MANUAL';
                                      } else {
                                        _gstinController.clear();
                                      }
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Unregistered (URD)',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _gstinController,
                readOnly: _isUrp || _isRetail,
                textCapitalization: TextCapitalization.characters,
                onChanged: (val) {
                  final upper = val.toUpperCase();
                  if (val != upper) {
                    _gstinController.value = _gstinController.value.copyWith(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                  setState(() {
                    if (_migrationType == 'GST_VERIFIED') {
                      _migrationType = 'MANUAL';
                    }
                  });
                },
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: (_isUrp || _isRetail)
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText:
                      _isRetail ? 'Disabled for Retail' : '27AADCB2230M1Z2',
                  hintStyle: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF94A3B8),
                      fontFamily: 'Inter'),
                  isDense: true,
                  filled: true,
                  fillColor: (_isUrp || _isRetail)
                      ? const Color(0xFFF8FAFC)
                      : Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    borderSide:
                        const BorderSide(color: Color(0xFF10B981), width: 1.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: disableVerify ? null : _handleVerifyGST,
                style: OutlinedButton.styleFrom(
                  backgroundColor: (_isUrp || _isRetail)
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFD1FAE5),
                  foregroundColor: (_isUrp || _isRetail)
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF047857),
                  disabledBackgroundColor: isVerified
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFF1F5F9),
                  disabledForegroundColor: isVerified
                      ? const Color(0xFF047857)
                      : const Color(0xFF94A3B8),
                  side: BorderSide(
                    color: (_isUrp || _isRetail) && !isVerified
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFA7F3D0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isVerifyingGst
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF047857)),
                      )
                    : isVerified
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 15, color: Color(0xFF047857)),
                              SizedBox(width: 5),
                              Text('Verified',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          )
                        : const Text('Verify',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRetailSwitch() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _isRetail = !_isRetail;
          if (_isRetail) {
            _gstinController.clear();
            _migrationType = 'RETAIL_WITH_PHONE';
          } else {
            _migrationType = 'MANUAL';
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Retail / Walk-in Customer',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155)),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _isRetail ? _accent : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment:
                  _isRetail ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentGroupDropdown() {
    final options = _allParentCandidates.where((c) => c.id != _id).toList();
    final bool validParent =
        _parentId != null && options.any((c) => c.id == _parentId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PARENT GROUP (MASTER CONSIGNEE)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            child: DropdownButton<int?>(
              value: validParent ? _parentId : null,
              isExpanded: true,
              isDense: true,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A)),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('-- No Parent Group --',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                ...options.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(
                      '${c.name}${c.city != null && c.city!.isNotEmpty ? ' (${c.city})' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _parentId = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUrdKycBanner(bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: isDesktop
          ? Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KYC Required for Unregistered Dealers',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF78350F)),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Please provide their PAN or Aadhaar number for compliance.',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _denseField(
                    label: 'PAN / Aadhaar *',
                    controller: _panNumberController,
                    placeholder: 'ABCDE1234F',
                    uppercase: true,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'KYC Required for Unregistered Dealers',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF78350F)),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Please provide their PAN or Aadhaar number for compliance.',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB45309)),
                ),
                const SizedBox(height: 10),
                _denseField(
                  label: 'PAN / Aadhaar *',
                  controller: _panNumberController,
                  placeholder: 'ABCDE1234F',
                  uppercase: true,
                ),
              ],
            ),
    );
  }

  Widget _buildFormCard() {
    return _glassCard(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 780;
          final String urpStar = _isUrp ? ' *' : '';

          final stateAndCodeRow = Row(
            children: [
              Expanded(
                flex: 3,
                child: _denseField(
                  label: 'State$urpStar',
                  controller: _stateController,
                  onChanged: (val) {
                    final mapped = _stateNameToCode[val.trim().toLowerCase()];
                    if (mapped != null) {
                      _stateCodeController.text = mapped;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _denseField(
                  label: 'Code$urpStar',
                  controller: _stateCodeController,
                ),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Header
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Customer Details',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                        if (_id != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentSoftBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _accentSoftBorder),
                            ),
                            child: Text(
                              'Editing #$_id',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                    _buildRetailSwitch(),
                  ],
                ),
              ),

              // Row 1: Consignor vs Consignee layout matching React 1-to-1
              if (_isConsignor) ...[
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _denseField(
                          label: 'Consignor Name *',
                          controller: _nameController,
                          boldAccentText: true,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(flex: 1, child: _buildGstinControl()),
                    ],
                  )
                else ...[
                  _denseField(
                    label: 'Consignor Name *',
                    controller: _nameController,
                    boldAccentText: true,
                  ),
                  const SizedBox(height: 12),
                  _buildGstinControl(),
                ],
              ] else ...[
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _denseField(
                          label: 'Trade Name (Primary) *',
                          controller: _nameController,
                          boldAccentText: true,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 1,
                        child: _denseField(
                          label: 'Legal Name',
                          controller: _legalNameController,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _denseField(
                    label: 'Trade Name (Primary) *',
                    controller: _nameController,
                    boldAccentText: true,
                  ),
                  const SizedBox(height: 12),
                  _denseField(
                    label: 'Legal Name',
                    controller: _legalNameController,
                  ),
                ],
                const SizedBox(height: 16),
                _buildGstinControl(),
              ],

              const SizedBox(height: 16),
              _denseField(
                label: 'Full Address$urpStar',
                controller: _addressController,
                maxLines: 2,
              ),

              const SizedBox(height: 16),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _denseField(
                            label: 'City$urpStar',
                            controller: _cityController)),
                    const SizedBox(width: 18),
                    Expanded(
                        child: _denseField(
                            label: 'District',
                            controller: _districtController)),
                    const SizedBox(width: 18),
                    Expanded(child: stateAndCodeRow),
                  ],
                )
              else ...[
                _denseField(label: 'City$urpStar', controller: _cityController),
                const SizedBox(height: 12),
                _denseField(label: 'District', controller: _districtController),
                const SizedBox(height: 12),
                stateAndCodeRow,
              ],

              const SizedBox(height: 16),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _denseField(
                        label: 'Pincode$urpStar',
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _denseField(
                        label: 'Phone Number${_isRetail ? ' *' : ''}',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _denseField(
                        label: 'Email Address',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                )
              else ...[
                _denseField(
                  label: 'Pincode$urpStar',
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _denseField(
                  label: 'Phone Number${_isRetail ? ' *' : ''}',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _denseField(
                  label: 'Email Address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],

              if (_isUrp) _buildUrdKycBanner(isDesktop),

              if (!_isConsignor) ...[
                const SizedBox(height: 16),
                if (isDesktop)
                  Row(
                    children: [
                      Expanded(flex: 2, child: _buildParentGroupDropdown()),
                      const SizedBox(width: 18),
                      const Expanded(flex: 1, child: SizedBox.shrink()),
                    ],
                  )
                else
                  _buildParentGroupDropdown(),
              ],

              // Bottom Action Bar
              Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.only(top: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: _clearForm,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Clear',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: (_isSaving || (_id != null && !_canEdit))
                            ? null
                            : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(
                          _id != null
                              ? 'Update ${widget.title}'
                              : 'Save ${widget.title}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAdditionalAddressesCard() {
    if (_addresses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: _glassCard(
        padding: EdgeInsets.zero,
        borderColor: _accentSoftBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _accentSoftBg.withValues(alpha: 0.65),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: _accentSoftBorder)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: _accent),
                  const SizedBox(width: 8),
                  Text(
                    'Additional Places of Business',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _accentDarkText),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accentSoftBorder,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_addresses.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _accent),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_addresses.length, (idx) {
                  final addr = _addresses[idx];
                  final locParts = [
                    addr['city'],
                    addr['district'],
                    addr['state']
                  ]
                      .where((e) => e != null && e.toString().trim().isNotEmpty)
                      .map((e) => e.toString())
                      .join(' • ');
                  return SizedBox(
                    width: 380,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (addr['address']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true)
                                      ? addr['address'].toString()
                                      : 'No Street Address',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B)),
                                ),
                                if (locParts.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(locParts,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF475569))),
                                ],
                                if (addr['pincode'] != null &&
                                    addr['pincode'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text('PIN: ${addr['pincode']}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B))),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Color(0xFF94A3B8)),
                            tooltip: 'Remove address',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: () {
                              setState(() {
                                _addresses.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusBadges(Consignor c) {
    final List<Widget> badges = [];
    if (!c.isActive) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: const Text(
            'ARCHIVED',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155)),
          ),
        ),
      );
    }
    if ((c.gstin?.isNotEmpty == true) && c.migrationType == 'GST_VERIFIED') {
      badges.add(
        Tooltip(
          message: 'Fully Verified',
          child: Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Text('✓',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF059669))),
          ),
        ),
      );
    }
    if (c.migrationType == 'EWB_LITE') {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Text(
            _isConsignor ? '⚠️ Lite' : '⚠️ EWB Lite',
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB45309)),
          ),
        ),
      );
    }
    return badges;
  }

  Widget _buildTradeNameSubline(Consignor c) {
    if (_isConsignor) return const SizedBox.shrink();
    final Set<String> distinct = {
      if (c.name.trim().isNotEmpty) c.name.trim(),
      ...c.tradeNames.map((t) => t.trim()).where((t) => t.isNotEmpty),
      if (c.legalName != null && c.legalName!.trim().isNotEmpty)
        c.legalName!.trim(),
    };
    final allNames = distinct.toList();
    if (allNames.length > 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Trade: ',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: allNames.contains(c.name.trim())
                      ? c.name.trim()
                      : allNames.first,
                  isDense: true,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600),
                  items: allNames
                      .map((n) => DropdownMenuItem<String>(
                            value: n,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 230),
                              child: Text(n, overflow: TextOverflow.ellipsis),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null && val != c.name) {
                      _updateConsigneePrimaryName(c.id, val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    } else if (c.tradeNames.isNotEmpty && c.tradeNames.first != c.name) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Trade: ${c.tradeNames.join(', ')}',
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRowActions(Consignor c, {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_canEdit)
          OutlinedButton.icon(
            onPressed: () => _handleEdit(c),
            icon: Icon(Icons.edit_outlined,
                size: 13,
                color: _isConsignor
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF2563EB)),
            label: const Text('Edit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  _isConsignor ? Colors.white : const Color(0xFFEFF6FF),
              foregroundColor: _isConsignor
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF2563EB),
              side: BorderSide(
                  color: _isConsignor
                      ? const Color(0xFFC7D2FE)
                      : const Color(0xFFBFDBFE)),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 11, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        if (_canDelete && c.isActive) ...[
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _handleArchive(c),
            icon: Icon(Icons.delete_outline_rounded,
                size: 13,
                color: _isConsignor
                    ? const Color(0xFFE11D48)
                    : const Color(0xFFD97706)),
            label: const Text('Archive',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  _isConsignor ? Colors.white : const Color(0xFFFFFBEB),
              foregroundColor: _isConsignor
                  ? const Color(0xFFE11D48)
                  : const Color(0xFFD97706),
              side: BorderSide(
                  color: _isConsignor
                      ? const Color(0xFFFECDD3)
                      : const Color(0xFFFDE68A)),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 11, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        if (_canDelete && !c.isActive) ...[
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => _handleRestore(c),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFECFDF5),
              foregroundColor: const Color(0xFF059669),
              side: const BorderSide(color: Color(0xFFA7F3D0)),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 11, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Restore',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }

  Widget _buildTableCard() {
    final rows = _filteredParties;
    final int apiOnlyCount = _parties
        .where((c) =>
            c.migrationType == null ||
            c.migrationType == 'API_ONLY' ||
            c.migrationType == 'MANUAL' ||
            c.migrationType == 'EWB_LITE' ||
            c.migrationType == 'GST_VERIFIED')
        .length;
    final int retailPhoneCount =
        _parties.where((c) => c.migrationType == 'RETAIL_WITH_PHONE').length;

    return _glassCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 760;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Filter + Search Bar
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    if (!_isConsignor)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _tabButton(
                              label: 'API Data ($apiOnlyCount)',
                              selected: _activeTab == 'API_ONLY',
                              activeColor: const Color(0xFF047857),
                              onTap: () =>
                                  setState(() => _activeTab = 'API_ONLY'),
                            ),
                            const SizedBox(width: 6),
                            _tabButton(
                              label: 'Retail (Has Phone) ($retailPhoneCount)',
                              selected: _activeTab == 'RETAIL_WITH_PHONE',
                              activeColor: const Color(0xFF4338CA),
                              onTap: () => setState(
                                  () => _activeTab = 'RETAIL_WITH_PHONE'),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Showing ${_parties.length} of $_totalRecords consignors',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569)),
                      ),
                    SizedBox(
                      width: isMobile ? double.infinity : 280,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search party...',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 16, color: Color(0xFF64748B)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 15, color: Color(0xFF64748B)),
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _accent, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Empty State
              if (rows.isEmpty && !_isLoading)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Icon(Icons.search_rounded,
                            size: 30, color: _accent.withValues(alpha: 0.35)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No records found',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'We couldn\'t find any ${widget.title.toLowerCase()}s matching your current filters or search criteria.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                )
              else if (isMobile)
                // MOBILE CARDS VIEW (React md:hidden parity)
                SizedBox(
                  height: 520,
                  child: ListView.separated(
                    controller: _tableScrollController,
                    itemCount: rows.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      if (index == rows.length) {
                        return _buildLoadMoreFooter();
                      }
                      final c = rows[index];
                      final parentName =
                          !_isConsignor ? _resolveParentName(c.parentId) : null;
                      return Opacity(
                        opacity: c.isActive ? 1.0 : 0.6,
                        child: Container(
                          color: c.isActive
                              ? Colors.white
                              : const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              '${index + 1}.',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF94A3B8)),
                                            ),
                                            Text(
                                              c.name,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A)),
                                            ),
                                            ..._buildStatusBadges(c),
                                          ],
                                        ),
                                        if (c.legalName != null &&
                                            c.legalName!.isNotEmpty &&
                                            c.legalName != c.name)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Legal: ${c.legalName}',
                                              style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B)),
                                            ),
                                          ),
                                        if (parentName != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF2FF),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'Parent: $parentName',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF4F46E5)),
                                              ),
                                            ),
                                          ),
                                        _buildTradeNameSubline(c),
                                        const SizedBox(height: 5),
                                        Text(
                                          (c.gstin != null &&
                                                  c.gstin!.trim().isNotEmpty)
                                              ? c.gstin!
                                              : 'NO GSTIN',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: _accent,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (c.addresses.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFFBEB),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFFDE68A)),
                                              ),
                                              child: Text(
                                                '+${c.addresses.length} Addr',
                                                style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFD97706)),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildRowActions(c, compact: true),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 16,
                                              color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              (c.city?.trim().isNotEmpty ==
                                                      true)
                                                  ? c.city!
                                                  : '-',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF334155)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_outlined,
                                              size: 16,
                                              color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              (c.phone?.trim().isNotEmpty ==
                                                      true)
                                                  ? c.phone!
                                                  : '-',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF334155)),
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
                  ),
                )
              else
                // DESKTOP DATA GRID (React hidden md:block parity)
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: Text(
                              _isConsignor ? '#' : 'S.NO',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              _isConsignor ? 'CONSIGNOR DETAILS' : 'NAME',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _isConsignor ? 'LOCATION' : 'CITY',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _isConsignor ? 'TAX ID (GSTIN)' : 'GSTIN',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              _isConsignor ? 'CONTACT' : 'PHONE',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4),
                            ),
                          ),
                          const SizedBox(
                            width: 180,
                            child: Text(
                              'ACTIONS',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 500,
                      child: ListView.separated(
                        controller: _tableScrollController,
                        itemCount: rows.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, index) {
                          if (index == rows.length) {
                            return _buildLoadMoreFooter();
                          }
                          final c = rows[index];
                          final parentName = !_isConsignor
                              ? _resolveParentName(c.parentId)
                              : null;
                          final bool isEven = index.isEven;

                          return Opacity(
                            opacity: c.isActive ? 1.0 : 0.6,
                            child: Container(
                              color: !c.isActive
                                  ? const Color(0xFFF1F5F9)
                                  : (isEven
                                      ? Colors.white
                                      : const Color(0xFFF8FAFC)
                                          .withValues(alpha: 0.65)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 11),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 44,
                                    child: Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                c.name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              ..._buildStatusBadges(c),
                                            ],
                                          ),
                                          if (c.legalName != null &&
                                              c.legalName!.isNotEmpty &&
                                              c.legalName != c.name)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Legal: ${c.legalName}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B)),
                                              ),
                                            ),
                                          if (parentName != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Parent: $parentName',
                                                style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF4F46E5)),
                                              ),
                                            ),
                                          _buildTradeNameSubline(c),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (_isConsignor) ...[
                                              const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 13,
                                                  color: Color(0xFF94A3B8)),
                                              const SizedBox(width: 4),
                                            ],
                                            Expanded(
                                              child: Text(
                                                (c.city?.trim().isNotEmpty ==
                                                        true)
                                                    ? c.city!
                                                    : '-',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF334155)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (c.addresses.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 3),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFFBEB),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFFDE68A)),
                                              ),
                                              child: Text(
                                                '+${c.addresses.length} ${_isConsignor ? 'ADDR' : 'Addr'}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFD97706)),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (c.gstin?.trim().isNotEmpty == true)
                                          ? c.gstin!.toUpperCase()
                                          : '-',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (c.phone?.trim().isNotEmpty == true)
                                          ? c.phone!
                                          : '-',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF334155)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: _buildRowActions(c),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool selected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: const Color(0xFFE2E8F0)) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter() {
    return InkWell(
      onTap: _isLoading ? null : () => _fetchParties(_page + 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: _isLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accent),
                    ),
                    const SizedBox(width: 10),
                    const Text('Loading more...',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B))),
                  ],
                )
              : Text(
                  'Scroll for more (${_parties.length} of $_totalRecords loaded)',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B)),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _handleSave,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _handleSave,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            controller: _pageScrollController,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HEADER CARD (Exact React GlassCard header)
                    _glassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _accentSoftBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _accentSoftBorder),
                            ),
                            child: Icon(
                              _isConsignor
                                  ? Icons.business_rounded
                                  : Icons.location_on_outlined,
                              size: 22,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.title} Master',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isConsignor
                                      ? 'Manage consignor profiles, addresses, and GSTIN details.'
                                      : 'Manage consignee profiles, delivery addresses, and GSTIN details.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _accentSoftBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _accentSoftBorder),
                            ),
                            child: Text(
                              '$_totalRecords Total',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _accent),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // FORM CARD + ADDITIONAL ADDRESSES CARD
                    _buildFormCard(),
                    _buildAdditionalAddressesCard(),

                    const SizedBox(height: 16),

                    // LIST / TABLE CARD
                    _buildTableCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
