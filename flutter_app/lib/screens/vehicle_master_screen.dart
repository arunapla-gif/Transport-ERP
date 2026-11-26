import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';

class VehicleMasterScreen extends StatefulWidget {
  const VehicleMasterScreen({super.key});

  @override
  State<VehicleMasterScreen> createState() => _VehicleMasterScreenState();
}

class _VehicleMasterScreenState extends State<VehicleMasterScreen> {
  // List & Pagination State
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isFetchingRc = false;
  int _page = 1;
  int _totalRecords = 0;
  bool _hasMore = true;

  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _tableScrollController = ScrollController();

  // Search State (400ms debounced like React VehicleMaster.jsx)
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedSearch = '';

  // Form State (1:1 with React VehicleMaster formData)
  int? _id;
  final TextEditingController _vehicleNumberController = TextEditingController();
  String _type = '6 Wheel (Lorry/Truck)';
  String _ladenType = 'Open Body';
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerPhoneController = TextEditingController();
  final TextEditingController _ownerPhone2Controller = TextEditingController();

  String _makeModel = '';
  DateTime? _fitnessExpiry;
  DateTime? _insuranceExpiry;
  DateTime? _npExpiry;
  int? _grossWeight;
  String _rcStatus = '';
  bool _rcVerified = false;
  Map<String, dynamic>? _vahanData;

  static const List<String> _defaultVehicleTypes = [
    '6 Wheel (Lorry/Truck)',
    '10 Wheel (Taurus)',
    '12 Wheeler',
    '14 Wheeler',
    '18 Wheeler',
    '22 Wheeler',
    '4 Wheel (Van/Minidor)',
  ];

  static const List<String> _defaultLadenTypes = [
    'Open Body',
    'Container',
  ];

  static const Color _emerald = Color(0xFF059669);
  static const Color _emeraldDark = Color(0xFF064E3B);
  static const Color _indigo = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _fetchVehicles(1);
    _tableScrollController.addListener(_onTableScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pageScrollController.dispose();
    _tableScrollController.dispose();
    _searchController.dispose();
    _vehicleNumberController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _ownerPhone2Controller.dispose();
    super.dispose();
  }

