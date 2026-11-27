import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/driver.dart';
import '../services/api_service.dart';

class DriverMasterScreen extends StatefulWidget {
  const DriverMasterScreen({super.key});

  @override
  State<DriverMasterScreen> createState() => _DriverMasterScreenState();
}

class _DriverMasterScreenState extends State<DriverMasterScreen> {
  // List & Pagination State
  List<Driver> _drivers = [];
  bool _isLoading = false;
  bool _isSaving = false;
  int _page = 1;
  int _totalRecords = 0;
  bool _hasMore = true;

  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _tableScrollController = ScrollController();

  // Search State (400ms debounced like React DriverMaster.jsx)
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedSearch = '';

  // Form State (1:1 with React DriverMaster formData)
  int? _id;
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _rtoController = TextEditingController();
  final TextEditingController _validityNtController = TextEditingController();
  final TextEditingController _validityTrController = TextEditingController();
  String _status = 'Active';

  static const List<String> _statusOptions = ['Active', 'Inactive', 'Blacklisted'];
  static const Color _emerald = Color(0xFF059669);
  static const Color _emeraldDark = Color(0xFF064E3B);

  @override
  void initState() {
    super.initState();
    _fetchDrivers(1);
    _tableScrollController.addListener(_onTableScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pageScrollController.dispose();
    _tableScrollController.dispose();
    _searchController.dispose();
    _licenseController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _bloodGroupController.dispose();
    _rtoController.dispose();
    _validityNtController.dispose();
    _validityTrController.dispose();
    super.dispose();
  }

  void _onTableScroll() {
    if (_tableScrollController.hasClients &&
        _tableScrollController.position.pixels >=
            _tableScrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchDrivers(_page + 1);
    }
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _debouncedSearch = val.trim();
      _fetchDrivers(1);
    });
  }

  Future<void> _fetchDrivers(int pageNum) async {
    if (_isLoading && pageNum > 1) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.getDriversPaginated(
        page: pageNum,
        limit: 50,
        q: _debouncedSearch,
      );
      final List<dynamic> rawList = (res['data'] as List?) ?? [];
      final List<Driver> fetched = rawList
          .map((e) => Driver.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          _page = pageNum;
          _totalRecords = (res['total'] as int?) ?? fetched.length;
          _hasMore = res['hasMore'] == true;
          if (pageNum == 1) {
            _drivers = fetched;
          } else {
            final existingIds = _drivers.map((d) => d.id).toSet();
            for (final item in fetched) {
              if (!existingIds.contains(item.id)) {
                _drivers.add(item);
              }
            }
          }
        });
      }
    } catch (e) {
      _showToast('Failed to fetch data.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final license = _licenseController.text.trim().toUpperCase();
    if (name.isEmpty) {
      _showToast('Driver Name is required', isError: true);
      return;
    }
    if (license.isEmpty) {
      _showToast('License Number is required', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> payload = {
        'licenseNumber': license,
        'name': name,
        'phone': _phoneController.text.trim(),
        'dob': _dobController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim(),
        'rto': _rtoController.text.trim(),
        'status': _status,
        'validityNt': _validityNtController.text.trim(),
        'validityTr': _validityTrController.text.trim(),
      };

      if (_id != null) {
        await ApiService.updateDriver(_id!, {...payload, 'id': _id});
        _showToast('Driver updated successfully');
      } else {
        await ApiService.createDriver(payload);
        _showToast('Driver created successfully');
      }

      _clearForm();
      _fetchDrivers(1);
    } catch (e) {
      _showToast('Failed to save record: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleEdit(Driver d) {
    setState(() {
      _id = d.id;
      _licenseController.text = d.licenseNumber;
      _nameController.text = d.name;
      _phoneController.text = d.phone ?? '';
      _dobController.text = d.dob ?? '';
      _bloodGroupController.text = d.bloodGroup ?? '';
      _rtoController.text = d.rto ?? '';
      _status = (d.status != null && d.status!.trim().isNotEmpty) ? d.status! : 'Active';
      _validityNtController.text = d.validityNt ?? '';
      _validityTrController.text = d.validityTr ?? '';
    });

    if (_pageScrollController.hasClients) {
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleDelete(Driver d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Driver?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to delete "${d.name}"?',
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
      await ApiService.deleteDriver(d.id);
      _showToast('Driver deleted');
      _fetchDrivers(1);
    } catch (e) {
      _showToast('Failed to delete driver', isError: true);
    }
  }

  void _clearForm() {
    setState(() {
      _id = null;
      _licenseController.clear();
      _nameController.clear();
      _phoneController.clear();
      _dobController.clear();
      _bloodGroupController.clear();
      _rtoController.clear();
      _status = 'Active';
      _validityNtController.clear();
      _validityTrController.clear();
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

  List<Driver> get _filteredDrivers {
    final term = _searchController.text.trim().toLowerCase();
    if (term.isEmpty) return _drivers;
    return _drivers.where((d) {
      return d.name.toLowerCase().contains(term) ||
          d.licenseNumber.toLowerCase().contains(term) ||
          (d.phone?.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  // --- UI PRIMITIVES (React GlassCard + DenseInput + DenseSelect parity) ---

  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
    bool boldEmerald = false,
    bool uppercase = false,
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
          textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
          onChanged: (val) {
            if (uppercase && val != val.toUpperCase()) {
              controller.value = controller.value.copyWith(
                text: val.toUpperCase(),
                selection: TextSelection.collapsed(offset: val.length),
              );
            }
          },
          style: TextStyle(
            fontSize: 14,
            fontWeight: boldEmerald ? FontWeight.w700 : FontWeight.w500,
            color: boldEmerald ? _emeraldDark : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
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
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _denseSelect({
    required String label,
    required String value,
    required List<String> baseOptions,
    required ValueChanged<String> onChanged,
  }) {
    final List<String> safeOptions = [
      ...baseOptions,
      if (!baseOptions.contains(value) && value.trim().isNotEmpty) value,
    ];

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
        InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
              items: safeOptions
                  .map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(String? rawStatus) {
    final String s = (rawStatus?.trim().isNotEmpty == true) ? rawStatus! : 'Active';
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF475569);
    if (s == 'Active') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
    } else if (s == 'Blacklisted') {
      bg = const Color(0xFFFFE4E6);
      fg = const Color(0xFFBE123C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        s.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.4),
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _glassCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= 780;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section Header
                  Container(
                    padding: const EdgeInsets.only(bottom: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 16, color: _emerald),
                        const SizedBox(width: 8),
                        const Text(
                          'Driver Identity',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        if (_id != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD1FAE5)),
                            ),
                            child: Text(
                              'Editing #$_id',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _emerald),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Row 1: License Number * (2 cols) | Driver Name * (2 cols)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _denseField(
                            label: 'License Number *',
                            controller: _licenseController,
                            boldEmerald: true,
                            uppercase: true,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _denseField(
                            label: 'Driver Name *',
                            controller: _nameController,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _denseField(
                      label: 'License Number *',
                      controller: _licenseController,
                      boldEmerald: true,
                      uppercase: true,
                    ),
                    const SizedBox(height: 12),
                    _denseField(label: 'Driver Name *', controller: _nameController),
                  ],

                  // Row 2 (5-col grid): Phone Number | Date of Birth | Blood Group | RTO | Status
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _denseField(
                                  label: 'Phone Number',
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _denseField(
                                  label: 'Date of Birth',
                                  controller: _dobController,
                                  placeholder: 'DD/MM/YYYY',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _denseField(
                                  label: 'Blood Group',
                                  controller: _bloodGroupController,
                                  placeholder: 'e.g. O+',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _denseField(
                                  label: 'RTO',
                                  controller: _rtoController,
                                  placeholder: 'e.g. TN67',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _denseSelect(
                                  label: 'Status',
                                  value: _status,
                                  baseOptions: _statusOptions,
                                  onChanged: (v) => setState(() => _status = v),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _denseField(
                                label: 'Phone Number',
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _denseField(
                                      label: 'Date of Birth',
                                      controller: _dobController,
                                      placeholder: 'DD/MM/YYYY',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _denseField(
                                      label: 'Blood Group',
                                      controller: _bloodGroupController,
                                      placeholder: 'e.g. O+',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _denseField(
                                      label: 'RTO',
                                      controller: _rtoController,
                                      placeholder: 'e.g. TN67',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _denseSelect(
                                      label: 'Status',
                                      value: _status,
                                      baseOptions: _statusOptions,
                                      onChanged: (v) => setState(() => _status = v),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),

                  // Row 3 (2-col grid): Validity (Non-Transport) | Validity (Transport)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _denseField(
                                  label: 'Validity (Non-Transport)',
                                  controller: _validityNtController,
                                  placeholder: 'DD/MM/YYYY',
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _denseField(
                                  label: 'Validity (Transport)',
                                  controller: _validityTrController,
                                  placeholder: 'DD/MM/YYYY',
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _denseField(
                                label: 'Validity (Non-Transport)',
                                controller: _validityNtController,
                                placeholder: 'DD/MM/YYYY',
                              ),
                              const SizedBox(height: 12),
                              _denseField(
                                label: 'Validity (Transport)',
                                controller: _validityTrController,
                                placeholder: 'DD/MM/YYYY',
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Separate Action Buttons GlassCard (matching React DriverMaster.jsx lines 222-233)
        _glassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _clearForm,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Clear Form', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  _id != null ? 'Update Record' : 'Save Driver Record',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  minimumSize: const Size(180, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCard() {
    final rows = _filteredDrivers;
    final int countDisplay = _totalRecords > 0 ? _totalRecords : _drivers.length;

    return _glassCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 720;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Saved Drivers (count) + Search driver or license...
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Saved Drivers ',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        children: [
                          TextSpan(
                            text: '($countDisplay)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 256,
                      height: 34,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          hintText: 'Search driver or license...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Color(0xFF94A3B8)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
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
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (rows.isEmpty && !_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Center(
                    child: Text(
                      'No drivers found.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else if (isMobile)
                SizedBox(
                  height: 400,
                  child: ListView.separated(
                    controller: _tableScrollController,
                    itemCount: rows.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      if (index == rows.length) return _buildLoadMoreFooter();
                      final d = rows[index];
                      return Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '${index + 1}.',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                      ),
                                      Text(
                                        d.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                      ),
                                      _buildStatusPill(d.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.credit_card_rounded, size: 13, color: Color(0xFF10B981)),
                                      const SizedBox(width: 5),
                                      Text(
                                        d.licenseNumber,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                      ),
                                    ],
                                  ),
                                  if (d.phone?.trim().isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(d.phone!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  if (d.validityNt?.trim().isNotEmpty == true || d.validityTr?.trim().isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        [
                                          if (d.validityNt?.trim().isNotEmpty == true) 'NT: ${d.validityNt}',
                                          if (d.validityTr?.trim().isNotEmpty == true) 'TR: ${d.validityTr}',
                                        ].join('  •  '),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _buildActionIcons(d),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                Column(
                  children: [
                    // Desktop Table Header (1:1 with React DriverMaster.jsx lines 254-261)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text('S.NO', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text('LICENSE NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text('NAME & PHONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('VALIDITIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 400,
                      child: ListView.separated(
                        controller: _tableScrollController,
                        itemCount: rows.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          if (index == rows.length) return _buildLoadMoreFooter();
                          final d = rows[index];
                          final bool hasNt = d.validityNt?.trim().isNotEmpty == true;
                          final bool hasTr = d.validityTr?.trim().isNotEmpty == true;

                          return Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Icon(Icons.credit_card_rounded, size: 14, color: const Color(0xFF10B981).withValues(alpha: 0.65)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          d.licenseNumber,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                      ),
                                      if (d.phone?.trim().isNotEmpty == true)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.phone_outlined, size: 10, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(d.phone!, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (hasNt)
                                        Text(
                                          'NT: ${d.validityNt}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.4),
                                        ),
                                      if (hasTr)
                                        Padding(
                                          padding: EdgeInsets.only(top: hasNt ? 2 : 0),
                                          child: Text(
                                            'TR: ${d.validityTr}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.4),
                                          ),
                                        ),
                                      if (!hasNt && !hasTr)
                                        const Text('-', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildStatusPill(d.status),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: _buildActionIcons(d),
                                ),
                              ],
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

  Widget _buildActionIcons(Driver d) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleEdit(d),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF475569)),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleDelete(d),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadMoreFooter() {
    return InkWell(
      onTap: _isLoading ? null : () => _fetchDrivers(_page + 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: _isLoading
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                    ),
                    SizedBox(width: 8),
                    Text('Loading more...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                  ],
                )
              : const Text('Scroll for more', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _handleSave,
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
                    // HEADER CARD (1:1 with React DriverMaster.jsx lines 176-186)
                    _glassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD1FAE5)),
                            ),
                            child: const Icon(Icons.person_outline_rounded, size: 22, color: _emerald),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver Master',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Manage drivers, contact details, and license validity.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // FORM + ACTION CARDS
                    _buildFormSection(),

                    const SizedBox(height: 16),

                    // SAVED DRIVERS TABLE CARD
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
