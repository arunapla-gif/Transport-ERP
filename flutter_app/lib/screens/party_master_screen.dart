import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/consignor.dart';

// We reuse Consignor model for both Consignor and Consignee as they share the same schema.
class PartyMasterScreen extends StatefulWidget {
  final String endpoint; // "consignors" or "consignees"
  final String title;

  const PartyMasterScreen({super.key, required this.endpoint, required this.title});

  @override
  State<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends State<PartyMasterScreen> {
  List<Consignor> _parties = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isFetchingGst = false;
  bool _gstVerified = false;

  // Form State
  int? _id;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _panNumberController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();

  bool get _isConsignor => widget.endpoint == 'consignors';

  List<Color> get _themeGradient => _isConsignor
      ? const [Color(0xFF2563EB), Color(0xFF1D4ED8)]
      : const [Color(0xFF0D9488), Color(0xFF0F766E)];

  Color get _themePrimary => _isConsignor ? const Color(0xFF2563EB) : const Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    _fetchParties(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _gstinController.dispose();
    _panNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading && _hasMore) {
      _fetchParties(_page + 1);
    }
  }

  Future<void> _fetchParties(int pageNum) async {
    setState(() => _isLoading = true);
    
    try {
      final res = await ApiService.getParties(widget.endpoint, page: pageNum, limit: 50, q: _searchTerm);
      if (mounted) {
        setState(() {
          _page = pageNum;
          final List<Consignor> newEntries = res.map((e) => Consignor.fromJson(e)).toList();
          if (pageNum == 1) {
            _parties = newEntries;
          } else {
            _parties.addAll(newEntries);
          }
          _hasMore = newEntries.length >= 50;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ${widget.title.toLowerCase()} records: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyGST() async {
    final gstin = _gstinController.text.trim().toUpperCase();
    if (gstin.length != 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 15-digit GSTIN'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isFetchingGst = true);

    try {
      final res = await ApiService.verifyGST(gstin);
      final info = res['taxpayerInfo'];
      if (info == null) throw Exception('Invalid GSTIN details returned');

      final addr = info['pradr']?['addr'] ?? {};
      final name = info['tradeNam'] ?? info['lgnm'] ?? '';

      setState(() {
        _nameController.text = name;
        _panNumberController.text = gstin.substring(2, 12);
        
        List<String> addressParts = [];
        if (addr['bno'] != null && addr['bno'].toString().trim().isNotEmpty) addressParts.add(addr['bno'].toString().trim());
        if (addr['bnm'] != null && addr['bnm'].toString().trim().isNotEmpty) addressParts.add(addr['bnm'].toString().trim());
        if (addr['st'] != null && addr['st'].toString().trim().isNotEmpty) addressParts.add(addr['st'].toString().trim());
        
        _addressController.text = addressParts.join(', ');
        _cityController.text = addr['loc'] ?? addr['city'] ?? '';
        _districtController.text = addr['dst'] ?? '';
        _stateController.text = addr['stcd'] ?? '';
        _pincodeController.text = addr['pncd'] ?? addr['pincode'] ?? '';
        _gstVerified = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Taxpayer "$name" verified via GST portal!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('GST Verification Failed'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingGst = false);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.title} Name is required'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = {
        if (_id != null) 'id': _id,
        'name': name,
        'gstin': _gstinController.text.trim().toUpperCase(),
        'panNumber': _panNumberController.text.trim().toUpperCase(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'group': _groupController.text.trim(),
        'branch': 'MAIN'
      };

      if (_id != null) {
        await ApiService.updateParty(widget.endpoint, _id!, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('${widget.title} record updated successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        await ApiService.createParty(widget.endpoint, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('New ${widget.title} profile created successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }

      _clearForm();
      _fetchParties(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save record: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleEdit(Consignor p) {
    setState(() {
      _id = p.id;
      _nameController.text = p.name;
      _gstinController.text = p.gstin ?? '';
      _panNumberController.text = p.panNumber ?? (p.gstin != null && p.gstin!.length >= 12 ? p.gstin!.substring(2, 12) : '');
      _phoneController.text = p.phone ?? '';
      _emailController.text = p.email ?? '';
      _addressController.text = p.address ?? '';
      _cityController.text = p.city ?? '';
      _districtController.text = p.district ?? '';
      _stateController.text = p.state ?? '';
      _pincodeController.text = p.pincode ?? '';
      _groupController.text = p.group ?? '';
      _gstVerified = (p.gstin?.length ?? 0) == 15;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing "${p.name}" (ID #${p.id})'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleDelete(Consignor p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Delete ${widget.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${p.name}" from ${widget.title.toLowerCase()} records?\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteParty(widget.endpoint, p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} record deleted'),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      _fetchParties(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _clearForm() {
    setState(() {
      _id = null;
      _nameController.clear();
      _gstinController.clear();
      _panNumberController.clear();
      _phoneController.clear();
      _emailController.clear();
      _addressController.clear();
      _cityController.clear();
      _districtController.clear();
      _stateController.clear();
      _pincodeController.clear();
      _groupController.clear();
      _gstVerified = false;
    });
  }

  void _showPartyDetailModal(Consignor p) {
    final bool hasGst = (p.gstin?.trim().length ?? 0) == 15;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          width: 580,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _themeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_isConsignor ? Icons.domain_rounded : Icons.storefront_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${widget.title.toUpperCase()} PROFILE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('ID #${p.id}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Body Details
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // GST & Tax Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hasGst ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasGst ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: hasGst ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              hasGst ? Icons.verified_rounded : Icons.info_outline_rounded,
                              color: hasGst ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasGst ? 'GST REGISTERED TAXPAYER' : 'UNREGISTERED COMPOSITION / CONSUMER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: hasGst ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.gstin?.trim().isNotEmpty == true ? p.gstin! : 'No GSTIN registered',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (p.panNumber != null && p.panNumber!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('PAN NUMBER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                  Text(p.panNumber!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF0F172A))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Address Info
                    _buildModalInfoRow(
                      icon: Icons.location_on_rounded,
                      label: 'BILLING ADDRESS',
                      value: p.address?.trim().isNotEmpty == true ? p.address! : 'Not specified',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalInfoRow(
                            icon: Icons.location_city_rounded,
                            label: 'CITY / DISTRICT',
                            value: [p.city, p.district].where((e) => e != null && e.isNotEmpty).join(', ').isEmpty
                                ? 'Not specified'
                                : [p.city, p.district].where((e) => e != null && e.isNotEmpty).join(', '),
                          ),
                        ),
                        Expanded(
                          child: _buildModalInfoRow(
                            icon: Icons.map_rounded,
                            label: 'STATE & PINCODE',
                            value: [p.state, p.pincode].where((e) => e != null && e.isNotEmpty).join(' - ').isEmpty
                                ? 'Not specified'
                                : [p.state, p.pincode].where((e) => e != null && e.isNotEmpty).join(' - '),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalInfoRow(
                            icon: Icons.phone_rounded,
                            label: 'PHONE / MOBILE',
                            value: p.phone?.trim().isNotEmpty == true ? p.phone! : 'No phone',
                          ),
                        ),
                        Expanded(
                          child: _buildModalInfoRow(
                            icon: Icons.category_rounded,
                            label: 'PARTY GROUP',
                            value: p.group?.trim().isNotEmpty == true ? p.group! : 'General / Regular',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Modal Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Branch: ${p.branch ?? 'MAIN'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleEdit(p);
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themePrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
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

  Widget _buildModalInfoRow({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: padding ?? const EdgeInsets.all(24),
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

  Widget _buildDenseInput({
    required String label,
    required Widget child,
    String? tooltip,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            if (tooltip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip,
                child: const Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDeco({
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _themePrimary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int gstCount = _parties.where((p) => (p.gstin?.trim().length ?? 0) == 15).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Executive Header Cockpit
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  margin: const EdgeInsets.only(bottom: 24),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompact = constraints.maxWidth < 680;
                      final headerInfo = Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _themeGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _themePrimary.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isConsignor ? Icons.domain_rounded : Icons.storefront_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.title} Directory & Master',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Taxpayer-verified client profiles, automated GSTIN lookup & party billing addresses',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blueGrey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final kpiPills = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: _themePrimary, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_parties.length} Profiles',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                                const SizedBox(width: 6),
                                Text(
                                  '$gstCount GST Verified',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headerInfo,
                            const SizedBox(height: 14),
                            kpiPills,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: headerInfo),
                          const SizedBox(width: 16),
                          kpiPills,
                        ],
                      );
                    },
                  ),
                ),

                // Registration / Editing Form Card
                _buildGlassCard(
                  child: LayoutBuilder(
                    builder: (context, formConstraints) {
                      final bool isNarrow = formConstraints.maxWidth < 700;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header with Edit Banner
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _id != null ? const Color(0xFFFEF3C7) : _themePrimary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _id != null ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                                        color: _id != null ? const Color(0xFFD97706) : _themePrimary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _id != null ? 'Editing Profile #$_id' : 'Register New ${widget.title}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                          ),
                                          Text(
                                            _id != null
                                                ? 'Update fields below and press Save to commit changes.'
                                                : 'Enter GSTIN to instantly autofill legal name, PAN & registered billing address',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_id != null)
                                TextButton.icon(
                                  onPressed: _clearForm,
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  label: const Text('Cancel Edit'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    backgroundColor: const Color(0xFFFEE2E2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Row 1: Fast GSTIN Verification & Discovery
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: isNarrow
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildDenseInput(
                                        label: 'GSTIN (PORTAL VERIFICATION)',
                                        tooltip: 'Enter 15-digit GSTIN to autofill legal party information',
                                        child: TextFormField(
                                          controller: _gstinController,
                                          decoration: _inputDeco(
                                            hintText: 'e.g. 33AAAAA0000A1Z5',
                                            prefixIcon: Icons.badge_outlined,
                                            suffixIcon: _gstVerified
                                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                                                : null,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'monospace',
                                            letterSpacing: 0.8,
                                            color: Color(0xFF0F172A),
                                          ),
                                          textCapitalization: TextCapitalization.characters,
                                          onChanged: (val) {
                                            if (_gstVerified && val.length != 15) {
                                              setState(() => _gstVerified = false);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: _isFetchingGst ? null : _handleVerifyGST,
                                          icon: _isFetchingGst
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                )
                                              : const Icon(Icons.cloud_download_rounded, size: 18),
                                          label: const Text('Verify GST', style: TextStyle(fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _themePrimary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDenseInput(
                                        label: 'PAN NUMBER',
                                        child: TextFormField(
                                          controller: _panNumberController,
                                          decoration: _inputDeco(
                                            hintText: 'e.g. AAAAA0000A',
                                            prefixIcon: Icons.credit_card_rounded,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'monospace',
                                            color: Color(0xFF0F172A),
                                          ),
                                          textCapitalization: TextCapitalization.characters,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _buildDenseInput(
                                          label: 'GSTIN (PORTAL VERIFICATION)',
                                          tooltip: 'Enter 15-digit GSTIN to autofill legal party information',
                                          child: TextFormField(
                                            controller: _gstinController,
                                            decoration: _inputDeco(
                                              hintText: 'e.g. 33AAAAA0000A1Z5',
                                              prefixIcon: Icons.badge_outlined,
                                              suffixIcon: _gstVerified
                                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                                                  : null,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'monospace',
                                              letterSpacing: 0.8,
                                              color: Color(0xFF0F172A),
                                            ),
                                            textCapitalization: TextCapitalization.characters,
                                            onChanged: (val) {
                                              if (_gstVerified && val.length != 15) {
                                                setState(() => _gstVerified = false);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: _isFetchingGst ? null : _handleVerifyGST,
                                          icon: _isFetchingGst
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                )
                                              : const Icon(Icons.cloud_download_rounded, size: 18),
                                          label: const Text('Verify GST', style: TextStyle(fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _themePrimary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: _buildDenseInput(
                                          label: 'PAN NUMBER',
                                          child: TextFormField(
                                            controller: _panNumberController,
                                            decoration: _inputDeco(
                                              hintText: 'e.g. AAAAA0000A',
                                              prefixIcon: Icons.credit_card_rounded,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontFamily: 'monospace',
                                              color: Color(0xFF0F172A),
                                            ),
                                            textCapitalization: TextCapitalization.characters,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // Row 2: Legal Name & Group
                          if (isNarrow) ...[
                            _buildDenseInput(
                              label: '${widget.title.toUpperCase()} LEGAL NAME *',
                              child: TextFormField(
                                controller: _nameController,
                                decoration: _inputDeco(
                                  hintText: 'Full company or trade name',
                                  prefixIcon: _isConsignor ? Icons.domain_rounded : Icons.storefront_rounded,
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDenseInput(
                              label: 'PARTY GROUP / CATEGORY',
                              child: TextFormField(
                                controller: _groupController,
                                decoration: _inputDeco(
                                  hintText: 'e.g. Textile, Steel, Pharma',
                                  prefixIcon: Icons.folder_special_rounded,
                                ),
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildDenseInput(
                                    label: '${widget.title.toUpperCase()} LEGAL NAME *',
                                    child: TextFormField(
                                      controller: _nameController,
                                      decoration: _inputDeco(
                                        hintText: 'Full company or trade name',
                                        prefixIcon: _isConsignor ? Icons.domain_rounded : Icons.storefront_rounded,
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildDenseInput(
                                    label: 'PARTY GROUP / CATEGORY',
                                    child: TextFormField(
                                      controller: _groupController,
                                      decoration: _inputDeco(
                                        hintText: 'e.g. Textile, Steel, Pharma',
                                        prefixIcon: Icons.folder_special_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Row 3: Contact Details
                          if (isNarrow) ...[
                            _buildDenseInput(
                              label: 'PRIMARY PHONE / MOBILE',
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: _inputDeco(
                                  hintText: '10-digit mobile number',
                                  prefixIcon: Icons.phone_rounded,
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDenseInput(
                              label: 'OFFICIAL EMAIL ADDRESS',
                              child: TextFormField(
                                controller: _emailController,
                                decoration: _inputDeco(
                                  hintText: 'billing@company.com',
                                  prefixIcon: Icons.email_rounded,
                                ),
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDenseInput(
                              label: 'CITY / TOWN',
                              child: TextFormField(
                                controller: _cityController,
                                decoration: _inputDeco(
                                  hintText: 'e.g. Tirupur, Coimbatore',
                                  prefixIcon: Icons.location_city_rounded,
                                ),
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'PRIMARY PHONE / MOBILE',
                                    child: TextFormField(
                                      controller: _phoneController,
                                      decoration: _inputDeco(
                                        hintText: '10-digit mobile number',
                                        prefixIcon: Icons.phone_rounded,
                                      ),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'OFFICIAL EMAIL ADDRESS',
                                    child: TextFormField(
                                      controller: _emailController,
                                      decoration: _inputDeco(
                                        hintText: 'billing@company.com',
                                        prefixIcon: Icons.email_rounded,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'CITY / TOWN',
                                    child: TextFormField(
                                      controller: _cityController,
                                      decoration: _inputDeco(
                                        hintText: 'e.g. Tirupur, Coimbatore',
                                        prefixIcon: Icons.location_city_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Row 4: Address, District, State & Pincode
                          if (isNarrow) ...[
                            _buildDenseInput(
                              label: 'REGISTERED BILLING ADDRESS',
                              child: TextFormField(
                                controller: _addressController,
                                decoration: _inputDeco(
                                  hintText: 'Door No, Building, Street, Area',
                                  prefixIcon: Icons.place_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'DISTRICT',
                                    child: TextFormField(
                                      controller: _districtController,
                                      decoration: _inputDeco(hintText: 'District'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'STATE',
                                    child: TextFormField(
                                      controller: _stateController,
                                      decoration: _inputDeco(hintText: 'State / Code'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDenseInput(
                              label: 'PINCODE',
                              child: TextFormField(
                                controller: _pincodeController,
                                decoration: _inputDeco(hintText: '6-digit PIN'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildDenseInput(
                                    label: 'REGISTERED BILLING ADDRESS',
                                    child: TextFormField(
                                      controller: _addressController,
                                      decoration: _inputDeco(
                                        hintText: 'Door No, Building, Street, Area',
                                        prefixIcon: Icons.place_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildDenseInput(
                                    label: 'DISTRICT',
                                    child: TextFormField(
                                      controller: _districtController,
                                      decoration: _inputDeco(hintText: 'District'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildDenseInput(
                                    label: 'STATE',
                                    child: TextFormField(
                                      controller: _stateController,
                                      decoration: _inputDeco(hintText: 'State / Code'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildDenseInput(
                                    label: 'PINCODE',
                                    child: TextFormField(
                                      controller: _pincodeController,
                                      decoration: _inputDeco(hintText: '6-digit PIN'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),

                          // Form Action Buttons
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              TextButton.icon(
                                onPressed: _clearForm,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Clear Form'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _themeGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _themePrimary.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleSave,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Icon(_id != null ? Icons.save_rounded : Icons.add_circle_outline_rounded, size: 18),
                                  label: Text(
                                    _id != null ? 'Update ${widget.title} Profile' : 'Save & Register ${widget.title}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Directory Search & Table Register
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isSearchNarrow = constraints.maxWidth < 680;
                    final searchTitle = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.title} Directory Register',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Showing ${_parties.length} loaded records • Scroll down for lazy pagination',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    );

                    final searchInput = SizedBox(
                      width: isSearchNarrow ? double.infinity : 340,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by Name, City or GSTIN...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchTerm = '';
                                    _fetchParties(1);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _themePrimary),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (val) {
                          _searchTerm = val;
                          _fetchParties(1);
                        },
                      ),
                    );

                    if (isSearchNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchTitle,
                          const SizedBox(height: 12),
                          searchInput,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        searchTitle,
                        searchInput,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Table Card
                _buildGlassCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LayoutBuilder(
                      builder: (context, tableConstraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableConstraints.maxWidth < 860 ? 860 : tableConstraints.maxWidth,
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 3, child: Text('PARTY / ENTITY NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                                      Expanded(flex: 2, child: Text('CITY / STATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                                      Expanded(flex: 2, child: Text('GSTIN STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                                      Expanded(flex: 2, child: Text('CONTACT PHONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                                      SizedBox(width: 140, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5), textAlign: TextAlign.right)),
                                    ],
                                  ),
                                ),

                                // Table Body
                                if (_parties.isEmpty && !_isLoading)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF1F5F9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _isConsignor ? Icons.domain_disabled_rounded : Icons.store_mall_directory_outlined,
                                              size: 40,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No ${widget.title.toLowerCase()} records found',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF334155)),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Try searching with a different name or add a new record above.',
                                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 440,
                                    child: ListView.separated(
                                      controller: _scrollController,
                                      itemCount: _parties.length + (_hasMore ? 1 : 0),
                                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (context, index) {
                                        if (index == _parties.length) {
                                          return Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Center(
                                              child: _isLoading
                                                  ? SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(color: _themePrimary, strokeWidth: 2),
                                                    )
                                                  : const Text('Scroll for more records', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                            ),
                                          );
                                        }

                                        final p = _parties[index];
                                        final bool hasGst = (p.gstin?.trim().length ?? 0) == 15;

                                        return InkWell(
                                          onTap: () => _showPartyDetailModal(p),
                                          hoverColor: const Color(0xFFF8FAFC),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            child: Row(
                                              children: [
                                                // Name & Group
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                          color: _themePrimary.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            p.name.isNotEmpty ? p.name.substring(0, 1).toUpperCase() : '?',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: 15,
                                                              color: _themePrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              p.name,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w800,
                                                                fontSize: 13,
                                                                color: Color(0xFF0F172A),
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            if (p.group != null && p.group!.isNotEmpty)
                                                              Text(
                                                                p.group!,
                                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // City / State
                                                Expanded(
                                                  flex: 2,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        p.city?.trim().isNotEmpty == true ? p.city! : '-',
                                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155)),
                                                      ),
                                                      if (p.state != null && p.state!.isNotEmpty)
                                                        Text(
                                                          p.state!,
                                                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                                        ),
                                                    ],
                                                  ),
                                                ),

                                                // GSTIN Status Pill
                                                Expanded(
                                                  flex: 2,
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: hasGst ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(
                                                            color: hasGst ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              hasGst ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                                              size: 11,
                                                              color: hasGst ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              hasGst ? p.gstin! : 'UNREGISTERED',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w800,
                                                                fontFamily: hasGst ? 'monospace' : null,
                                                                color: hasGst ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Phone
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    p.phone?.trim().isNotEmpty == true ? p.phone! : '-',
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                                  ),
                                                ),

                                                // Actions
                                                SizedBox(
                                                  width: 140,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                                                        tooltip: 'View Full Profile',
                                                        onPressed: () => _showPartyDetailModal(p),
                                                        constraints: const BoxConstraints(),
                                                        padding: const EdgeInsets.all(6),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                                                        tooltip: 'Edit Record',
                                                        onPressed: () => _handleEdit(p),
                                                        constraints: const BoxConstraints(),
                                                        padding: const EdgeInsets.all(6),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                        tooltip: 'Delete Record',
                                                        onPressed: () => _handleDelete(p),
                                                        constraints: const BoxConstraints(),
                                                        padding: const EdgeInsets.all(6),
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
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