  void _onTableScroll() {
    if (_tableScrollController.hasClients &&
        _tableScrollController.position.pixels >=
            _tableScrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchVehicles(_page + 1);
    }
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _debouncedSearch = val.trim();
      _fetchVehicles(1);
    });
  }

  Future<void> _fetchVehicles(int pageNum) async {
    if (_isLoading && pageNum > 1) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.getVehiclesPaginated(
        page: pageNum,
        limit: 50,
        q: _debouncedSearch,
      );
      final List<dynamic> rawList = (res['data'] as List?) ?? [];
      final List<Vehicle> fetched = rawList
          .map((e) => Vehicle.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          _page = pageNum;
          _totalRecords = (res['total'] as int?) ?? fetched.length;
          _hasMore = res['hasMore'] == true;
          if (pageNum == 1) {
            _vehicles = fetched;
          } else {
            final existingIds = _vehicles.map((v) => v.id).toSet();
            for (final item in fetched) {
              if (!existingIds.contains(item.id)) {
                _vehicles.add(item);
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

  String _getVehicleTypeFromWheels(dynamic axlesRaw, dynamic gvwRaw) {
    final int axles = int.tryParse(axlesRaw?.toString() ?? '') ?? 0;
    final int gvw = int.tryParse(gvwRaw?.toString() ?? '') ?? 0;
    if (axles <= 0) return '6 Wheel (Lorry/Truck)';
    if (axles == 2) {
      return (gvw > 0 && gvw <= 3500) ? '4 Wheel (Van/Minidor)' : '6 Wheel (Lorry/Truck)';
    }
    if (axles == 3) return '10 Wheel (Taurus)';
    if (axles == 4) return '12 Wheeler';
    if (axles == 5) return '14 Wheeler';
    if (axles == 6) return '18 Wheeler';
    if (axles == 7) return '22 Wheeler';
    return '${axles * 4 - 6} Wheeler';
  }

  DateTime? _parseRcDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    // Handle DD-MMM-YYYY or DD-MM-YYYY formats returned by VAHAN
    final parts = s.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final y = int.tryParse(parts[2]);
      int? m = int.tryParse(parts[1]);
      if (m == null) {
        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        m = months[parts[1].toLowerCase()];
      }
      if (d != null && m != null && y != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  Future<void> _handleFetchRC() async {
    final rawNo = _vehicleNumberController.text.trim();
    if (rawNo.isEmpty) {
      _showToast('Please enter a vehicle number first', isError: true);
      return;
    }

    setState(() {
      _isFetchingRc = true;
      _vahanData = null;
    });

    try {
      final cleanNo = rawNo.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final vData = await ApiService.fetchRcDetails(cleanNo);

      setState(() {
        _vahanData = vData;
        _vehicleNumberController.text = cleanNo;
        _type = _getVehicleTypeFromWheels(vData['rc_no_of_axle'], vData['rc_gvw']);
        _ownerNameController.text = (vData['rc_owner_name'] ?? '').toString();
        _makeModel = (vData['rc_maker_model'] ?? '').toString();
        _fitnessExpiry = _parseRcDate(vData['rc_fit_upto']);
        _insuranceExpiry = _parseRcDate(vData['rc_insurance_upto']);
        _npExpiry = _parseRcDate(vData['rc_np_upto']);
        _grossWeight = int.tryParse(vData['rc_gvw']?.toString() ?? '');
        _rcStatus = (vData['rc_status'] ?? '').toString();
        _rcVerified = true;
      });

      _showToast('RC Details fetched successfully from VAHAN');
    } catch (e) {
      _showToast('Failed to fetch RC details from VAHAN', isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingRc = false);
    }
  }

  Future<void> _handleSave() async {
    final vNum = _vehicleNumberController.text.trim().toUpperCase();
    if (vNum.isEmpty) {
      _showToast('Vehicle Number is required', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> payload = {
        'vehicleNumber': vNum,
        'type': _type,
        'ladenType': _ladenType,
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhone': _ownerPhoneController.text.trim(),
        'ownerPhone2': _ownerPhone2Controller.text.trim(),
        'makeModel': _makeModel,
        'fitnessExpiry': _fitnessExpiry?.toIso8601String(),
        'insuranceExpiry': _insuranceExpiry?.toIso8601String(),
        'npExpiry': _npExpiry?.toIso8601String(),
        'grossWeight': _grossWeight,
        'rcStatus': _rcStatus,
        'rcVerified': _rcVerified,
      };

      if (_id != null) {
        await ApiService.updateVehicle(_id!, {...payload, 'id': _id});
        _showToast('Vehicle updated successfully');
      } else {
        await ApiService.createVehicle(payload);
        _showToast('Vehicle created successfully');
      }

      _clearForm();
      _fetchVehicles(1);
    } catch (e) {
      _showToast('Failed to save record: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleEdit(Vehicle v) {
    setState(() {
      _id = v.id;
      _vehicleNumberController.text = v.vehicleNumber;
      _type = (v.type != null && v.type!.trim().isNotEmpty) ? v.type! : '6 Wheel (Lorry/Truck)';
      _ladenType = (v.ladenType != null && v.ladenType!.trim().isNotEmpty) ? v.ladenType! : 'Open Body';
      _ownerNameController.text = v.ownerName ?? '';
      _ownerPhoneController.text = v.ownerPhone ?? '';
      _ownerPhone2Controller.text = v.ownerPhone2 ?? '';
      _makeModel = v.makeModel ?? '';
      _fitnessExpiry = v.fitnessExpiry;
      _insuranceExpiry = v.insuranceExpiry;
      _npExpiry = v.npExpiry;
      _grossWeight = v.grossWeight;
      _rcStatus = v.rcStatus ?? '';
      _rcVerified = v.rcVerified;
      _vahanData = null;
    });

    if (_pageScrollController.hasClients) {
      _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleDelete(Vehicle v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Vehicle?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        content: Text(
          'Are you sure you want to delete "${v.vehicleNumber}"?',
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
      await ApiService.deleteVehicle(v.id);
      _showToast('Record deleted');
      _fetchVehicles(1);
    } catch (e) {
      _showToast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _clearForm() {
    setState(() {
      _id = null;
      _vehicleNumberController.clear();
      _type = '6 Wheel (Lorry/Truck)';
      _ladenType = 'Open Body';
      _ownerNameController.clear();
      _ownerPhoneController.clear();
      _ownerPhone2Controller.clear();
      _makeModel = '';
      _fitnessExpiry = null;
      _insuranceExpiry = null;
      _npExpiry = null;
      _grossWeight = null;
      _rcStatus = '';
      _rcVerified = false;
      _vahanData = null;
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

  List<Vehicle> get _filteredVehicles {
    final term = _searchController.text.trim().toLowerCase();
    if (term.isEmpty) return _vehicles;
    return _vehicles.where((v) {
      return v.vehicleNumber.toLowerCase().contains(term) ||
          (v.ownerName?.toLowerCase().contains(term) ?? false) ||
          (v.ownerPhone?.toLowerCase().contains(term) ?? false) ||
          (v.ownerPhone2?.toLowerCase().contains(term) ?? false);
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
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
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
            setState(() {});
          },
          style: TextStyle(
            fontSize: 13,
            fontWeight: boldEmerald ? FontWeight.w700 : FontWeight.w500,
            color: boldEmerald ? _emeraldDark : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
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
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
              items: safeOptions
                  .map((opt) => DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt, overflow: TextOverflow.ellipsis),
                      ))
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

  // --- VAHAN 2x2 BENTO GRID (1:1 with React VehicleForm.jsx lines 84-178) ---

  Widget _buildVahanBento() {
    if (_vahanData == null) return const SizedBox.shrink();

    final v = _vahanData!;
    final String rcStatus = (v['rc_status'] ?? 'ACTIVE').toString();
    final bool isActive = rcStatus.toUpperCase() == 'ACTIVE';
    final int? gvw = int.tryParse(v['rc_gvw']?.toString() ?? '');
    final int? unld = int.tryParse(v['rc_unld_wt']?.toString() ?? '');
    final String payloadText = (gvw != null && unld != null) ? '${gvw - unld}' : 'N/A';
    final String makerFull = '${v['rc_maker_desc'] ?? ''} ${v['rc_maker_model'] ?? ''}'.trim();
    final String? npUpto = v['rc_np_upto']?.toString().trim().isNotEmpty == true
        ? v['rc_np_upto'].toString()
        : null;
    final String? blacklist = v['rc_blacklist_status']?.toString().trim().isNotEmpty == true
        ? v['rc_blacklist_status'].toString()
        : null;

    Widget kvRow(String k, String val) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                val.isEmpty ? '-' : val,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      );
    }

    Widget complianceCell(String title, String val) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
            const SizedBox(height: 3),
            Text(
              val.isEmpty ? '-' : val,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
            ),
          ],
        ),
      );
    }

    final ownershipCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
            child: const Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF6366F1)),
                SizedBox(width: 6),
                Text('OWNERSHIP DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
              ],
            ),
          ),
          kvRow('Registered Owner', (v['rc_owner_name'] ?? '-').toString()),
          kvRow('Registration Date', (v['rc_regn_dt'] ?? '-').toString()),
          kvRow('RTO Office', (v['rc_registered_at'] ?? '-').toString()),
          kvRow('Owner Type', (v['rc_owner_cd_desc'] ?? '-').toString()),
        ],
      ),
    );

    final specsCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
            child: const Row(
              children: [
                Icon(Icons.local_shipping_outlined, size: 15, color: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Text('VEHICLE & PAYLOAD SPECS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MAX LEGAL PAYLOAD',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFD97706), letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          text: '$payloadText ',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF78350F)),
                          children: const [
                            TextSpan(
                              text: 'KG',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: const Color(0xFFFDE68A)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'GROSS: ${v['rc_gvw'] ?? '-'} KG',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UNLADEN: ${v['rc_unld_wt'] ?? '-'} KG',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          kvRow('Make & Model', makerFull),
          kvRow('Vehicle Class', (v['rc_vh_class_desc'] ?? '-').toString()),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Wheels & Axles', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE0E7FF)),
                      ),
                      child: Text(
                        _getVehicleTypeFromWheels(v['rc_no_of_axle'], v['rc_gvw']).toUpperCase(),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _indigo),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${v['rc_no_of_axle'] ?? '?'} Axles)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final complianceCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
            child: const Row(
              children: [
                Icon(Icons.fact_check_outlined, size: 15, color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text('COMPLIANCE & TAX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: complianceCell('Fitness Expiry', (v['rc_fit_upto'] ?? '-').toString())),
              const SizedBox(width: 10),
              Expanded(child: complianceCell('Insurance Expiry', (v['rc_insurance_upto'] ?? '-').toString())),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: complianceCell('PUC Expiry', (v['rc_pucc_upto'] ?? '-').toString())),
              const SizedBox(width: 10),
              Expanded(child: complianceCell('Tax Expiry', (v['rc_tax_upto'] ?? '-').toString())),
            ],
          ),
        ],
      ),
    );

    final permitsCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
            child: const Row(
              children: [
                Icon(Icons.gpp_maybe_outlined, size: 15, color: Color(0xFFF43F5E)),
                SizedBox(width: 6),
                Text('PERMIT & FINANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
              ],
            ),
          ),
          kvRow('Permit Number', (v['rc_permit_no'] ?? '-').toString()),
          kvRow('Base Permit Expiry', (v['rc_permit_valid_upto'] ?? '-').toString()),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nat. Permit Expiry', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                if (npUpto != null)
                  Text(npUpto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: const Text(
                      'MISSING (LOCAL ONLY)',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFBE123C), letterSpacing: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          kvRow('Financer Bank', (v['rc_financer']?.toString().trim().isNotEmpty == true ? v['rc_financer'] : 'None').toString()),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Blacklist Status', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: blacklist != null ? const Color(0xFFFFE4E6) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (blacklist ?? 'CLEAR').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: blacklist != null ? const Color(0xFFBE123C) : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool twoCol = constraints.maxWidth >= 820;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VAHAN VERIFIED DATA',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _indigo, letterSpacing: 0.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'STATUS: ${rcStatus.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isActive ? const Color(0xFF047857) : const Color(0xFFBE123C),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (twoCol) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: ownershipCard),
                      const SizedBox(width: 14),
                      Expanded(child: specsCard),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: complianceCard),
                      const SizedBox(width: 14),
                      Expanded(child: permitsCard),
                    ],
                  ),
                ),
              ] else ...[
                ownershipCard,
                const SizedBox(height: 12),
                specsCard,
                const SizedBox(height: 12),
                complianceCard,
                const SizedBox(height: 12),
                permitsCard,
              ],
            ],
          );
        },
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
              final bool isDesktop = constraints.maxWidth >= 760;

              final vehicleNoWithVerify = Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _denseField(
                      label: 'Vehicle Number *',
                      controller: _vehicleNumberController,
                      boldEmerald: true,
                      uppercase: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: (_isFetchingRc || _vehicleNumberController.text.trim().isEmpty)
                          ? null
                          : _handleFetchRC,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _indigo.withValues(alpha: 0.45),
                        disabledForegroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _isFetchingRc ? 'Fetching...' : 'Verify RC',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              );

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
                        const Icon(Icons.local_shipping_outlined, size: 16, color: _emerald),
                        const SizedBox(width: 8),
                        const Text(
                          'Vehicle Identity',
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

                  // Row 1: Vehicle Number + Verify RC | Vehicle Type | Laden Type
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: vehicleNoWithVerify),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _denseSelect(
                            label: 'Vehicle Type',
                            value: _type,
                            baseOptions: _defaultVehicleTypes,
                            onChanged: (v) => setState(() => _type = v),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _denseSelect(
                            label: 'Laden Type',
                            value: _ladenType,
                            baseOptions: _defaultLadenTypes,
                            onChanged: (v) => setState(() => _ladenType = v),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    vehicleNoWithVerify,
                    const SizedBox(height: 12),
                    _denseSelect(
                      label: 'Vehicle Type',
                      value: _type,
                      baseOptions: _defaultVehicleTypes,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                    const SizedBox(height: 12),
                    _denseSelect(
                      label: 'Laden Type',
                      value: _ladenType,
                      baseOptions: _defaultLadenTypes,
                      onChanged: (v) => setState(() => _ladenType = v),
                    ),
                  ],

                  // Row 2: Owner Name (2 cols) | Owner Phone 1 | Owner Phone 2
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
                                flex: 2,
                                child: _denseField(
                                  label: 'Owner Name',
                                  controller: _ownerNameController,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 1,
                                child: _denseField(
                                  label: 'Owner Phone 1',
                                  controller: _ownerPhoneController,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 1,
                                child: _denseField(
                                  label: 'Owner Phone 2',
                                  controller: _ownerPhone2Controller,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _denseField(label: 'Owner Name', controller: _ownerNameController),
                              const SizedBox(height: 12),
                              _denseField(
                                label: 'Owner Phone 1',
                                controller: _ownerPhoneController,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 12),
                              _denseField(
                                label: 'Owner Phone 2',
                                controller: _ownerPhone2Controller,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                  ),

                  // VAHAN RC 2x2 Bento Results
                  _buildVahanBento(),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Separate Action Buttons GlassCard (matching React VehicleForm.jsx lines 183-195)
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
                  _id != null ? 'Update Record' : 'Save Vehicle Record',
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
    final rows = _filteredVehicles;
    final int countDisplay = _totalRecords > 0 ? _totalRecords : _vehicles.length;

    return _glassCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 700;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Saved Vehicles (46) + Search lorry or driver...
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
                        text: 'Saved Vehicles ',
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
                          hintText: 'Search lorry or driver...',
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
                      'No records found.',
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
                      final v = rows[index];
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
                                        v.vehicleNumber,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                                      ),
                                      if (v.rcVerified)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text(
                                            'VERIFIED',
                                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8), letterSpacing: 0.4),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${v.type ?? '-'} • ${(v.ladenType ?? 'Open Body').toUpperCase()}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                  if (v.ownerName?.trim().isNotEmpty == true) ...[
                                    const SizedBox(height: 3),
                                    Text(v.ownerName!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                  ],
                                  if (v.ownerPhone?.trim().isNotEmpty == true || v.ownerPhone2?.trim().isNotEmpty == true)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        [
                                          if (v.ownerPhone?.trim().isNotEmpty == true) 'Ph1: ${v.ownerPhone}',
                                          if (v.ownerPhone2?.trim().isNotEmpty == true) 'Ph2: ${v.ownerPhone2}',
                                        ].join('  •  '),
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _buildActionIcons(v),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                Column(
                  children: [
                    // Desktop Table Header (matching React VehicleTable.jsx lines 35-43)
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
                            child: Text('VEHICLE NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text('OWNER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
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
                          final v = rows[index];
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
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        v.vehicleNumber,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                      ),
                                      if (v.rcVerified)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text(
                                            'VERIFIED',
                                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8), letterSpacing: 0.4),
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
                                        v.type?.trim().isNotEmpty == true ? v.type! : '-',
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (v.ladenType?.trim().isNotEmpty == true ? v.ladenType! : 'Open Body').toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.4),
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
                                        v.ownerName?.trim().isNotEmpty == true ? v.ownerName! : '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                      ),
                                      if (v.ownerPhone?.trim().isNotEmpty == true)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text('Ph1: ${v.ownerPhone}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                        ),
                                      if (v.ownerPhone2?.trim().isNotEmpty == true)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 1),
                                          child: Text('Ph2: ${v.ownerPhone2}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: _buildActionIcons(v),
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

  Widget _buildActionIcons(Vehicle v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleEdit(v),
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
          onTap: () => _handleDelete(v),
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
      onTap: _isLoading ? null : () => _fetchVehicles(_page + 1),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: _indigo),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HEADER CARD (1:1 with React VehicleMaster.jsx lines 206-216)
                    _glassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD1FAE5)),
                            ),
                            child: const Icon(Icons.local_shipping_outlined, size: 20, color: _emerald),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vehicle Master',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Manage lorries, vehicle types, and driver details.',
                                  style: TextStyle(
                                    fontSize: 12,
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

                    // SAVED VEHICLES TABLE CARD
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
