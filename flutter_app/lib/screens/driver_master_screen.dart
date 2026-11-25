import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/driver.dart';

class DriverMasterScreen extends StatefulWidget {
  const DriverMasterScreen({super.key});

  @override
  State<DriverMasterScreen> createState() => _DriverMasterScreenState();
}

class _DriverMasterScreenState extends State<DriverMasterScreen> {
  List<Driver> _drivers = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  // Form State
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

  final List<String> _statusOptions = ['Active', 'Inactive', 'Blacklisted'];

  static const List<Color> _themeGradient = [Color(0xFF0F766E), Color(0xFF0D9488)];
  static const Color _themePrimary = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    _fetchDrivers(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading && _hasMore) {
      _fetchDrivers(_page + 1);
    }
  }

  Future<void> _fetchDrivers(int pageNum) async {
    setState(() => _isLoading = true);
    
    try {
      final res = await ApiService.getDriversPaginated(page: pageNum, limit: 50, q: _searchTerm);
      if (mounted) {
        setState(() {
          _page = pageNum;
          if (res['data'] != null) {
            final List<Driver> newEntries = (res['data'] as List).map((e) => Driver.fromJson(e)).toList();
            if (pageNum == 1) {
              _drivers = newEntries;
            } else {
              _drivers.addAll(newEntries);
            }
            _hasMore = res['hasMore'] ?? false; 
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load drivers: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final license = _licenseController.text.trim().toUpperCase();
    if (name.isEmpty || license.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver Name and License Number are mandatory'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = {
        if (_id != null) 'id': _id,
        'name': name,
        'licenseNumber': license,
        'phone': _phoneController.text.trim(),
        'dob': _dobController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim().toUpperCase(),
        'rto': _rtoController.text.trim().toUpperCase(),
        'status': _status,
        'validityNt': _validityNtController.text.trim(),
        'validityTr': _validityTrController.text.trim(),
      };

      if (_id != null) {
        await ApiService.updateDriver(_id!, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Driver "$name" record updated successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        await ApiService.createDriver(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('New driver "$name" onboarded successfully!'),
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
      _fetchDrivers(1);
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

  void _handleEdit(Driver d) {
    setState(() {
      _id = d.id;
      _nameController.text = d.name;
      _licenseController.text = d.licenseNumber;
      _phoneController.text = d.phone ?? '';
      _dobController.text = d.dob ?? '';
      _bloodGroupController.text = d.bloodGroup ?? '';
      _rtoController.text = d.rto ?? '';
      _status = _statusOptions.contains(d.status) ? d.status! : 'Active';
      _validityNtController.text = d.validityNt ?? '';
      _validityTrController.text = d.validityTr ?? '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing driver "${d.name}" (ID #${d.id})'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleDelete(Driver d) async {
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
            const Text('Delete Driver Record', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove driver "${d.name}" (${d.licenseNumber})?\nThis action cannot be undone.',
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
      await ApiService.deleteDriver(d.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver ${d.name} deleted'),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      _fetchDrivers(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete driver: $e'),
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
      _licenseController.clear();
      _phoneController.clear();
      _dobController.clear();
      _bloodGroupController.clear();
      _rtoController.clear();
      _validityNtController.clear();
      _validityTrController.clear();
      _status = 'Active';
    });
  }

  void _showDriverDetailModal(Driver d) {
    final bool isActive = (d.status ?? 'Active').toLowerCase() == 'active';
    final bool isBlacklisted = (d.status ?? '').toLowerCase() == 'blacklisted';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: _themeGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.badge_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'COMMERCIAL DRIVER PROFILE',
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
                                    child: Text('ID #${d.id}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                d.name,
                                style: const TextStyle(
                                  fontSize: 20,
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

                  // Body Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, modalConstraints) {
                        final isCompact = modalConstraints.maxWidth < 460;
                        return Column(
                          children: [
                            // Status & License Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isBlacklisted
                                    ? const Color(0xFFFEF2F2)
                                    : (isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isBlacklisted
                                      ? const Color(0xFFFECACA)
                                      : (isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: isCompact
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isBlacklisted
                                                    ? const Color(0xFFFEE2E2)
                                                    : (isActive ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0)),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isBlacklisted
                                                    ? Icons.block_rounded
                                                    : (isActive ? Icons.verified_user_rounded : Icons.pause_circle_outline_rounded),
                                                color: isBlacklisted
                                                    ? const Color(0xFFDC2626)
                                                    : (isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Text(
                                                d.status?.toUpperCase() ?? 'ACTIVE',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isBlacklisted
                                                      ? const Color(0xFFDC2626)
                                                      : (isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'COMMERCIAL DRIVING LICENSE (DL)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: isBlacklisted
                                                ? const Color(0xFFB91C1C)
                                                : (isActive ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          d.licenseNumber,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'monospace',
                                            color: Color(0xFF0F172A),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isBlacklisted
                                                ? const Color(0xFFFEE2E2)
                                                : (isActive ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0)),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isBlacklisted
                                                ? Icons.block_rounded
                                                : (isActive ? Icons.verified_user_rounded : Icons.pause_circle_outline_rounded),
                                            color: isBlacklisted
                                                ? const Color(0xFFDC2626)
                                                : (isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'COMMERCIAL DRIVING LICENSE (DL)',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                  color: isBlacklisted
                                                      ? const Color(0xFFB91C1C)
                                                      : (isActive ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                d.licenseNumber,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  fontFamily: 'monospace',
                                                  color: Color(0xFF0F172A),
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(
                                            d.status?.toUpperCase() ?? 'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isBlacklisted
                                                  ? const Color(0xFFDC2626)
                                                  : (isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 18),

                            // Phone & RTO
                            if (isCompact) ...[
                              _buildModalInfoBox(
                                icon: Icons.phone_rounded,
                                label: 'PHONE NUMBER',
                                value: d.phone?.trim().isNotEmpty == true ? d.phone! : 'No phone registered',
                              ),
                              const SizedBox(height: 10),
                              _buildModalInfoBox(
                                icon: Icons.account_balance_rounded,
                                label: 'ISSUING RTO AUTHORITY',
                                value: d.rto?.trim().isNotEmpty == true ? d.rto! : 'Not specified',
                              ),
                            ] else
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildModalInfoBox(
                                      icon: Icons.phone_rounded,
                                      label: 'PHONE NUMBER',
                                      value: d.phone?.trim().isNotEmpty == true ? d.phone! : 'No phone registered',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildModalInfoBox(
                                      icon: Icons.account_balance_rounded,
                                      label: 'ISSUING RTO AUTHORITY',
                                      value: d.rto?.trim().isNotEmpty == true ? d.rto! : 'Not specified',
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),

                            // Demographics: Blood Group & DOB
                            if (isCompact) ...[
                              _buildModalInfoBox(
                                icon: Icons.bloodtype_rounded,
                                label: 'BLOOD GROUP',
                                value: d.bloodGroup?.trim().isNotEmpty == true ? d.bloodGroup! : 'Not specified',
                              ),
                              const SizedBox(height: 10),
                              _buildModalInfoBox(
                                icon: Icons.cake_rounded,
                                label: 'DATE OF BIRTH',
                                value: d.dob?.trim().isNotEmpty == true ? d.dob! : 'Not specified',
                              ),
                            ] else
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildModalInfoBox(
                                      icon: Icons.bloodtype_rounded,
                                      label: 'BLOOD GROUP',
                                      value: d.bloodGroup?.trim().isNotEmpty == true ? d.bloodGroup! : 'Not specified',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildModalInfoBox(
                                      icon: Icons.cake_rounded,
                                      label: 'DATE OF BIRTH',
                                      value: d.dob?.trim().isNotEmpty == true ? d.dob! : 'Not specified',
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 18),

                            // License Validity Box
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('STATUTORY LICENSE PERMITS & VALIDITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                  const SizedBox(height: 10),
                                  if (isCompact) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('NON-TRANSPORT (NT)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                                          const SizedBox(height: 2),
                                          Text(
                                            d.validityNt?.trim().isNotEmpty == true ? d.validityNt! : 'N/A',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('COMMERCIAL TRANSPORT (TR)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                          const SizedBox(height: 2),
                                          Text(
                                            d.validityTr?.trim().isNotEmpty == true ? d.validityTr! : 'N/A',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF15803D)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('NON-TRANSPORT (NT)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                                                const SizedBox(height: 2),
                                                Text(
                                                  d.validityNt?.trim().isNotEmpty == true ? d.validityNt! : 'N/A',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('COMMERCIAL TRANSPORT (TR)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                                const SizedBox(height: 2),
                                                Text(
                                                  d.validityTr?.trim().isNotEmpty == true ? d.validityTr! : 'N/A',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Color(0xFF15803D)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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
                  mainAxisAlignment: MainAxisAlignment.end,
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
                        _handleEdit(d);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _themePrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildModalInfoBox({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        borderSide: const BorderSide(color: _themePrimary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int activeCount = _drivers.where((d) => (d.status ?? 'Active').toLowerCase() == 'active').length;

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
                // Header Card
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
                      final isMobile = constraints.maxWidth < 680;
                      return isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
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
                                      child: const Icon(Icons.badge_rounded, color: Colors.white, size: 26),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Driver & Commercial Crew Registry',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Commercial driving licenses, transport validity permits, emergency blood groups & RTO verification',
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
                                ),
                                const SizedBox(height: 14),
                                Wrap(
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
                                            decoration: const BoxDecoration(color: _themePrimary, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_drivers.length} Drivers',
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
                                          const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$activeCount Active On-Duty',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
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
                                  child: const Icon(Icons.badge_rounded, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Driver & Commercial Crew Registry',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Commercial driving licenses, transport validity permits, emergency blood groups & RTO verification',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blueGrey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
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
                                            decoration: const BoxDecoration(color: _themePrimary, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_drivers.length} Drivers',
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
                                          const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFF16A34A)),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$activeCount Active On-Duty',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                    },
                  ),
                ),

                // Form Card
                _buildGlassCard(
                  child: LayoutBuilder(
                    builder: (context, formConstraints) {
                      final isMobile = formConstraints.maxWidth < 750;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                            _id != null ? 'Editing Driver Profile #$_id' : 'Register New Commercial Driver',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                          ),
                                          Text(
                                            _id != null
                                                ? 'Update driver credentials and press save to commit changes.'
                                                : 'Enter driving license number, personal demographics & statutory permit validities',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_id != null) ...[
                                  const SizedBox(height: 10),
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
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _id != null ? 'Editing Driver Profile #$_id' : 'Register New Commercial Driver',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          _id != null
                                              ? 'Update driver credentials and press save to commit changes.'
                                              : 'Enter driving license number, personal demographics & statutory permit validities',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ],
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

                          // Row 1: License Number & Name & Status
                          if (isMobile) ...[
                            _buildDenseInput(
                              label: 'DRIVING LICENSE NUMBER *',
                              tooltip: 'Indian commercial DL format e.g. TN38 20180001234',
                              child: TextFormField(
                                controller: _licenseController,
                                decoration: _inputDeco(
                                  hintText: 'e.g. TN38 20180001234',
                                  prefixIcon: Icons.badge_outlined,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  color: _themePrimary,
                                  letterSpacing: 0.8,
                                ),
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildDenseInput(
                              label: 'DRIVER LEGAL NAME *',
                              child: TextFormField(
                                controller: _nameController,
                                decoration: _inputDeco(
                                  hintText: 'Full name as per driving license',
                                  prefixIcon: Icons.person_rounded,
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildDenseInput(
                              label: 'OPERATIONAL STATUS',
                              child: DropdownButtonFormField<String>(
                                value: _status,
                                decoration: _inputDeco(),
                                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _status = val);
                                },
                              ),
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildDenseInput(
                                    label: 'DRIVING LICENSE NUMBER *',
                                    tooltip: 'Indian commercial DL format e.g. TN38 20180001234',
                                    child: TextFormField(
                                      controller: _licenseController,
                                      decoration: _inputDeco(
                                        hintText: 'e.g. TN38 20180001234',
                                        prefixIcon: Icons.badge_outlined,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                        color: _themePrimary,
                                        letterSpacing: 0.8,
                                      ),
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: _buildDenseInput(
                                    label: 'DRIVER LEGAL NAME *',
                                    child: TextFormField(
                                      controller: _nameController,
                                      decoration: _inputDeco(
                                        hintText: 'Full name as per driving license',
                                        prefixIcon: Icons.person_rounded,
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildDenseInput(
                                    label: 'OPERATIONAL STATUS',
                                    child: DropdownButtonFormField<String>(
                                      value: _status,
                                      decoration: _inputDeco(),
                                      items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _status = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Row 2: Phone, DOB, Blood Group, RTO
                          if (isMobile) ...[
                            _buildDenseInput(
                              label: 'PRIMARY MOBILE PHONE',
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: _inputDeco(hintText: '10-digit mobile number', prefixIcon: Icons.phone_rounded),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'DATE OF BIRTH',
                                    child: TextFormField(
                                      controller: _dobController,
                                      decoration: _inputDeco(hintText: 'DD/MM/YYYY', prefixIcon: Icons.calendar_today_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'BLOOD GROUP',
                                    child: TextFormField(
                                      controller: _bloodGroupController,
                                      decoration: _inputDeco(hintText: 'e.g. O+, B+', prefixIcon: Icons.bloodtype_rounded),
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildDenseInput(
                              label: 'ISSUING RTO AUTHORITY',
                              child: TextFormField(
                                controller: _rtoController,
                                decoration: _inputDeco(hintText: 'e.g. TN-38 Coimbatore North', prefixIcon: Icons.account_balance_rounded),
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildDenseInput(
                                    label: 'PRIMARY MOBILE PHONE',
                                    child: TextFormField(
                                      controller: _phoneController,
                                      decoration: _inputDeco(hintText: '10-digit mobile number', prefixIcon: Icons.phone_rounded),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildDenseInput(
                                    label: 'DATE OF BIRTH',
                                    child: TextFormField(
                                      controller: _dobController,
                                      decoration: _inputDeco(hintText: 'DD/MM/YYYY', prefixIcon: Icons.calendar_today_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildDenseInput(
                                    label: 'BLOOD GROUP',
                                    child: TextFormField(
                                      controller: _bloodGroupController,
                                      decoration: _inputDeco(hintText: 'e.g. O+, B+', prefixIcon: Icons.bloodtype_rounded),
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildDenseInput(
                                    label: 'ISSUING RTO AUTHORITY',
                                    child: TextFormField(
                                      controller: _rtoController,
                                      decoration: _inputDeco(hintText: 'e.g. TN-38 Coimbatore North', prefixIcon: Icons.account_balance_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          // Row 3: Validities
                          if (isMobile) ...[
                            _buildDenseInput(
                              label: 'NON-TRANSPORT (NT) VALIDITY',
                              child: TextFormField(
                                controller: _validityNtController,
                                decoration: _inputDeco(hintText: 'DD/MM/YYYY or YYYY-MM-DD', prefixIcon: Icons.event_available_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildDenseInput(
                              label: 'COMMERCIAL TRANSPORT (TR) VALIDITY',
                              child: TextFormField(
                                controller: _validityTrController,
                                decoration: _inputDeco(hintText: 'DD/MM/YYYY or YYYY-MM-DD', prefixIcon: Icons.local_shipping_rounded),
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'NON-TRANSPORT (NT) VALIDITY',
                                    child: TextFormField(
                                      controller: _validityNtController,
                                      decoration: _inputDeco(hintText: 'DD/MM/YYYY or YYYY-MM-DD', prefixIcon: Icons.event_available_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'COMMERCIAL TRANSPORT (TR) VALIDITY',
                                    child: TextFormField(
                                      controller: _validityTrController,
                                      decoration: _inputDeco(hintText: 'DD/MM/YYYY or YYYY-MM-DD', prefixIcon: Icons.local_shipping_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),

                          // Actions
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
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
                                    gradient: const LinearGradient(
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
                                      _id != null ? 'Update Driver Profile' : 'Save & Register Driver',
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
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Search Bar & Directory Title
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 680;
                    return isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Driver Master Directory',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Showing ${_drivers.length} commercial drivers • Scroll for lazy pagination',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search driver by Name, DL or Phone...',
                                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            _searchTerm = '';
                                            _fetchDrivers(1);
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
                                    borderSide: const BorderSide(color: _themePrimary),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onChanged: (val) {
                                  _searchTerm = val;
                                  _fetchDrivers(1);
                                },
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Driver Master Directory',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Showing ${_drivers.length} commercial drivers • Scroll for lazy pagination',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 340,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search driver by Name, DL or Phone...',
                                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () {
                                              _searchController.clear();
                                              _searchTerm = '';
                                              _fetchDrivers(1);
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
                                      borderSide: const BorderSide(color: _themePrimary),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  onChanged: (val) {
                                    _searchTerm = val;
                                    _fetchDrivers(1);
                                  },
                                ),
                              ),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 14),

                // Table
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
                              Expanded(flex: 3, child: Text('DRIVER & LICENSE NUMBER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              Expanded(flex: 2, child: Text('CONTACT PHONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              Expanded(flex: 2, child: Text('PERMIT VALIDITIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              Expanded(flex: 1, child: Text('BLOOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              SizedBox(width: 140, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),

                        // Table Body
                        if (_drivers.isEmpty && !_isLoading)
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
                                    child: const Icon(Icons.person_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No drivers found in registry.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF334155))),
                                  const SizedBox(height: 4),
                                  const Text('Onboard your first commercial driver or clear your search query above.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 440,
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount: _drivers.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                if (index == _drivers.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Center(child: Text('Scroll for more drivers', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                                  );
                                }
                                final d = _drivers[index];
                                final bool isActive = (d.status ?? 'Active').toLowerCase() == 'active';
                                final bool isBlacklisted = (d.status ?? '').toLowerCase() == 'blacklisted';

                                return InkWell(
                                  onTap: () => _showDriverDetailModal(d),
                                  hoverColor: const Color(0xFFF8FAFC),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    child: Row(
                                      children: [
                                        // Name & License
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
                                                    d.name.isNotEmpty ? d.name.substring(0, 1).toUpperCase() : 'D',
                                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _themePrimary),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      d.name,
                                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      d.licenseNumber,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontFamily: 'monospace',
                                                        fontWeight: FontWeight.w700,
                                                        color: _themePrimary,
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
                                            d.phone?.trim().isNotEmpty == true ? d.phone! : '-',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                          ),
                                        ),

                                        // Validities
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (d.validityTr != null && d.validityTr!.isNotEmpty)
                                                Text('TR: ${d.validityTr}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                                              if (d.validityNt != null && d.validityNt!.isNotEmpty)
                                                Text('NT: ${d.validityNt}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                              if ((d.validityTr == null || d.validityTr!.isEmpty) && (d.validityNt == null || d.validityNt!.isEmpty))
                                                const Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                            ],
                                          ),
                                        ),

                                        // Blood Group
                                        Expanded(
                                          flex: 1,
                                          child: d.bloodGroup?.trim().isNotEmpty == true
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEE2E2),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    d.bloodGroup!,
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                )
                                              : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                                        ),

                                        // Status
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isBlacklisted
                                                      ? const Color(0xFFFEE2E2)
                                                      : (isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isBlacklisted
                                                        ? const Color(0xFFFECACA)
                                                        : (isActive ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: isBlacklisted
                                                            ? const Color(0xFFDC2626)
                                                            : (isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      d.status?.toUpperCase() ?? 'ACTIVE',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: isBlacklisted
                                                            ? const Color(0xFFB91C1C)
                                                            : (isActive ? const Color(0xFF15803D) : const Color(0xFF64748B)),
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
                                          width: 140,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                                                tooltip: 'View Profile',
                                                onPressed: () => _showDriverDetailModal(d),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                                                tooltip: 'Edit Driver',
                                                onPressed: () => _handleEdit(d),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                tooltip: 'Delete Driver',
                                                onPressed: () => _handleDelete(d),
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
